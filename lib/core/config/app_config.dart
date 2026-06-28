/// 앱 전역 설정. 빌드 시 --dart-define 으로 덮어쓸 수 있다.
///
/// 예) flutter run --dart-define=API_BASE_URL=https://api.vtms.com
class AppConfig {
  AppConfig._();

  /// 백엔드 API 베이스 URL.
  /// 기본값은 로컬 개발용 FastAPI 서버.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiPrefix = '/api';

  static String api(String path) => '$apiBaseUrl$apiPrefix$path';

  /// 구글 OAuth 웹 클라이언트 ID (웹에서 사용).
  /// flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxx.apps.googleusercontent.com
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// 구글 OAuth 서버(웹) 클라이언트 ID (안드로이드에서 idToken 발급용 serverClientId).
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );
}
