import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vtms/app.dart';
import 'package:vtms/core/auth/auth_api.dart';
import 'package:vtms/core/auth/auth_controller.dart';
import 'package:vtms/core/auth/token_storage.dart';

/// 백엔드를 흉내내는 컨트롤러를 만든다.
AuthController buildAuth({String? token}) {
  final mock = MockClient((req) async {
    if (req.url.path.endsWith('/auth/me')) {
      return http.Response(
        jsonEncode({
          'id': 1,
          'email': 'admin@vtms.com',
          'full_name': '관리자',
          'is_active': true,
          'roles': ['admin'],
          'permissions': ['master:manage'],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (req.url.path.endsWith('/auth/login')) {
      return http.Response(
        jsonEncode({'access_token': 'test-token', 'token_type': 'bearer'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
  return AuthController(api: AuthApi(mock), storage: InMemoryTokenStore(token));
}

void main() {
  testWidgets('토큰이 없으면 로그인 화면이 표시된다', (tester) async {
    final auth = buildAuth();
    await tester.pumpWidget(VtmsApp(authController: auth));
    await auth.bootstrap();
    await tester.pumpAndSettle();

    expect(find.text('로그인'), findsWidgets);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
  });

  testWidgets('넓은 화면 로그인에는 브랜드 패널(VTMS)이 보인다', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final auth = buildAuth();
    await tester.pumpWidget(VtmsApp(authController: auth));
    await auth.bootstrap();
    await tester.pumpAndSettle();

    expect(find.text('VTMS'), findsOneWidget);
  });

  testWidgets('인증된 상태에서 좁은 화면은 하단 네비게이션 바', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final auth = buildAuth(token: 'test-token');
    await tester.pumpWidget(VtmsApp(authController: auth));
    await auth.bootstrap();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('인증된 상태에서 넓은 화면은 좌측 네비게이션 레일', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final auth = buildAuth(token: 'test-token');
    await tester.pumpWidget(VtmsApp(authController: auth));
    await auth.bootstrap();
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
