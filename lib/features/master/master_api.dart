import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/auth_models.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import 'master_models.dart';

/// 마스터 범용 CRUD API 클라이언트. 저장된 액세스 토큰으로 인증한다.
class MasterApi {
  MasterApi({http.Client? client, TokenStore? store})
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

  Future<List<MasterMeta>> meta() async {
    final res = await _client.get(
      Uri.parse(AppConfig.api('/master/_meta')),
      headers: await _headers(),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (body['masters'] as List)
          .map((e) => MasterMeta.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw AuthException(_msg(res, '마스터 정보를 불러오지 못했습니다.'));
  }

  Future<MasterPage> list(
    String key, {
    String? q,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = {
      'limit': '$limit',
      'offset': '$offset',
      if (q != null && q.isNotEmpty) 'q': q,
    };
    final uri = Uri.parse(AppConfig.api('/master/$key'))
        .replace(queryParameters: params);
    final res = await _client.get(uri, headers: await _headers());
    if (res.statusCode == 200) {
      return MasterPage.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw AuthException(_msg(res, '목록을 불러오지 못했습니다.'));
  }

  Future<void> create(String key, Map<String, dynamic> data) async {
    final res = await _client.post(
      Uri.parse(AppConfig.api('/master/$key')),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200 || res.statusCode == 201) return;
    throw AuthException(_msg(res, '등록에 실패했습니다.'));
  }

  Future<void> update(String key, Object id, Map<String, dynamic> data) async {
    final res = await _client.put(
      Uri.parse(AppConfig.api('/master/$key/$id')),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return;
    throw AuthException(_msg(res, '수정에 실패했습니다.'));
  }

  Future<void> remove(String key, Object id) async {
    final res = await _client.delete(
      Uri.parse(AppConfig.api('/master/$key/$id')),
      headers: await _headers(),
    );
    if (res.statusCode == 200 || res.statusCode == 204) return;
    throw AuthException(_msg(res, '삭제에 실패했습니다.'));
  }

  String _msg(http.Response res, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['detail'] is String) return body['detail'] as String;
    } catch (_) {}
    return fallback;
  }
}
