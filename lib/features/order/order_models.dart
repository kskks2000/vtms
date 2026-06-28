// 오더(운송 주문) 도메인 모델. 백엔드 /orders 응답을 표현한다.

/// enum 코드 → 한글 라벨 매핑.
class OrderEnums {
  OrderEnums._();

  static const Map<String, String> status = {
    'draft': '초안',
    'confirmed': '확정',
    'planned': '계획',
    'tendered': '배차요청',
    'assigned': '배차완료',
    'in_transit': '운송중',
    'delivered': '배송완료',
    'completed': '정산완료',
    'cancelled': '취소',
  };

  static const Map<String, String> service = {
    'economy': '이코노미',
    'standard': '표준',
    'express': '특급',
    'same_day': '당일',
  };

  static const Map<String, String> equipment = {
    'van': '밴',
    'reefer': '냉동',
    'flatbed': '평판',
    'wing': '윙바디',
    'tanker': '탱크',
    'container_20': '컨테이너20',
    'container_40': '컨테이너40',
    'ltl_box': 'LTL박스',
    'parcel': '소화물',
    'other': '기타',
  };

  static const Map<String, String> stopType = {
    'pickup': '상차',
    'delivery': '하차',
    'cross_dock': '크로스독',
  };

  static const Map<String, String> chargeType = {
    'base': '기본운임',
    'fuel': '유류할증',
    'accessorial': '부가요금',
    'tax': '세금',
    'discount': '할인',
    'adjustment': '조정',
  };

  static String statusLabel(String? c) => status[c] ?? c ?? '-';
  static String serviceLabel(String? c) => service[c] ?? c ?? '-';
  static String equipmentLabel(String? c) => equipment[c] ?? c ?? '-';
  static String stopLabel(String? c) => stopType[c] ?? c ?? '-';
  static String chargeLabel(String? c) => chargeType[c] ?? c ?? '-';
}

/// 드롭다운 옵션(id + 표시명).
class LookupOption {
  const LookupOption({required this.id, required this.label, this.extra});
  final int id;
  final String label;
  final String? extra;
}

/// 통화 옵션.
class CurrencyOption {
  const CurrencyOption({required this.code, required this.name});
  final String code;
  final String name;
}

/// 오더 화면 구성용 룩업 묶음.
class OrderLookups {
  OrderLookups({
    required this.customers,
    required this.locations,
    required this.accessorialTypes,
    required this.glCodes,
    required this.currencies,
    required this.statuses,
    required this.services,
    required this.equipments,
    required this.stopTypes,
    required this.chargeTypes,
    required this.transitions,
  });

  final List<LookupOption> customers;
  final List<LookupOption> locations;
  final List<LookupOption> accessorialTypes;
  final List<LookupOption> glCodes;
  final List<CurrencyOption> currencies;
  final List<String> statuses;
  final List<String> services;
  final List<String> equipments;
  final List<String> stopTypes;
  final List<String> chargeTypes;
  final Map<String, List<String>> transitions;

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory OrderLookups.fromJson(Map<String, dynamic> j) {
    final enums = (j['enums'] as Map?)?.cast<String, dynamic>() ?? {};
    final trans = (j['transitions'] as Map?)?.cast<String, dynamic>() ?? {};
    return OrderLookups(
      customers: ((j['customers'] as List?) ?? [])
          .map((e) => LookupOption(
                id: e['id'] as int,
                label: '${e['name']}${e['code'] != null ? ' (${e['code']})' : ''}',
              ))
          .toList(),
      locations: ((j['locations'] as List?) ?? [])
          .map((e) => LookupOption(
                id: e['id'] as int,
                label: e['name'] as String? ?? '',
                extra: e['address'] as String?,
              ))
          .toList(),
      accessorialTypes: ((j['accessorial_types'] as List?) ?? [])
          .map((e) => LookupOption(
                id: e['id'] as int,
                label: '${e['name']}${e['code'] != null ? ' (${e['code']})' : ''}',
              ))
          .toList(),
      glCodes: ((j['gl_codes'] as List?) ?? [])
          .map((e) => LookupOption(
                id: e['id'] as int,
                label: '${e['code']} ${e['name']}',
              ))
          .toList(),
      currencies: ((j['currencies'] as List?) ?? [])
          .map((e) => CurrencyOption(
                code: e['code'] as String,
                name: e['name'] as String? ?? e['code'] as String,
              ))
          .toList(),
      statuses: _strList(enums['order_status']),
      services: _strList(enums['service_level']),
      equipments: _strList(enums['equipment_type']),
      stopTypes: _strList(enums['stop_type']),
      chargeTypes: _strList(enums['charge_type']),
      transitions: {
        for (final e in trans.entries) e.key: _strList(e.value),
      },
    );
  }

  String? customerName(int? id) {
    if (id == null) return null;
    for (final c in customers) {
      if (c.id == id) return c.label;
    }
    return null;
  }
}

/// 대시보드 요약(상태별 건수 + 오늘 + 당월 매출).
class OrderSummary {
  OrderSummary({
    required this.total,
    required this.statusCounts,
    required this.today,
    required this.monthRevenue,
  });

  final int total;
  final Map<String, int> statusCounts;
  final int today;
  final num monthRevenue;

  int count(String status) => statusCounts[status] ?? 0;

  /// 여러 상태의 합계.
  int sumOf(Iterable<String> statuses) =>
      statuses.fold<int>(0, (s, k) => s + count(k));

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        total: j['total'] as int? ?? 0,
        statusCounts: ((j['status_counts'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
        today: j['today'] as int? ?? 0,
        monthRevenue: j['month_revenue'] as num? ?? 0,
      );

  static OrderSummary empty() =>
      OrderSummary(total: 0, statusCounts: const {}, today: 0, monthRevenue: 0);
}

/// 목록 행(요약).
class OrderListItem {
  OrderListItem({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.service,
    required this.equipment,
    required this.pickupAt,
    required this.deliveryAt,
    required this.totalWeightKg,
    required this.totalVolumeCbm,
    required this.currency,
    required this.sellAmount,
    required this.customerId,
    required this.customerName,
    required this.createdAt,
  });

  final int id;
  final String orderNo;
  final String status;
  final String? service;
  final String? equipment;
  final String? pickupAt;
  final String? deliveryAt;
  final num? totalWeightKg;
  final num? totalVolumeCbm;
  final String? currency;
  final num? sellAmount;
  final int? customerId;
  final String? customerName;
  final String? createdAt;

  factory OrderListItem.fromJson(Map<String, dynamic> j) => OrderListItem(
        id: j['id'] as int,
        orderNo: j['order_no'] as String? ?? '',
        status: j['status'] as String? ?? 'draft',
        service: j['service'] as String?,
        equipment: j['requested_equipment'] as String?,
        pickupAt: j['requested_pickup_at']?.toString(),
        deliveryAt: j['requested_delivery_at']?.toString(),
        totalWeightKg: j['total_weight_kg'] as num?,
        totalVolumeCbm: j['total_volume_cbm'] as num?,
        currency: j['currency'] as String?,
        sellAmount: j['sell_amount'] as num?,
        customerId: j['customer_id'] as int?,
        customerName: j['customer_name'] as String?,
        createdAt: j['created_at']?.toString(),
      );
}

/// 목록 페이지.
class OrderPage {
  OrderPage({required this.items, required this.total, required this.limit, required this.offset});

  final List<OrderListItem> items;
  final int total;
  final int limit;
  final int offset;

  factory OrderPage.fromJson(Map<String, dynamic> j) => OrderPage(
        items: ((j['items'] as List?) ?? [])
            .map((e) => OrderListItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        total: j['total'] as int? ?? 0,
        limit: j['limit'] as int? ?? 50,
        offset: j['offset'] as int? ?? 0,
      );
}

/// 편집 가능한 가변 자식 모델들(폼 상태용). Map 으로 직렬화한다.
class OrderItemModel {
  String sku = '';
  String description = '';
  String quantity = '1';
  String packageType = '';
  String weightKg = '';
  String volumeCbm = '';
  bool isHazmat = false;
  String unNumber = '';
  String hsCode = '';

  OrderItemModel();

  factory OrderItemModel.fromJson(Map<String, dynamic> j) {
    final m = OrderItemModel();
    m.sku = j['sku']?.toString() ?? '';
    m.description = j['description']?.toString() ?? '';
    m.quantity = (j['quantity'] ?? 1).toString();
    m.packageType = j['package_type']?.toString() ?? '';
    m.weightKg = j['weight_kg']?.toString() ?? '';
    m.volumeCbm = j['volume_cbm']?.toString() ?? '';
    m.isHazmat = j['is_hazmat'] == true;
    m.unNumber = j['un_number']?.toString() ?? '';
    m.hsCode = j['hs_code']?.toString() ?? '';
    return m;
  }

  Map<String, dynamic> toJson() => {
        'sku': sku,
        'description': description,
        'quantity': quantity,
        'package_type': packageType,
        'weight_kg': weightKg,
        'volume_cbm': volumeCbm,
        'is_hazmat': isHazmat,
        'un_number': unNumber,
        'hs_code': hsCode,
      };

  num get qtyNum => num.tryParse(quantity) ?? 1;
  num get weightNum => num.tryParse(weightKg) ?? 0;
  num get volumeNum => num.tryParse(volumeCbm) ?? 0;
}

class OrderStopModel {
  String stopType = 'pickup';
  int? locationId;
  String address = '';
  String windowFrom = '';
  String windowTo = '';

  OrderStopModel({this.stopType = 'pickup'});

  factory OrderStopModel.fromJson(Map<String, dynamic> j) {
    final m = OrderStopModel();
    m.stopType = j['stop_type']?.toString() ?? 'pickup';
    m.locationId = j['location_id'] as int?;
    m.address = j['address']?.toString() ?? '';
    m.windowFrom = j['window_from']?.toString() ?? '';
    m.windowTo = j['window_to']?.toString() ?? '';
    return m;
  }

  Map<String, dynamic> toJson() => {
        'stop_type': stopType,
        'location_id': locationId,
        'address': address,
        'window_from': windowFrom,
        'window_to': windowTo,
      };
}

class OrderChargeModel {
  String chargeType = 'base';
  int? accessorialTypeId;
  String description = '';
  String amount = '';
  String currency = 'KRW';
  int? glCodeId;

  OrderChargeModel({this.chargeType = 'base'});

  factory OrderChargeModel.fromJson(Map<String, dynamic> j) {
    final m = OrderChargeModel();
    m.chargeType = j['charge_type']?.toString() ?? 'base';
    m.accessorialTypeId = j['accessorial_type_id'] as int?;
    m.description = j['description']?.toString() ?? '';
    m.amount = j['amount']?.toString() ?? '';
    m.currency = j['currency']?.toString() ?? 'KRW';
    m.glCodeId = j['gl_code_id'] as int?;
    return m;
  }

  Map<String, dynamic> toJson() => {
        'charge_type': chargeType,
        'accessorial_type_id': accessorialTypeId,
        'description': description,
        'amount': amount,
        'currency': currency,
        'gl_code_id': glCodeId,
      };

  num get amountNum => num.tryParse(amount) ?? 0;
}

class OrderRefModel {
  String refType = '';
  String refValue = '';

  OrderRefModel();

  factory OrderRefModel.fromJson(Map<String, dynamic> j) {
    final m = OrderRefModel();
    m.refType = j['ref_type']?.toString() ?? '';
    m.refValue = j['ref_value']?.toString() ?? '';
    return m;
  }

  Map<String, dynamic> toJson() => {'ref_type': refType, 'ref_value': refValue};
}

/// 폼 전체 상태(헤더 + 자식 리스트). 상세 조회 결과를 폼으로 로드할 때 사용.
class OrderDetail {
  int? id;
  String orderNo = '';
  String status = 'draft';
  int? customerId;
  String service = 'standard';
  String? equipment;
  String pickupAt = '';
  String deliveryAt = '';
  String temperatureMin = '';
  String temperatureMax = '';
  String declaredValue = '';
  String currency = 'KRW';
  String notes = '';
  List<OrderItemModel> items = [];
  List<OrderStopModel> stops = [];
  List<OrderChargeModel> charges = [];
  List<OrderRefModel> references = [];

  OrderDetail();

  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final d = OrderDetail();
    d.id = j['id'] as int?;
    d.orderNo = j['order_no']?.toString() ?? '';
    d.status = j['status']?.toString() ?? 'draft';
    d.customerId = j['customer_id'] as int?;
    d.service = j['service']?.toString() ?? 'standard';
    d.equipment = j['requested_equipment'] as String?;
    d.pickupAt = j['requested_pickup_at']?.toString() ?? '';
    d.deliveryAt = j['requested_delivery_at']?.toString() ?? '';
    d.temperatureMin = j['temperature_min_c']?.toString() ?? '';
    d.temperatureMax = j['temperature_max_c']?.toString() ?? '';
    d.declaredValue = j['declared_value']?.toString() ?? '';
    d.currency = j['currency']?.toString() ?? 'KRW';
    d.notes = j['notes']?.toString() ?? '';
    d.items = ((j['items'] as List?) ?? [])
        .map((e) => OrderItemModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    d.stops = ((j['stops'] as List?) ?? [])
        .map((e) => OrderStopModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    d.charges = ((j['charges'] as List?) ?? [])
        .map((e) => OrderChargeModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    d.references = ((j['references'] as List?) ?? [])
        .map((e) => OrderRefModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return d;
  }

  Map<String, dynamic> toPayload() => {
        'customer_id': customerId,
        'order_no': orderNo.trim().isEmpty ? null : orderNo.trim(),
        'service': service,
        'requested_equipment': equipment,
        'requested_pickup_at': pickupAt.trim().isEmpty ? null : pickupAt.trim(),
        'requested_delivery_at': deliveryAt.trim().isEmpty ? null : deliveryAt.trim(),
        'temperature_min_c': temperatureMin.trim().isEmpty ? null : temperatureMin.trim(),
        'temperature_max_c': temperatureMax.trim().isEmpty ? null : temperatureMax.trim(),
        'declared_value': declaredValue.trim().isEmpty ? null : declaredValue.trim(),
        'currency': currency,
        'notes': notes.trim().isEmpty ? null : notes.trim(),
        'items': items.map((e) => e.toJson()).toList(),
        'stops': stops.map((e) => e.toJson()).toList(),
        'charges': charges.map((e) => e.toJson()).toList(),
        'references': references
            .where((r) => r.refType.trim().isNotEmpty && r.refValue.trim().isNotEmpty)
            .map((e) => e.toJson())
            .toList(),
      };

  num get totalWeight => items.fold<num>(0, (s, i) => s + i.weightNum * i.qtyNum);
  num get totalVolume => items.fold<num>(0, (s, i) => s + i.volumeNum * i.qtyNum);
  num get totalCharge => charges.fold<num>(0, (s, c) => s + c.amountNum);
}
