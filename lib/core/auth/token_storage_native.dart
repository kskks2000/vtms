import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_storage.dart';

/// 모바일/데스크톱: flutter_secure_storage 로 암호화 저장.
TokenStore createPlatformTokenStore() => SecureTokenStorage();

class SecureTokenStorage implements TokenStore {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;
  static const _key = 'access_token';

  @override
  Future<void> save(String token) => _storage.write(key: _key, value: token);

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
