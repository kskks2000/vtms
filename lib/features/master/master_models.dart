/// 마스터 메타데이터 모델. 백엔드 /master/_meta 응답을 표현한다.

class MasterColumn {
  const MasterColumn({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    required this.editable,
    required this.inList,
    required this.searchable,
    required this.group,
    required this.help,
    required this.fullWidth,
    required this.defaultValue,
  });

  final String name;
  final String label;
  final String type; // text | int | number | bool | date | datetime
  final bool required;
  final bool editable;
  final bool inList;
  final bool searchable;
  final String group;
  final String help;
  final bool fullWidth;
  final String defaultValue;

  bool get isBool => type == 'bool';
  bool get isNumber => type == 'int' || type == 'number';
  bool get isDate => type == 'date';

  factory MasterColumn.fromJson(Map<String, dynamic> j) => MasterColumn(
        name: j['name'] as String,
        label: j['label'] as String? ?? j['name'] as String,
        type: j['type'] as String? ?? 'text',
        required: j['required'] as bool? ?? false,
        editable: j['editable'] as bool? ?? true,
        inList: j['in_list'] as bool? ?? true,
        searchable: j['searchable'] as bool? ?? false,
        group: j['group'] as String? ?? '기본 정보',
        help: j['help'] as String? ?? '',
        fullWidth: j['full_width'] as bool? ?? false,
        defaultValue: j['default'] as String? ?? '',
      );
}

class MasterMeta {
  const MasterMeta({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.pk,
    required this.softDelete,
    required this.columns,
  });

  final String key;
  final String label;
  final String subtitle;
  final String pk;
  final bool softDelete;
  final List<MasterColumn> columns;

  List<MasterColumn> get listColumns =>
      columns.where((c) => c.inList).toList();
  List<MasterColumn> get editColumns =>
      columns.where((c) => c.editable).toList();

  /// 편집 컬럼을 group 순서대로 묶는다(등장 순서 보존).
  Map<String, List<MasterColumn>> get editGroups {
    final map = <String, List<MasterColumn>>{};
    for (final c in editColumns) {
      map.putIfAbsent(c.group, () => []).add(c);
    }
    return map;
  }

  factory MasterMeta.fromJson(Map<String, dynamic> j) => MasterMeta(
        key: j['key'] as String,
        label: j['label'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        pk: j['pk'] as String? ?? 'id',
        softDelete: j['soft_delete'] as bool? ?? true,
        columns: (j['columns'] as List)
            .map((e) => MasterColumn.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// 목록 페이지 결과.
class MasterPage {
  const MasterPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final int limit;
  final int offset;

  factory MasterPage.fromJson(Map<String, dynamic> j) => MasterPage(
        items: (j['items'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        total: j['total'] as int? ?? 0,
        limit: j['limit'] as int? ?? 50,
        offset: j['offset'] as int? ?? 0,
      );
}
