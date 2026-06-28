import 'package:flutter/material.dart';

import '../../core/auth/auth_models.dart';
import 'order_api.dart';
import 'order_bulk_view.dart';
import 'order_form_view.dart';
import 'order_models.dart';

/// 오더 모듈 메인. 내부적으로 랜딩 / 목록 / 등록·수정 / 일괄업로드 뷰를 전환한다.
enum _View { landing, list, form, bulk }

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final OrderApi _api = OrderApi();
  final TextEditingController _searchCtrl = TextEditingController();
  static const int _limit = 20;

  _View _view = _View.landing;

  bool _loadingLookups = false;
  String? _lookupError;
  OrderLookups? _lookups;

  bool _loadingList = false;
  OrderPage? _page;
  int _offset = 0;
  String _statusFilter = '';

  OrderDetail? _editing; // null = 신규

  @override
  void initState() {
    super.initState();
    _ensureLookups();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<bool> _ensureLookups() async {
    if (_lookups != null) return true;
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });
    try {
      final lk = await _api.lookups();
      setState(() {
        _lookups = lk;
        _loadingLookups = false;
      });
      return true;
    } on AuthException catch (e) {
      setState(() {
        _lookupError = e.message;
        _loadingLookups = false;
      });
      return false;
    } catch (_) {
      setState(() {
        _lookupError = '서버에 연결할 수 없습니다.';
        _loadingLookups = false;
      });
      return false;
    }
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final page = await _api.list(
        q: _searchCtrl.text.trim(),
        status: _statusFilter,
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _page = page;
        _loadingList = false;
      });
    } on AuthException catch (e) {
      setState(() => _loadingList = false);
      _toast(e.message);
    } catch (_) {
      setState(() => _loadingList = false);
      _toast('목록을 불러오지 못했습니다.');
    }
  }

  // ── 뷰 전환 ────────────────────────────────────────────────
  Future<void> _openList() async {
    if (!await _ensureLookups()) return;
    setState(() {
      _view = _View.list;
      _offset = 0;
    });
    _loadList();
  }

  Future<void> _openNewForm() async {
    if (!await _ensureLookups()) return;
    setState(() {
      _editing = null;
      _view = _View.form;
    });
  }

  Future<void> _openEditForm(int id) async {
    if (!await _ensureLookups()) return;
    try {
      final detail = await _api.get(id);
      setState(() {
        _editing = detail;
        _view = _View.form;
      });
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _openBulk() async {
    if (!await _ensureLookups()) return;
    setState(() => _view = _View.bulk);
  }

  Future<String?> _submitForm(OrderDetail data) async {
    try {
      if (data.id == null) {
        final no = await _api.create(data.toPayload());
        _backToList();
        _toast('오더가 등록되었습니다. ($no)');
      } else {
        await _api.update(data.id!, data.toPayload());
        _backToList();
        _toast('오더가 수정되었습니다.');
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return '저장 중 오류가 발생했습니다.';
    }
  }

  void _backToList() {
    setState(() => _view = _View.list);
    _loadList();
  }

  Future<void> _changeStatus(OrderListItem o, String to) async {
    try {
      await _api.changeStatus(o.id, to);
      _toast('상태가 변경되었습니다: ${OrderEnums.statusLabel(to)}');
      _loadList();
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _delete(OrderListItem o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('오더 삭제'),
        content: Text('${o.orderNo} 오더를 삭제하시겠습니까?\n(초안 상태만 삭제 가능)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.remove(o.id);
      _toast('삭제되었습니다.');
      _loadList();
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLookups && _lookups == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_view) {
      case _View.landing:
        return _landing();
      case _View.list:
        return _listView();
      case _View.form:
        return OrderFormView(
          key: ValueKey('form-${_editing?.id ?? 'new'}'),
          lookups: _lookups!,
          initial: _editing,
          onCancel: _backToList,
          onSubmit: _submitForm,
        );
      case _View.bulk:
        return OrderBulkView(
          lookups: _lookups!,
          api: _api,
          onClose: _backToList,
        );
    }
  }

  // ── 랜딩 (기능 카드) ───────────────────────────────────────
  Widget _landing() {
    final theme = Theme.of(context);
    final cards = [
      _LandingCard(
        icon: Icons.add_box_outlined,
        title: '오더 등록',
        subtitle: '운송 주문을 신규 등록합니다',
        onTap: _openNewForm,
      ),
      _LandingCard(
        icon: Icons.list_alt_outlined,
        title: '오더 목록 / 검색',
        subtitle: '등록된 오더를 조회·수정합니다',
        onTap: _openList,
      ),
      _LandingCard(
        icon: Icons.upload_file_outlined,
        title: '오더 일괄 업로드',
        subtitle: 'CSV 로 여러 오더를 한 번에 등록',
        onTap: _openBulk,
      ),
      _LandingCard(
        icon: Icons.timeline_outlined,
        title: '오더 상태 관리',
        subtitle: '상태별 조회 및 전이 처리',
        onTap: () async {
          await _openList();
        },
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('오더 생성',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('운송 오더를 등록하고 관리합니다.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (_lookupError != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: _lookupError!, onRetry: () => _ensureLookups()),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 1100 ? 3 : (c.maxWidth >= 720 ? 2 : 1);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 2.6,
            children: cards,
          );
        }),
      ],
    );
  }

  // ── 목록 / 검색 / 상태관리 ─────────────────────────────────
  Widget _listView() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _view = _View.landing),
                icon: const Icon(Icons.arrow_back),
                tooltip: '메뉴로',
              ),
              const SizedBox(width: 4),
              Text('오더 목록',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              if (_page != null)
                Text('총 ${_page!.total}건',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openNewForm,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('오더 등록'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: _toolbar(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _table(),
                  ),
                ),
                _pagination(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          height: 42,
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '오더번호 · 고객명 검색',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) {
              _offset = 0;
              _loadList();
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: _statusFilter.isEmpty ? '' : _statusFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: '상태',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('전체')),
              for (final s in (_lookups?.statuses ?? const <String>[]))
                DropdownMenuItem(value: s, child: Text(OrderEnums.statusLabel(s))),
            ],
            onChanged: (v) {
              setState(() {
                _statusFilter = v ?? '';
                _offset = 0;
              });
              _loadList();
            },
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: '새로고침',
          onPressed: _loadList,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _table() {
    final scheme = Theme.of(context).colorScheme;
    if (_loadingList && _page == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final page = _page;
    if (page == null || page.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text('오더가 없습니다.', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openNewForm,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('오더 등록'),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
                columnSpacing: 24,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 56,
                columns: const [
                  DataColumn(label: Text('오더번호')),
                  DataColumn(label: Text('고객')),
                  DataColumn(label: Text('상태')),
                  DataColumn(label: Text('서비스')),
                  DataColumn(label: Text('상차요청')),
                  DataColumn(label: Text('중량(kg)')),
                  DataColumn(label: Text('매출')),
                  DataColumn(label: Text('관리')),
                ],
                rows: [
                  for (final o in page.items)
                    DataRow(
                      cells: [
                        DataCell(Text(o.orderNo,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () => _openEditForm(o.id)),
                        DataCell(Text(o.customerName ?? '-'),
                            onTap: () => _openEditForm(o.id)),
                        DataCell(_StatusBadge(status: o.status)),
                        DataCell(Text(OrderEnums.serviceLabel(o.service))),
                        DataCell(Text(_shortDt(o.pickupAt))),
                        DataCell(Text(o.totalWeightKg?.toString() ?? '-')),
                        DataCell(Text(o.sellAmount != null
                            ? '${o.sellAmount} ${o.currency ?? ''}'
                            : '-')),
                        DataCell(_rowActions(o)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_loadingList)
          Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
            ),
          ),
      ],
    );
  }

  Widget _rowActions(OrderListItem o) {
    final transitions = _lookups?.transitions[o.status] ?? const <String>[];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: '수정',
          onPressed: () => _openEditForm(o.id),
        ),
        if (transitions.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz, size: 18),
            tooltip: '상태 변경',
            itemBuilder: (_) => [
              for (final t in transitions)
                PopupMenuItem(
                  value: t,
                  child: Text('→ ${OrderEnums.statusLabel(t)}'),
                ),
            ],
            onSelected: (t) => _changeStatus(o, t),
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: '삭제',
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _delete(o),
        ),
      ],
    );
  }

  Widget _pagination() {
    final page = _page;
    if (page == null) return const SizedBox(height: 8);
    final from = page.total == 0 ? 0 : _offset + 1;
    final to = _offset + page.items.length;
    final canPrev = _offset > 0;
    final canNext = to < page.total;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$from–$to / 총 ${page.total}건'),
          const SizedBox(width: 12),
          IconButton.outlined(
            onPressed: canPrev
                ? () {
                    setState(() => _offset -= _limit);
                    _loadList();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 4),
          IconButton.outlined(
            onPressed: canNext
                ? () {
                    setState(() => _offset += _limit);
                    _loadList();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  String _shortDt(String? s) {
    if (s == null || s.isEmpty) return '-';
    return s.length >= 16 ? s.substring(0, 16).replaceFirst('T', ' ') : s;
  }
}

/// 상태 배지(목록/요약 공용).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  Color _color(ColorScheme s) {
    switch (status) {
      case 'draft':
        return s.outline;
      case 'cancelled':
        return s.error;
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'in_transit':
      case 'assigned':
        return s.primary;
      default:
        return s.tertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = _color(scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        OrderEnums.statusLabel(status),
        style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: scheme.onErrorContainer))),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
