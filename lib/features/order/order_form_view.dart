import 'package:flutter/material.dart';

import 'order_models.dart';

/// 오더 등록/수정 폼. 헤더 + 배송지/품목/부가요금/참조 자식 섹션으로 구성한다.
/// 자식 행은 모델 객체를 직접 수정(onChanged)하여 상태를 관리한다.
class OrderFormView extends StatefulWidget {
  const OrderFormView({
    super.key,
    required this.lookups,
    required this.initial,
    required this.onCancel,
    required this.onSubmit,
  });

  final OrderLookups lookups;
  final OrderDetail? initial; // null 이면 신규
  final VoidCallback onCancel;

  /// 저장 처리. 성공이면 null, 실패면 에러 메시지 반환.
  final Future<String?> Function(OrderDetail data) onSubmit;

  @override
  State<OrderFormView> createState() => _OrderFormViewState();
}

class _OrderFormViewState extends State<OrderFormView> {
  final _formKey = GlobalKey<FormState>();
  late OrderDetail _d;
  bool _saving = false;
  String? _error;

  bool get _isEdit => _d.id != null;

  @override
  void initState() {
    super.initState();
    _d = widget.initial ?? OrderDetail();
    if (widget.initial == null) {
      // 신규: 기본 상·하차 한 줄씩 제공
      _d.stops = [
        OrderStopModel(stopType: 'pickup'),
        OrderStopModel(stopType: 'delivery'),
      ];
      _d.items = [OrderItemModel()];
      _d.charges = [OrderChargeModel(chargeType: 'base')];
    }
  }

  Future<void> _pickDateTime(String current, ValueChanged<String> onPicked) async {
    final base = DateTime.tryParse(current) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    final h = time?.hour ?? 0;
    final m = time?.minute ?? 0;
    final s = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}T'
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    onPicked(s);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_d.customerId == null) {
      setState(() => _error = '고객(거래처)을 선택하세요.');
      return;
    }
    if (_d.stops.isEmpty) {
      setState(() => _error = '배송지를 최소 1개 이상 입력하세요.');
      return;
    }
    setState(() => _saving = true);
    final err = await widget.onSubmit(_d);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(scheme),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _ErrorBar(message: _error!),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _basicSection(),
                  const SizedBox(height: 16),
                  _stopsSection(),
                  const SizedBox(height: 16),
                  _itemsSection(),
                  const SizedBox(height: 16),
                  _chargesSection(),
                  const SizedBox(height: 16),
                  _refsSection(),
                  const SizedBox(height: 16),
                  _summary(scheme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _saving ? null : widget.onCancel,
            icon: const Icon(Icons.arrow_back),
            tooltip: '목록으로',
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit ? '오더 수정' : '오더 등록',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                _isEdit ? _d.orderNo : '운송 주문을 등록합니다 (번호 자동 채번)',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (_isEdit) ...[
            const SizedBox(width: 12),
            _StatusChip(status: _d.status),
          ],
          const Spacer(),
          OutlinedButton(
            onPressed: _saving ? null : widget.onCancel,
            child: const Text('취소'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(_isEdit ? '저장' : '등록'),
          ),
        ],
      ),
    );
  }

  // ── 기본 정보 ───────────────────────────────────────────────
  Widget _basicSection() {
    return _SectionCard(
      title: '기본 정보',
      icon: Icons.description_outlined,
      child: LayoutBuilder(builder: (context, c) {
        final two = c.maxWidth >= 640;
        final w = two ? (c.maxWidth - 16) / 2 : c.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: w, child: _customerField()),
            SizedBox(width: w, child: _serviceField()),
            SizedBox(width: w, child: _equipmentField()),
            SizedBox(width: w, child: _currencyField()),
            SizedBox(
              width: w,
              child: _dateTimeField(
                label: '상차 요청일시',
                value: _d.pickupAt,
                onPicked: (s) => setState(() => _d.pickupAt = s),
              ),
            ),
            SizedBox(
              width: w,
              child: _dateTimeField(
                label: '하차 요청일시',
                value: _d.deliveryAt,
                onPicked: (s) => setState(() => _d.deliveryAt = s),
              ),
            ),
            SizedBox(
              width: w,
              child: _numField(
                label: '최저 온도(℃)',
                value: _d.temperatureMin,
                onChanged: (v) => _d.temperatureMin = v,
              ),
            ),
            SizedBox(
              width: w,
              child: _numField(
                label: '최고 온도(℃)',
                value: _d.temperatureMax,
                onChanged: (v) => _d.temperatureMax = v,
              ),
            ),
            SizedBox(
              width: w,
              child: _numField(
                label: '신고 가액',
                value: _d.declaredValue,
                onChanged: (v) => _d.declaredValue = v,
              ),
            ),
            SizedBox(
              width: c.maxWidth,
              child: TextFormField(
                initialValue: _d.notes,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '비고',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _d.notes = v,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _customerField() {
    return DropdownButtonFormField<int>(
      value: _d.customerId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '고객(거래처) *',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final o in widget.lookups.customers)
          DropdownMenuItem(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis)),
      ],
      validator: (v) => v == null ? '고객을 선택하세요.' : null,
      onChanged: _saving ? null : (v) => setState(() => _d.customerId = v),
    );
  }

  Widget _serviceField() {
    return DropdownButtonFormField<String>(
      value: _d.service,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '서비스 레벨',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final s in widget.lookups.services)
          DropdownMenuItem(value: s, child: Text(OrderEnums.serviceLabel(s))),
      ],
      onChanged: _saving ? null : (v) => setState(() => _d.service = v ?? 'standard'),
    );
  }

  Widget _equipmentField() {
    return DropdownButtonFormField<String?>(
      value: _d.equipment,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '요청 장비',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('선택 안 함')),
        for (final e in widget.lookups.equipments)
          DropdownMenuItem(value: e, child: Text(OrderEnums.equipmentLabel(e))),
      ],
      onChanged: _saving ? null : (v) => setState(() => _d.equipment = v),
    );
  }

  Widget _currencyField() {
    final codes = widget.lookups.currencies.isEmpty
        ? const [CurrencyOption(code: 'KRW', name: '원')]
        : widget.lookups.currencies;
    return DropdownButtonFormField<String>(
      value: _d.currency,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '통화',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final c in codes)
          DropdownMenuItem(value: c.code, child: Text('${c.code} · ${c.name}')),
      ],
      onChanged: _saving ? null : (v) => setState(() => _d.currency = v ?? 'KRW'),
    );
  }

  // ── 배송지 ──────────────────────────────────────────────────
  Widget _stopsSection() {
    return _SectionCard(
      title: '배송지 (상·하차)',
      icon: Icons.place_outlined,
      trailing: _addButton('정차지 추가', () {
        setState(() => _d.stops.add(OrderStopModel(stopType: 'delivery')));
      }),
      child: Column(
        children: [
          for (int i = 0; i < _d.stops.length; i++)
            _stopRow(i, _d.stops[i]),
          if (_d.stops.isEmpty) _emptyHint('배송지를 추가하세요.'),
        ],
      ),
    );
  }

  Widget _stopRow(int idx, OrderStopModel s) {
    return Padding(
      key: ValueKey('stop-${identityHashCode(s)}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth >= 560;
          final w = two ? (c.maxWidth - 16) / 2 : c.maxWidth;
          return Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    child: Text('${idx + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: s.stopType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '유형',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final t in widget.lookups.stopTypes)
                          DropdownMenuItem(value: t, child: Text(OrderEnums.stopLabel(t))),
                      ],
                      onChanged: _saving ? null : (v) => setState(() => s.stopType = v ?? 'delivery'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: '삭제',
                    onPressed: _saving ? null : () => setState(() => _d.stops.removeAt(idx)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: c.maxWidth,
                    child: _locationField(s),
                  ),
                  SizedBox(
                    width: c.maxWidth,
                    child: TextFormField(
                      initialValue: s.address,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: '주소',
                        helperText: '거점을 선택하지 않으면 직접 입력',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => s.address = v,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _dateTimeField(
                      label: '시간창 시작',
                      value: s.windowFrom,
                      onPicked: (v) => setState(() => s.windowFrom = v),
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _dateTimeField(
                      label: '시간창 종료',
                      value: s.windowTo,
                      onPicked: (v) => setState(() => s.windowTo = v),
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _locationField(OrderStopModel s) {
    if (widget.lookups.locations.isEmpty) {
      return const SizedBox.shrink();
    }
    return DropdownButtonFormField<int?>(
      value: s.locationId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '거점 선택',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('선택 안 함')),
        for (final o in widget.lookups.locations)
          DropdownMenuItem(value: o.id, child: Text(o.label, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: _saving
          ? null
          : (v) {
              setState(() {
                s.locationId = v;
                if (v != null) {
                  final loc = widget.lookups.locations.firstWhere((e) => e.id == v);
                  if ((s.address).isEmpty && loc.extra != null) s.address = loc.extra!;
                }
              });
            },
    );
  }

  // ── 품목 ────────────────────────────────────────────────────
  Widget _itemsSection() {
    return _SectionCard(
      title: '품목',
      icon: Icons.inventory_2_outlined,
      trailing: _addButton('품목 추가', () {
        setState(() => _d.items.add(OrderItemModel()));
      }),
      child: Column(
        children: [
          for (int i = 0; i < _d.items.length; i++) _itemRow(i, _d.items[i]),
          if (_d.items.isEmpty) _emptyHint('품목을 추가하세요.'),
        ],
      ),
    );
  }

  Widget _itemRow(int idx, OrderItemModel it) {
    return Padding(
      key: ValueKey('item-${identityHashCode(it)}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final three = c.maxWidth >= 720;
          final w = three ? (c.maxWidth - 32) / 3 : c.maxWidth;
          return Column(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(width: w, child: _textField('SKU', it.sku, (v) => it.sku = v)),
                  SizedBox(
                    width: three ? (c.maxWidth - 32) / 3 * 2 + 16 : c.maxWidth,
                    child: _textField('품명', it.description, (v) => it.description = v),
                  ),
                  SizedBox(width: w, child: _numField(label: '수량', value: it.quantity, onChanged: (v) {
                    it.quantity = v;
                    setState(() {}); // 합계 갱신
                  })),
                  SizedBox(width: w, child: _textField('포장 유형', it.packageType, (v) => it.packageType = v)),
                  SizedBox(width: w, child: _numField(label: '중량(kg)', value: it.weightKg, onChanged: (v) {
                    it.weightKg = v;
                    setState(() {});
                  })),
                  SizedBox(width: w, child: _numField(label: '부피(cbm)', value: it.volumeCbm, onChanged: (v) {
                    it.volumeCbm = v;
                    setState(() {});
                  })),
                  SizedBox(width: w, child: _textField('UN 번호', it.unNumber, (v) => it.unNumber = v)),
                  SizedBox(width: w, child: _textField('HS 코드', it.hsCode, (v) => it.hsCode = v)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Switch(
                    value: it.isHazmat,
                    onChanged: _saving ? null : (v) => setState(() => it.isHazmat = v),
                  ),
                  const Text('위험물'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Theme.of(context).colorScheme.error,
                    tooltip: '삭제',
                    onPressed: _saving
                        ? null
                        : () => setState(() => _d.items.removeAt(idx)),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── 부가요금 ────────────────────────────────────────────────
  Widget _chargesSection() {
    return _SectionCard(
      title: '운임 · 부가요금',
      icon: Icons.request_quote_outlined,
      trailing: _addButton('요금 추가', () {
        setState(() => _d.charges.add(OrderChargeModel(chargeType: 'accessorial')));
      }),
      child: Column(
        children: [
          for (int i = 0; i < _d.charges.length; i++) _chargeRow(i, _d.charges[i]),
          if (_d.charges.isEmpty) _emptyHint('요금 항목을 추가하세요.'),
        ],
      ),
    );
  }

  Widget _chargeRow(int idx, OrderChargeModel ch) {
    return Padding(
      key: ValueKey('charge-${identityHashCode(ch)}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 640;
        final typeW = wide ? 160.0 : c.maxWidth;
        final amtW = wide ? 160.0 : c.maxWidth;
        final descW = wide ? c.maxWidth - typeW - amtW - 32 - 48 : c.maxWidth;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: typeW,
                child: DropdownButtonFormField<String>(
                  value: ch.chargeType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '유형',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final t in widget.lookups.chargeTypes)
                      DropdownMenuItem(value: t, child: Text(OrderEnums.chargeLabel(t))),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => ch.chargeType = v ?? 'base'),
                ),
              ),
              SizedBox(
                width: descW < 120 ? c.maxWidth : descW,
                child: _textField('설명', ch.description, (v) => ch.description = v),
              ),
              SizedBox(
                width: amtW,
                child: _numField(
                  label: '금액',
                  value: ch.amount,
                  onChanged: (v) {
                    ch.amount = v;
                    setState(() {});
                  },
                ),
              ),
              if (widget.lookups.accessorialTypes.isNotEmpty && ch.chargeType == 'accessorial')
                SizedBox(
                  width: c.maxWidth,
                  child: DropdownButtonFormField<int?>(
                    value: ch.accessorialTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '부가요금 유형',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('선택 안 함')),
                      for (final o in widget.lookups.accessorialTypes)
                        DropdownMenuItem(value: o.id, child: Text(o.label)),
                    ],
                    onChanged: _saving ? null : (v) => setState(() => ch.accessorialTypeId = v),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Theme.of(context).colorScheme.error,
                tooltip: '삭제',
                onPressed: _saving ? null : () => setState(() => _d.charges.removeAt(idx)),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ── 참조번호 ────────────────────────────────────────────────
  Widget _refsSection() {
    return _SectionCard(
      title: '참조번호',
      icon: Icons.tag_outlined,
      trailing: _addButton('참조 추가', () {
        setState(() => _d.references.add(OrderRefModel()));
      }),
      child: Column(
        children: [
          for (int i = 0; i < _d.references.length; i++) _refRow(i, _d.references[i]),
          if (_d.references.isEmpty) _emptyHint('PO 번호 등 참조를 추가할 수 있습니다.'),
        ],
      ),
    );
  }

  Widget _refRow(int idx, OrderRefModel rf) {
    return Padding(
      key: ValueKey('ref-${identityHashCode(rf)}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: _textField('유형 (예: PO, BL)', rf.refType, (v) => rf.refType = v),
          ),
          const SizedBox(width: 16),
          Expanded(child: _textField('값', rf.refValue, (v) => rf.refValue = v)),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Theme.of(context).colorScheme.error,
            tooltip: '삭제',
            onPressed: _saving ? null : () => setState(() => _d.references.removeAt(idx)),
          ),
        ],
      ),
    );
  }

  // ── 합계 ────────────────────────────────────────────────────
  Widget _summary(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        children: [
          _summaryItem('총 중량', '${_fmt(_d.totalWeight)} kg'),
          _summaryItem('총 부피', '${_fmt(_d.totalVolume)} cbm'),
          _summaryItem('품목 수', '${_d.items.length} 건'),
          _summaryItem('매출 합계', '${_fmt(_d.totalCharge)} ${_d.currency}', emphasize: true),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, {bool emphasize = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 18 : 15,
            fontWeight: FontWeight.bold,
            color: emphasize ? scheme.primary : scheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ── 공통 필드 위젯 ──────────────────────────────────────────
  Widget _textField(String label, String value, ValueChanged<String> onChanged) {
    return TextFormField(
      initialValue: value,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  Widget _numField({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      initialValue: value,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) {
        if (v != null && v.trim().isNotEmpty && num.tryParse(v.trim()) == null) {
          return '숫자를 입력하세요.';
        }
        return null;
      },
      onChanged: onChanged,
    );
  }

  Widget _dateTimeField({
    required String label,
    required String value,
    required ValueChanged<String> onPicked,
  }) {
    final display = value.isEmpty ? '' : value.replaceFirst('T', ' ');
    return InkWell(
      onTap: _saving ? null : () => _pickDateTime(value, onPicked),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: value.isEmpty
              ? const Icon(Icons.calendar_today, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: _saving ? null : () => onPicked(''),
                ),
        ),
        child: Text(display.isEmpty ? '선택' : display,
            style: TextStyle(
                color: display.isEmpty
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null)),
      ),
    );
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: _saving ? null : onTap,
      icon: const Icon(Icons.add, size: 18),
      label: Text(label),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  String _fmt(num n) {
    final s = n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
    // 천 단위 콤마
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}

/// 섹션 카드(제목 + 우측 액션 + 본문).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        OrderEnums.statusLabel(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message});
  final String message;

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
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
