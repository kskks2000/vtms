// 플랫폼별 토큰 저장소를 선택한다.
// - 웹: localStorage (token_storage_web.dart) — HTTP/비보안 컨텍스트에서도 동작
// - 그 외(안드로이드 등): flutter_secure_storage (token_storage_native.dart)
import 'token_storage_native.dart'
    if (dart.library.html) 'token_storage_web.dart';

/// 토큰 저장소 인터페이스. 테스트에서는 인메모리 구현으로 교체할 수 있다.
abstract class TokenStore {
  Future<void> save(String token);
  Future<String?> read();
  Future<void> clear();
}

/// 현재 플랫폼에 맞는 토큰 저장소를 생성한다.
/// 구현은 조건부 import 된 파일의 createPlatformTokenStore() 가 제공한다.
TokenStore createTokenStore() => createPlatformTokenStore();

/// 테스트/임시용 인메모리 토큰 저장소.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._token]);
  String? _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> clear() async => _token = null;
}
