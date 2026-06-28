import 'dart:html' as html;

import 'token_storage.dart';

/// 웹: 브라우저 localStorage 사용.
/// flutter_secure_storage 의 WebCrypto(crypto.subtle)는 보안 컨텍스트(HTTPS)에서만
/// 동작하므로, HTTP 환경 호환을 위해 localStorage 로 저장한다.
TokenStore createPlatformTokenStore() => WebTokenStorage();

class WebTokenStorage implements TokenStore {
  static const _key = 'access_token';

  @override
  Future<void> save(String token) async =>
      html.window.localStorage[_key] = token;

  @override
  Future<String?> read() async => html.window.localStorage[_key];

  @override
  Future<void> clear() async => html.window.localStorage.remove(_key);
}
