import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_models.dart';

/// Firebase Authentication 처리.
///
/// 이메일/비밀번호와 Google 로그인을 모두 지원하며, 성공 시 Firebase ID 토큰을
/// 반환한다. 이 토큰을 백엔드 `/auth/firebase` 로 전달해 자체 JWT 를 발급받는다.
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _authOverride = auth,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth? _authOverride;
  final GoogleSignIn _googleSignIn;

  // Firebase.initializeApp 이후에만 접근되도록 지연 평가한다.
  // (위젯 테스트 등 Firebase 미초기화 환경에서의 생성 오류를 방지)
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  /// 로그인/가입 호출을 감싸 User 를 반환한다.
  ///
  /// firebase_auth 의 알려진 버그(`Null check operator used on a null value`)는
  /// 인증에는 성공해도 UserCredential 파싱 단계에서 예외를 던진다. 이 경우
  /// currentUser 로 실제 로그인 여부를 재확인해 복구한다.
  Future<User?> _resolveUser(
    Future<UserCredential> Function() signIn,
  ) async {
    try {
      final cred = await signIn();
      return cred.user ?? _auth.currentUser;
    } on FirebaseAuthException {
      rethrow; // 진짜 인증 오류는 그대로 위로 전달
    } catch (_) {
      final user = _auth.currentUser;
      if (user != null) return user; // 실제로는 로그인 성공
      rethrow;
    }
  }

  /// 이메일/비밀번호 로그인 후 Firebase ID 토큰 반환.
  Future<String> signInWithEmailPassword(String email, String password) async {
    try {
      final user = await _resolveUser(
        () => _auth.signInWithEmailAndPassword(email: email, password: password),
      );
      return await _idTokenOf(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('로그인 처리 중 오류: $e');
    }
  }

  /// 이메일/비밀번호로 회원가입한다.
  /// 가입 후 인증 메일을 발송하고, 메일 인증을 마친 뒤 로그인하도록
  /// 현재 세션은 정리한다.
  Future<void> signUpWithEmailPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final user = await _resolveUser(
        () => _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        ),
      );
      if (user != null) {
        final name = displayName?.trim() ?? '';
        if (name.isNotEmpty) {
          await user.updateDisplayName(name);
        }
        await user.sendEmailVerification();
      }
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('회원가입 처리 중 오류: $e');
    }
  }

  /// 비밀번호 재설정 메일을 발송한다.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Google 로그인 후 Firebase ID 토큰 반환. 사용자가 취소하면 null.
  Future<String?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // 웹은 팝업 방식으로 바로 Firebase 자격증명을 얻는다.
        final provider = GoogleAuthProvider()..addScope('email');
        final user = await _resolveUser(() => _auth.signInWithPopup(provider));
        return await _idTokenOf(user);
      }

      // 모바일은 google_sign_in 으로 자격증명을 받아 Firebase 에 연결한다.
      final account = await _googleSignIn.signIn();
      if (account == null) return null; // 사용자 취소
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );
      final user =
          await _resolveUser(() => _auth.signInWithCredential(credential));
      return await _idTokenOf(user);
    } on FirebaseAuthException catch (e) {
      // 사용자가 팝업을 닫은 경우는 취소로 처리한다.
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return null;
      }
      throw AuthException(_messageFor(e));
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Google 로그인 처리 중 오류: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // 구글 세션 정리 실패는 무시
    }
    await _auth.signOut();
  }

  Future<String> _idTokenOf(User? user) async {
    if (user == null) {
      throw const AuthException('로그인 사용자 정보를 가져오지 못했습니다.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AuthException('Firebase 토큰을 발급받지 못했습니다.');
    }
    return token;
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '올바른 이메일 형식이 아닙니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'operation-not-allowed':
        return '이메일/비밀번호 로그인이 비활성화되어 있습니다. 관리자에게 문의하세요.';
      case 'too-many-requests':
        return '시도 횟수가 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return '로그인이 취소되었습니다.';
      case 'unauthorized-domain':
        return '승인되지 않은 도메인입니다. Firebase 콘솔의 승인된 도메인에 현재 주소를 추가하세요.';
      default:
        return '로그인에 실패했습니다. (${e.code})';
    }
  }
}
