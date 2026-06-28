import 'package:flutter/material.dart';

import '../../core/auth/auth_models.dart';
import 'master_api.dart';
import 'master_form_page.dart';
import 'master_models.dart';

enum _Mode { list, form }

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  final MasterApi _api = MasterApi();
  final TextEditingController _searchCtrl = TextEditingController();
  static const int _limit = 20;

  bool _loadingMeta = true;
  String? _error;
  List<MasterMeta> _masters = [];
  MasterMeta? _selected;

  bool _loadingRows = false;
  MasterPage? _page;
  int _offset = 0;

  _Mode _mode = _Mode.list;
  Map<String, dynamic>? _formInitial;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() {
      _loadingMeta = true;
      _error = null;
    });
    try {
      final masters = await _api.meta();
      setState(() {
        _masters = masters;
        _selected = masters.isNotEmpty ? masters.first : null;
        _loadingMeta = false;
      });
      if (_selected != null) _loadRows();
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _loadingMeta = false;
      });
    } catch (_) {
      setState(() {
        _error = '서버에 연결할 수 없습니다.';
        _loadingMeta = false;
      });
    }
  }

  Future<void> _loadRows() async {
    final sel = _selected;
    if (sel == null) return;
    setState(() => _loadingRows = true);
    try {
      final page = await _api.list(sel.key,
          q: _searchCtrl.text.trim(), limit: _limit, offset: _offset);
      setState(() {
        _page = page;
        _loadingRows = false;
      });
    } on AuthException catch (e) {
      setState(() => _loadingRows = false);
      _toast(e.message);
    } catch (_) {
      setState(() => _loadingRows = false);
      _toast('목록을 불러오지 못했습니다.');
    }
  }

  void _selectMaster(MasterMeta m) {
    setState(() {
      _selected = m;
      _offset = 0;
      _searchCtrl.clear();
      _page = null;
      _mode = _Mode.list;
    });
    _loadRows();
  }

  void _openForm({Map<String, dynamic>? row}) {
    setState(() {
      _formInitial = row;
      _mode = _Mode.form;
    });
  }

  Future<String?> _submitForm(Map<String, dynamic> data) async {
    final sel = _selected!;
    try {
      if (_formInitial == null) {
        await _api.create(sel.key, data);
      } else {
        await _api.update(sel.key, _formInitial![sel.pk] as Object, data);
      }
      final created = _formInitial == null;
      setState(() => _mode = _Mode.list);
      _toast(created ? '등록되었습니다.' : '수정되었습니다.');
      _loadRows();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return '저장 중 오류가 발생했습니다.';
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final sel = _selected!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('선택한 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
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
      await _api.remove(sel.key, row[sel.pk] as Object);
      _toast('삭제되었습니다.');
      _loadRows();
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMeta) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadMeta, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    if (_mode == _Mode.form && _selected != null) {
      return MasterFormPage(
        key: ValueKey('${_selected!.key}-${_formInitial?[_selected!.pk] ?? 'new'}'),
        meta: _selected!,
        initial: _formInitial,
        onCancel: () => setState(() => _mode = _Mode.list),
        onSubmit: _submitForm,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tabBar(),
        Expanded(child: _listArea()),
      ],
    );
  }

  // ── 마스터 탭 바 ───────────────────────────────────────────
  Widget _tabBar() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final m in _masters)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _MasterTab(
                  meta: m,
                  selected: _selected?.key == m.key,
                  icon: _iconFor(m.key),
                  onTap: () => _selectMaster(m),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 목록 영역 ─────────────────────────────────────────────
  Widget _listArea() {
    final sel = _selected;
    if (sel == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(sel.label,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (_page != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('총 ${_page!.total}건',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _toolbar(),
          const SizedBox(height: 16),
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
    );
  }

  Widget _toolbar() {
    return Row(
      children: [
        SizedBox(
          width: 320,
          height: 42,
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '검색',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  _offset = 0;
                  _loadRows();
                },
              ),
            ),
            onSubmitted: (_) {
              _offset = 0;
              _loadRows();
            },
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: '새로고침',
          onPressed: _loadRows,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add, size: 18),
          label: Text('${_selected!.label} 등록'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _table() {
    final sel = _selected!;
    final scheme = Theme.of(context).colorScheme;
    if (_loadingRows && _page == null) {
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
            Text('등록된 데이터가 없습니다.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: Text('${sel.label} 등록'),
            ),
          ],
        ),
      );
    }
    final cols = sel.listColumns;
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
                headingTextStyle:
                    const TextStyle(fontWeight: FontWeight.bold),
                columnSpacing: 28,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 56,
                columns: [
                  for (final c in cols) DataColumn(label: Text(c.label)),
                  const DataColumn(label: Text('관리')),
                ],
                rows: [
                  for (final row in page.items)
                    DataRow(
                      cells: [
                        for (final c in cols)
                          DataCell(_cell(row[c.name], c),
                              onTap: () => _openForm(row: row)),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: '수정',
                              onPressed: () => _openForm(row: row),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline, size: 18),
                              tooltip: '삭제',
                              color: scheme.error,
                              onPressed: () => _delete(row),
                            ),
                          ],
                        )),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_loadingRows)
          Positioned(
            top: 8,
            right: 8,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            ),
          ),
      ],
    );
  }

  Widget _cell(dynamic v, MasterColumn c) {
    final scheme = Theme.of(context).colorScheme;
    if (c.isBool) {
      final on = v == true;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: on
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          on ? '사용' : '미사용',
          style: TextStyle(
            fontSize: 12,
            color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (v == null) {
      return Text('-', style: TextStyle(color: scheme.outline));
    }
    var s = v.toString();
    if (c.type == 'datetime' && s.length >= 16) s = s.substring(0, 16);
    return Text(s);
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
          Text('$from–$to / 총 ${page.total}건',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 12),
          IconButton.outlined(
            onPressed: canPrev
                ? () {
                    setState(() => _offset -= _limit);
                    _loadRows();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 4),
          IconButton.outlined(
            onPressed: canNext
                ? () {
                    setState(() => _offset += _limit);
                    _loadRows();
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'partners':
        return Icons.handshake_outlined;
      case 'locations':
        return Icons.place_outlined;
      case 'zones':
        return Icons.public_outlined;
      case 'vehicles':
        return Icons.local_shipping_outlined;
      case 'drivers':
        return Icons.badge_outlined;
      case 'facilities':
        return Icons.warehouse_outlined;
      case 'tariffs':
        return Icons.request_quote_outlined;
      case 'users':
        return Icons.people_outline;
      case 'roles':
        return Icons.admin_panel_settings_outlined;
      case 'tax_codes':
        return Icons.percent_outlined;
      case 'gl_codes':
        return Icons.account_balance_outlined;
      case 'accessorial_types':
        return Icons.add_card_outlined;
      default:
        return Icons.dataset_outlined;
    }
  }
}

/// 마스터 선택 탭(라벨 + 서브타이틀, 잘림 없음).
class _MasterTab extends StatelessWidget {
  const _MasterTab({
    required this.meta,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final MasterMeta meta;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primaryContainer : scheme.surface;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? scheme.primary : fg),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: fg, fontSize: 14)),
                  if (meta.subtitle.isNotEmpty)
                    Text(meta.subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                                : scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
