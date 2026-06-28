import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_models.dart';
import 'order_api.dart';
import 'order_models.dart';

/// 오더 일괄 업로드. CSV 텍스트를 붙여넣어 여러 오더를 한 번에 등록한다.
/// 외부 파일 피커 의존성 없이 텍스트 붙여넣기로 처리한다(웹/앱 공용).
class OrderBulkView extends StatefulWidget {
  const OrderBulkView({
    super.key,
    required this.lookups,
    required this.api,
    required this.onClose,
  });

  final OrderLookups lookups;
  final OrderApi api;
  final VoidCallback onClose;

  @override
  State<OrderBulkView> createState() => _OrderBulkViewState();
}

class _OrderBulkViewState extends State<OrderBulkView> {
  // CSV 컬럼 정의(순서 고정). 헤더 행은 선택.
  static const List<String> _columns = [
    'customer_code', // 거래처 코드 (또는 customer_id 숫자)
    'service',
    'requested_equipment',
    'pickup_address',
    'pickup_at',
    'delivery_address',
    'delivery_at',
    'sku',
    'description',
    'quantity',
    'weight_kg',
    'volume_cbm',
    'notes',
  ];

  final TextEditingController _csvCtrl = TextEditingController();
  List<Map<String, dynamic>> _parsed = [];
  List<String> _parseErrors = [];
  bool _submitting = false;
  Map<String, dynamic>? _result;

  // 거래처 코드 → id 매핑(룩업 label 에 코드가 "(CODE)" 로 들어있음).
  late final Map<String, int> _customerByCode = _buildCodeMap();

  Map<String, int> _buildCodeMap() {
    final map = <String, int>{};
    for (final c in widget.lookups.customers) {
      final m = RegExp(r'\(([^)]+)\)\s*$').firstMatch(c.label);
      if (m != null) map[m.group(1)!.trim().toUpperCase()] = c.id;
    }
    return map;
  }

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  void _parse() {
    final text = _csvCtrl.text.trim();
    final rows = <Map<String, dynamic>>[];
    final errors = <String>[];
    if (text.isEmpty) {
      setState(() {
        _parsed = [];
        _parseErrors = ['CSV 내용을 입력하세요.'];
        _result = null;
      });
      return;
    }
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    int start = 0;
    if (lines.isNotEmpty && lines.first.toLowerCase().contains('customer')) {
      start = 1; // 헤더 행 건너뜀
    }
    for (int i = start; i < lines.length; i++) {
      final cells = _splitCsv(lines[i]);
      final row = <String, dynamic>{};
      for (int j = 0; j < _columns.length && j < cells.length; j++) {
        final v = cells[j].trim();
        if (v.isNotEmpty) row[_columns[j]] = v;
      }
      // 거래처 코드 → customer_id 해석
      final code = (row['customer_code'] ?? '').toString().trim();
      if (code.isEmpty) {
        errors.add('${i + 1}행: 거래처 코드가 비어 있습니다.');
        continue;
      }
      final asInt = int.tryParse(code);
      final cid = asInt ?? _customerByCode[code.toUpperCase()];
      if (cid == null) {
        errors.add('${i + 1}행: 거래처 코드 "$code" 를 찾을 수 없습니다.');
        continue;
      }
      row['customer_id'] = cid;
      row.remove('customer_code');
      rows.add(row);
    }
    setState(() {
      _parsed = rows;
      _parseErrors = errors;
      _result = null;
    });
  }

  /// 간단한 CSV 셀 분리(따옴표 감싼 콤마 지원).
  List<String> _splitCsv(String line) {
    final out = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        out.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    out.add(sb.toString());
    return out;
  }

  Future<void> _submit() async {
    if (_parsed.isEmpty) return;
    setState(() {
      _submitting = true;
      _result = null;
    });
    try {
      final res = await widget.api.bulk(_parsed);
      setState(() {
        _result = res;
        _submitting = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('일괄 등록 중 오류가 발생했습니다.')));
    }
  }

  void _fillSample() {
    final firstCode = _customerByCode.keys.isNotEmpty ? _customerByCode.keys.first : 'CUST-001';
    _csvCtrl.text = [
      _columns.join(','),
      '$firstCode,express,reefer,서울시 송파구 1,2026-07-01T09:00,부산시 해운대구 2,2026-07-02T18:00,SKU-1,냉장식품,10,5,0.1,긴급',
      '$firstCode,standard,van,인천시 중구 3,,대전시 유성구 4,,SKU-2,일반화물,3,20,0.5,',
    ].join('\n');
    _parse();
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: widget.onClose,
                icon: const Icon(Icons.arrow_back),
                tooltip: '목록으로',
              ),
              const SizedBox(width: 4),
              Text('오더 일괄 업로드',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: _fillSample,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: const Text('샘플 채우기'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _guide(scheme),
                const SizedBox(height: 16),
                TextField(
                  controller: _csvCtrl,
                  minLines: 6,
                  maxLines: 14,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'CSV 붙여넣기',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    hintText: _columns.join(','),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _parse,
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('검증 / 미리보기'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: (_parsed.isEmpty || _submitting) ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload, size: 18),
                      label: Text('${_parsed.length}건 등록'),
                    ),
                  ],
                ),
                if (_parseErrors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _errorList(scheme),
                ],
                if (_parsed.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _preview(scheme),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  _resultView(scheme),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _guide(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text('CSV 컬럼 순서',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _columns.join(',')));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('헤더를 복사했습니다.')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('헤더 복사'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            _columns.join(', '),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          Text(
            '· customer_code 는 거래처 코드 또는 숫자 ID. · 일시는 YYYY-MM-DDTHH:MM 형식. '
            '· 첫 줄이 헤더(customer 포함)면 자동으로 건너뜁니다. · 한 행이 하나의 오더로 등록됩니다.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _errorList(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('검증 경고 (${_parseErrors.length})',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: scheme.onErrorContainer)),
          const SizedBox(height: 6),
          for (final e in _parseErrors)
            Text('• $e', style: TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _preview(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('미리보기 (${_parsed.length}건)',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('고객ID')),
                DataColumn(label: Text('서비스')),
                DataColumn(label: Text('장비')),
                DataColumn(label: Text('상차지')),
                DataColumn(label: Text('하차지')),
                DataColumn(label: Text('품명')),
                DataColumn(label: Text('수량')),
              ],
              rows: [
                for (int i = 0; i < _parsed.length; i++)
                  DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text('${_parsed[i]['customer_id'] ?? '-'}')),
                    DataCell(Text('${_parsed[i]['service'] ?? '-'}')),
                    DataCell(Text('${_parsed[i]['requested_equipment'] ?? '-'}')),
                    DataCell(Text('${_parsed[i]['pickup_address'] ?? '-'}')),
                    DataCell(Text('${_parsed[i]['delivery_address'] ?? '-'}')),
                    DataCell(Text('${_parsed[i]['description'] ?? '-'}')),
                    DataCell(Text('${_parsed[i]['quantity'] ?? '-'}')),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultView(ColorScheme scheme) {
    final r = _result!;
    final results = (r['results'] as List?) ?? [];
    final success = r['success'] ?? 0;
    final failed = r['failed'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text('등록 완료: 성공 $success건 / 실패 $failed건',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in results)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    item['ok'] == true ? Icons.check : Icons.close,
                    size: 16,
                    color: item['ok'] == true ? Colors.green : scheme.error,
                  ),
                  const SizedBox(width: 6),
                  Text('${item['row']}행: '),
                  Text(
                    item['ok'] == true
                        ? '${item['order_no']}'
                        : '${item['error']}',
                    style: TextStyle(
                      color: item['ok'] == true ? null : scheme.error,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(onPressed: widget.onClose, child: const Text('목록으로')),
        ],
      ),
    );
  }
}
