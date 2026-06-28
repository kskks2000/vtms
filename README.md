# VTMS — 운송 관리 시스템 (프론트엔드)

대기업용 TMS의 Flutter 프론트엔드입니다. **단일 코드베이스로 웹과 안드로이드 앱**을 모두 지원하며, 화면 너비에 따라 레이아웃이 바뀌는 **반응형** 구조입니다.

## 반응형 동작

| 화면 폭 | 구간 | 네비게이션 | 본문 |
|---------|------|------------|------|
| < 600px | 모바일(앱) | 하단 NavigationBar | 단일 컬럼 |
| 600 ~ 1024px | 태블릿 | 접힌 NavigationRail | 2컬럼 그리드 |
| ≥ 1024px | 데스크탑(웹) | 펼쳐진 사이드바 + 상단바 | 3컬럼 그리드 (최대 1440px) |

브레이크포인트는 `lib/core/responsive/breakpoints.dart`에서 한 곳으로 관리합니다.

## 프로젝트 구조

```
lib/
  main.dart                      # 진입점
  app.dart                       # MaterialApp.router
  core/
    theme/app_theme.dart         # Material 3 테마
    responsive/                  # 브레이크포인트 + 반응형 빌더
    navigation/
      app_destinations.dart      # 7개 모듈 메뉴 정의 (단일 소스)
      app_shell.dart             # 반응형 네비게이션 셸
      app_router.dart            # go_router (StatefulShellRoute)
  features/                      # 7개 모듈 화면
    master / order / planning / execution / tracking / performance / settlement
    common/module_scaffold.dart  # 공통 플레이스홀더
```

7개 모듈(마스터 · 오더 생성 · 운송계획 · 실행 · 트래킹 · 실적 · 정산)은 각각 탭 상태가 보존되며, 웹에서는 `/master`, `/order` 등 URL 경로로 직접 접근됩니다.

## 실행 방법

```bash
flutter pub get

# 웹
flutter run -d chrome

# 안드로이드 (에뮬레이터/기기 연결 후)
flutter run -d android

# 테스트
flutter test

# 정적 분석
flutter analyze
```

## 다음 작업

- 트래킹 모듈에 네이버 지도 API 연동 (웹: JS SDK / 안드로이드: 네이티브 SDK 플랫폼 분기)
- 각 모듈 화면의 실제 목록/폼/상세 구현
- FastAPI 백엔드 연동 (API 클라이언트, 상태관리 도입)
