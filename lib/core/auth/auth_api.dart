import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_models.dart';

/// FastAPI 인증 엔드포인트 클라이언트.
class AuthApi {
  AuthApi([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// 로그인 → 액세스 토큰 반환.
  Future<String> login(String email, String password) async {
    final res = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['access_token'] as String;
    }
    throw AuthException(_errorMessage(res, '로그인에 실패했습니다.'));
  }

  /// Firebase ID 토큰으로 로그인 → 액세스 토큰 반환.
  /// 이메일/비밀번호, Google 등 모든 Firebase 로그인 방식에 공통 사용한다.
  Future<String> firebaseLogin(String idToken) async {
    final res = await _post('/auth/firebase', {'id_token': idToken});
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['access_token'] as String;
    }
    throw AuthException(_errorMessage(res, '로그인에 실패했습니다.'));
  }

  /// 토큰으로 현재 사용자 조회. 토큰 유효성 검증에도 사용.
  Future<AuthUser> me(String token) async {
    final res = await _client.get(
      Uri.parse(AppConfig.api('/auth/me')),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return AuthUser.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw AuthException(_errorMessage(res, '사용자 정보를 가져오지 못했습니다.'));
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) {
    return _client.post(
      Uri.parse(AppConfig.api(path)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  String _errorMessage(http.Response res, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
    } catch (_) {
      // 본문 파싱 실패 시 기본 메시지 사용
    }
    return fallback;
  }
}
