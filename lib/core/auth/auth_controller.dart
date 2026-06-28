import 'package:flutter/foundation.dart';

import 'auth_api.dart';
import 'auth_models.dart';
import 'firebase_auth_service.dart';
import 'token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// 인증 상태를 보관하는 컨트롤러.
/// go_router의 refreshListenable 로 연결되어 상태 변화 시 라우팅을 갱신한다.
class AuthController extends ChangeNotifier {
  AuthController({
    AuthApi? api,
    TokenStore? storage,
    FirebaseAuthService? firebase,
  })  : _api = api ?? AuthApi(),
        _storage = storage ?? createTokenStore(),
        _firebase = firebase ?? FirebaseAuthService();

  final AuthApi _api;
  final TokenStore _storage;
  final FirebaseAuthService _firebase;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// 앱 시작 시 저장된 토큰으로 자동 로그인 시도.
  Future<void> bootstrap() async {
    final token = await _storage.read();
    if (token == null) {
      _set(AuthStatus.unauthenticated, null);
      return;
    }
    try {
      final user = await _api.me(token);
      _set(AuthStatus.authenticated, user);
    } catch (_) {
      await _storage.clear();
      _set(AuthStatus.unauthenticated, null);
    }
  }

  /// 이메일/비밀번호 로그인(Firebase). 실패 시 AuthException 을 던진다.
  Future<void> login(String email, String password) async {
    final idToken =
        await _firebase.signInWithEmailPassword(email.trim(), password);
    final token = await _api.firebaseLogin(idToken);
    await _storage.save(token);
    final user = await _api.me(token);
    _set(AuthStatus.authenticated, user);
  }

  /// 이메일/비밀번호 회원가입(Firebase). 인증 메일이 발송된다.
  /// 가입만 수행하며 로그인 상태는 바꾸지 않는다(메일 인증 후 로그인).
  /// 실패 시 AuthException 을 던진다.
  Future<void> register(String email, String password, String name) async {
    await _firebase.signUpWithEmailPassword(
      email.trim(),
      password,
      displayName: name,
    );
  }

  /// 비밀번호 재설정 메일 발송(Firebase). 실패 시 AuthException 을 던진다.
  Future<void> sendPasswordReset(String email) async {
    await _firebase.sendPasswordResetEmail(email.trim());
  }

  /// 구글 로그인(Firebase). 사용자가 취소하면 false, 성공하면 true.
  /// 실패 시 AuthException 을 던진다.
  Future<bool> loginWithGoogle() async {
    final idToken = await _firebase.signInWithGoogle();
    if (idToken == null) return false; // 취소
    final token = await _api.firebaseLogin(idToken);
    await _storage.save(token);
    final user = await _api.me(token);
    _set(AuthStatus.authenticated, user);
    return true;
  }

  Future<void> logout() async {
    await _storage.clear();
    try {
      await _firebase.signOut();
    } catch (_) {
      // Firebase 세션 정리 실패는 무시
    }
    _set(AuthStatus.unauthenticated, null);
  }

  void _set(AuthStatus status, AuthUser? user) {
    _status = status;
    _user = user;
    notifyListeners();
  }
}
