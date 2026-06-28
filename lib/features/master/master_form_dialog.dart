import 'package:flutter/material.dart';

import 'master_models.dart';

/// 마스터 등록/수정 폼. 저장 시 변경된 데이터 맵을 반환하고, 취소 시 null.
Future<Map<String, dynamic>?> showMasterForm(
  BuildContext context,
  MasterMeta meta, {
  Map<String, dynamic>? initial,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _MasterFormDialog(meta: meta, initial: initial),
  );
}

class _MasterFormDialog extends StatefulWidget {
  const _MasterFormDialog({required this.meta, this.initial});
  final MasterMeta meta;
  final Map<String, dynamic>? initial;

  @override
  State<_MasterFormDialog> createState() => _MasterFormDialogState();
}

class _MasterFormDialogState extends State<_MasterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _text = {};
  late final Map<String, bool> _bools = {};

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    for (final c in widget.meta.editColumns) {
      final v = widget.initial?[c.name];
      if (c.type == 'bool') {
        _bools[c.name] = (v is bool) ? v : (v == true);
      } else {
        _text[c.name] = TextEditingController(text: v?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(MasterColumn col) async {
    final now = DateTime.now();
    DateTime initial = now;
    final cur = _text[col.name]!.text;
    final parsed = DateTime.tryParse(cur);
    if (parsed != null) initial = parsed;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _text[col.name]!.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Map<String, dynamic> _collect() {
    final data = <String, dynamic>{};
    for (final c in widget.meta.editColumns) {
      if (c.type == 'bool') {
        data[c.name] = _bools[c.name] ?? false;
      } else {
        final raw = _text[c.name]!.text.trim();
        data[c.name] = raw.isEmpty ? null : raw;
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final cols = widget.meta.editColumns;
    return AlertDialog(
      title: Text('${widget.meta.label} ${_isEdit ? '수정' : '등록'}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final c in cols) _field(c)],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _collect());
            }
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  Widget _field(MasterColumn c) {
    final label = c.label + (c.required ? ' *' : '');
    if (c.type == 'bool') {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: _bools[c.name] ?? false,
        onChanged: (v) => setState(() => _bools[c.name] = v),
      );
    }

    final isNumber = c.type == 'int' || c.type == 'number';
    final isDate = c.type == 'date';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: _text[c.name],
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        readOnly: isDate,
        onTap: isDate ? () => _pickDate(c) : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: isDate ? const Icon(Icons.calendar_today, size: 18) : null,
          hintText: isDate ? 'YYYY-MM-DD' : null,
        ),
        validator: (v) {
          if (c.required && (v == null || v.trim().isEmpty)) {
            return '필수 항목입니다.';
          }
          if (isNumber && v != null && v.trim().isNotEmpty) {
            if (num.tryParse(v.trim()) == null) return '숫자를 입력하세요.';
          }
          return null;
        },
      ),
    );
  }
}
