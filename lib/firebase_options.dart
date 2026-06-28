// Firebase 플랫폼별 설정.
//
// 보안: 키 값은 더 이상 소스에 하드코딩하지 않고, 빌드 시 --dart-define 으로
// 주입한다(루트 .env 참조). 값이 비어 있으면 빌드 스크립트가 .env 를 읽어
// 주입하지 않은 것이므로, scripts/build_web.sh 또는 redeploy.sh 로 빌드한다.
//
// 참고: Firebase 웹 apiKey 자체는 "비밀값"이 아니라 클라이언트 식별자이며,
// 접근 제어는 Firebase 보안 규칙과 Authorized domains 로 수행한다. 다만 키를
// 저장소(GitHub)에 커밋하지 않기 위해 .env 로 분리한다.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  // ── 빌드 시 주입되는 환경값 (--dart-define) ──────────────────
  static const String _webApiKey =
      String.fromEnvironment('FIREBASE_WEB_API_KEY');
  static const String _webAppId =
      String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String _androidApiKey =
      String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const String _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _projectId =
      String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _authDomain =
      String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions 가 $defaultTargetPlatform 플랫폼용으로 '
          '설정되지 않았습니다. `flutterfire configure` 를 실행해 주세요.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _webApiKey,
    appId: _webAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
  );

  // 안드로이드: Firebase 콘솔에서 앱 추가 후 .env 의 FIREBASE_ANDROID_* 를 채운다.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: _androidAppId,
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );
}
