import 'package:flutter/material.dart';

import 'master_models.dart';

/// 마스터 전용 등록/수정 화면(전체 영역).
/// 섹션(그룹)별로 필드를 묶고, 넓은 화면에서는 2단으로 배치한다.
class MasterFormPage extends StatefulWidget {
  const MasterFormPage({
    super.key,
    required this.meta,
    required this.initial,
    required this.onCancel,
    required this.onSubmit,
  });

  final MasterMeta meta;
  final Map<String, dynamic>? initial;
  final VoidCallback onCancel;

  /// 저장 처리. 성공이면 null, 실패면 에러 메시지를 반환.
  final Future<String?> Function(Map<String, dynamic> data) onSubmit;

  @override
  State<MasterFormPage> createState() => _MasterFormPageState();
}

class _MasterFormPageState extends State<MasterFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _text = {};
  final Map<String, bool> _bools = {};

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    for (final c in widget.meta.editColumns) {
      final init = widget.initial?[c.name];
      if (c.isBool) {
        _bools[c.name] = init is bool
            ? init
            : (init == true || (init == null && c.defaultValue == 'true'));
      } else {
        final v = init?.toString() ??
            (widget.initial == null ? c.defaultValue : '');
        _text[c.name] = TextEditingController(text: v);
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
    final cur = _text[col.name]!.text;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(cur) ?? DateTime.now(),
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
      if (c.isBool) {
        data[c.name] = _bools[c.name] ?? false;
      } else {
        final raw = _text[c.name]!.text.trim();
        data[c.name] = raw.isEmpty ? null : raw;
      }
    }
    return data;
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSubmit(_collect());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = widget.meta.editGroups;
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
                  for (final entry in groups.entries) ...[
                    _SectionCard(title: entry.key, fields: entry.value, builder: _field),
                    const SizedBox(height: 16),
                  ],
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
                '${widget.meta.label} ${_isEdit ? '수정' : '등록'}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (widget.meta.subtitle.isNotEmpty)
                Text(
                  widget.meta.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
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

  Widget _field(MasterColumn c) {
    final scheme = Theme.of(context).colorScheme;
    if (c.isBool) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SwitchListTile(
          title: Text(c.label),
          subtitle: c.help.isNotEmpty ? Text(c.help) : null,
          value: _bools[c.name] ?? false,
          onChanged: _saving
              ? null
              : (v) => setState(() => _bools[c.name] = v),
        ),
      );
    }

    return TextFormField(
      controller: _text[c.name],
      enabled: !_saving,
      readOnly: c.isDate,
      onTap: c.isDate ? () => _pickDate(c) : null,
      keyboardType: c.isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: c.required ? '${c.label} *' : c.label,
        helperText: c.help.isNotEmpty ? c.help : null,
        hintText: c.isDate ? 'YYYY-MM-DD' : null,
        suffixIcon:
            c.isDate ? const Icon(Icons.calendar_today, size: 18) : null,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) {
        if (c.required && (v == null || v.trim().isEmpty)) {
          return '필수 항목입니다.';
        }
        if (c.isNumber && v != null && v.trim().isNotEmpty) {
          if (num.tryParse(v.trim()) == null) return '숫자를 입력하세요.';
        }
        return null;
      },
    );
  }
}

/// 섹션 카드: 제목 + 반응형(2단) 필드 그리드.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.fields,
    required this.builder,
  });

  final String title;
  final List<MasterColumn> fields;
  final Widget Function(MasterColumn) builder;

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 640;
                const gap = 16.0;
                final colW =
                    twoCol ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final c in fields)
                      SizedBox(
                        width: (c.fullWidth || !twoCol)
                            ? constraints.maxWidth
                            : colW,
                        child: builder(c),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
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
            child: Text(message,
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
