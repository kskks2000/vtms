// Firebase 플랫폼별 설정.
//
// 웹 설정은 Firebase 콘솔에서 제공한 값으로 채워져 있습니다.
// 안드로이드/iOS 는 `flutterfire configure` 를 실행해 자동 생성하거나,
// Firebase 콘솔에서 해당 앱을 추가한 뒤 아래 android 값을 채워주세요.
//
// 참고: 여기 담긴 apiKey 는 Firebase 웹 클라이언트 키로, 비밀값이 아닙니다.
// 접근 제어는 Firebase 보안 규칙과 Authorized domains 로 수행합니다.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

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
    apiKey: '***REMOVED_FIREBASE_KEY***',
    appId: '1:851399161896:web:d203f8ac9e6082b8f35d1d',
    messagingSenderId: '851399161896',
    projectId: 'vtms-e44bf',
    authDomain: 'vtms-e44bf.firebaseapp.com',
    storageBucket: 'vtms-e44bf.firebasestorage.app',
  );

  // TODO(android): Firebase 콘솔에서 안드로이드 앱을 추가한 뒤
  // appId/apiKey 를 채우고 google-services.json 을 android/app/ 에 배치하세요.
  // 또는 `flutterfire configure` 로 이 파일을 재생성하세요.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO_ANDROID_API_KEY',
    appId: 'TODO_ANDROID_APP_ID',
    messagingSenderId: '851399161896',
    projectId: 'vtms-e44bf',
    storageBucket: 'vtms-e44bf.firebasestorage.app',
  );
}
