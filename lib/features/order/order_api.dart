import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/auth_models.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import 'order_models.dart';

/// 오더 API 클라이언트. 저장된 액세스 토큰으로 인증한다.
class OrderApi {
  OrderApi({http.Client? client, TokenStore? store})
      : _client = client ?? http.Client(),
        _store = store ?? createTokenStore();

  final http.Client _client;
  final TokenStore _store;

  Future<Map<String, String>> _headers() async {
    final token = await _store.read();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<OrderLookups> lookups() async {
    final res = await _client.get(
      Uri.parse(AppConfig.api('/orders/_lookups')),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return OrderLookups.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw AuthException(_msg(res, '기준 정보를 불러오지 못했습니다.'));
  }

  Future<OrderPage> list({
    String? q,
    String? status,
    int? customerId,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      'limit': '$limit',
      'offset': '$offset',
      if (q != null && q.isNotEmpty) 'q': q,
      if (status != null && status.isNotEmpty) 'status': status,
      if (customerId != null) 'customer_id': '$customerId',
    };
    final uri = Uri.parse(AppConfig.api('/orders'))
        .replace(queryParameters: params);
    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      return OrderPage.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw AuthException(_msg(res, '오더 목록을 불러오지 못했습니다.'));
  }

  Future<OrderDetail> get(int id) async {
    final res = await _client.get(
      Uri.parse(AppConfig.api('/orders/$id')),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      return OrderDetail.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw AuthException(_msg(res, '오더를 불러오지 못했습니다.'));
  }

  /// 등록. 성공 시 생성된 오더 번호를 반환.
  Future<String> create(Map<String, dynamic> payload) async {
    final res = await _client.post(
      Uri.parse(AppConfig.api('/orders')),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return body['order_no'] as String? ?? '';
    }
    throw AuthException(_msg(res, '오더 등록에 실패했습니다.'));
  }

  Future<void> update(int id, Map<String, dynamic> payload) async {
    final res = await _client.put(
      Uri.parse(AppConfig.api('/orders/$id')),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) return;
    throw AuthException(_msg(res, '오더 수정에 실패했습니다.'));
  }

  Future<void> changeStatus(int id, String status, {String? reason}) async {
    final res = await _client.post(
      Uri.parse(AppConfig.api('/orders/$id/status')),
      headers: await _headers(),
      body: jsonEncode({'status': status, if (reason != null) 'reason': reason}),
    );
    if (res.statusCode == 200) return;
    throw AuthException(_msg(res, '상태 변경에 실패했습니다.'));
  }

  Future<void> remove(int id) async {
    final res = await _client.delete(
      Uri.parse(AppConfig.api('/orders/$id')),
      headers: await _headers(),
    );
    if (res.statusCode == 200 || res.statusCode == 204) return;
    throw AuthException(_msg(res, '오더 삭제에 실패했습니다.'));
  }

  /// 일괄 등록. 행별 결과 요약을 반환.
  Future<Map<String, dynamic>> bulk(List<Map<String, dynamic>> rows) async {
    final res = await _client.post(
      Uri.parse(AppConfig.api('/orders/bulk')),
      headers: await _headers(),
      body: jsonEncode({'rows': rows}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    throw AuthException(_msg(res, '일괄 등록에 실패했습니다.'));
  }

  String _msg(http.Response res, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['detail'] is String) return body['detail'] as String;
    } catch (_) {}
    return fallback;
  }
}
