# Firebase 인증 연동 가이드

VTMS 로그인은 **Firebase Authentication** 으로 통합되었습니다. 이메일/비밀번호와
Google 로그인 모두 Firebase 가 클라이언트 인증을 수행하고, 백엔드는 Firebase ID
토큰을 검증한 뒤 내부 사용자와 매핑하여 **자체 JWT 액세스 토큰**을 발급합니다.

## 인증 흐름

1. Flutter 앱이 Firebase 로 로그인(이메일/비밀번호 또는 Google) → Firebase ID 토큰 획득
2. 앱이 `POST /api/auth/firebase { id_token }` 호출
3. 백엔드가 ID 토큰의 서명·만료·audience(projectId)·issuer 를 검증
4. 이메일로 `vtms.users` 매핑 → `external_auth_id` 연결 → VTMS JWT 발급
5. 이후 모든 API 는 기존과 동일하게 VTMS JWT(`Authorization: Bearer ...`) 사용

토큰 검증에는 별도 서비스 계정 키 없이 `google-auth` 의
`verify_firebase_token` 을 사용합니다(이미 `requirements.txt` 에 포함).

## 1. Firebase 콘솔 설정

프로젝트: **vtms-e44bf**

- **Authentication > Sign-in method** 에서 다음 제공업체 사용 설정:
  - 이메일/비밀번호
  - Google
- **Authentication > Settings > Authorized domains** 에 앱이 배포되는 도메인 추가
  (`localhost` 는 기본 포함)

## 2. 백엔드 설정

`backend/.env` (또는 환경 변수):

```
FIREBASE_PROJECT_ID=vtms-e44bf
# 미등록 이메일로 로그인 시 자동 계정 생성 여부 (기본 false)
# true 로 두면 이메일 인증을 마친 토큰에 한해 기본 테넌트로 계정을 생성
FIREBASE_AUTO_PROVISION=false
```

의존성 설치(이미 추가됨):

```
pip install -r requirements.txt   # google-auth==2.30.0 포함
```

### 기존 사용자 주의

시드 관리자(`admin@vtms.com`)는 DB 의 `password_hash` 로만 존재하고 Firebase 에는
없습니다. Firebase 로그인을 쓰려면 둘 중 하나가 필요합니다.

- Firebase 콘솔 > Authentication 에서 동일 이메일로 사용자를 생성, 또는
- `FIREBASE_AUTO_PROVISION=true` 로 두고 이메일 인증을 마친 계정으로 최초 로그인
  (이메일이 `vtms.users` 와 일치하면 기존 계정에 연결됨)

기존 `POST /api/auth/login`(DB 비밀번호 직접 검증) 엔드포인트는 그대로 남아 있어
관리자 폴백 로그인으로 사용할 수 있습니다.

## 3. Flutter 설정

```
flutter pub get
```

- 웹: `firebase_core` 가 Firebase JS SDK 를 자동 로드하므로 `web/index.html`
  수정이 필요 없습니다. 설정값은 `lib/firebase_options.dart` 의 `web` 에
  이미 채워져 있습니다.
- 안드로이드: 아직 설정이 비어 있습니다. 둘 중 하나를 수행하세요.
  - `flutterfire configure` 실행(권장) → `firebase_options.dart` 자동 재생성
  - 또는 Firebase 콘솔에서 안드로이드 앱을 추가하고 `google-services.json` 을
    `android/app/` 에 배치한 뒤 `firebase_options.dart` 의 `android` 값(appId,
    apiKey)을 채우기
  - Google 로그인을 쓰려면 앱의 **SHA-1 지문**을 Firebase 콘솔에 등록해야 합니다.

빌드 시 API 주소는 기존과 동일하게 지정합니다.

```
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

## 4. 변경된 파일

백엔드

- `app/core/firebase.py` (신규) — Firebase ID 토큰 검증
- `app/api/auth.py` — `POST /auth/firebase` 추가
- `app/schemas/auth.py` — `FirebaseLoginRequest`
- `app/core/config.py` — `FIREBASE_PROJECT_ID`, `FIREBASE_AUTO_PROVISION`
- `app/crud/user.py` — `create_external_user`(범용 외부 인증 사용자 생성)

프론트엔드

- `lib/firebase_options.dart` (신규) — 플랫폼별 Firebase 설정
- `lib/main.dart` — `Firebase.initializeApp`
- `lib/core/auth/firebase_auth_service.dart` (신규) — 이메일/PW + Google
- `lib/core/auth/auth_api.dart` — `firebaseLogin` (구 `googleLogin` 대체)
- `lib/core/auth/auth_controller.dart` — Firebase 기반으로 교체
- `pubspec.yaml` — `firebase_core`, `firebase_auth` 추가
- `lib/core/auth/google_sign_in_service.dart` — 폐기(삭제 가능)

## 보안 메모

- `firebase_options.dart`/Firebase config 의 `apiKey` 는 웹 클라이언트 키로
  **비밀값이 아닙니다.** 접근 제어는 Firebase 보안 규칙과 Authorized domains 로
  수행합니다.
- 백엔드는 토큰의 `aud`(projectId)와 `iss`(`securetoken.google.com/<projectId>`)를
  검증하므로, 다른 Firebase 프로젝트에서 발급된 토큰은 거부됩니다.
