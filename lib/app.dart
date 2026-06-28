import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_controller.dart';
import 'core/auth/auth_scope.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';

/// 앱 루트. 웹과 안드로이드 양쪽에서 동일하게 동작한다.
class VtmsApp extends StatefulWidget {
  const VtmsApp({super.key, this.authController});

  /// 테스트에서 상태를 주입하기 위한 선택적 컨트롤러.
  final AuthController? authController;

  @override
  State<VtmsApp> createState() => _VtmsAppState();
}

class _VtmsAppState extends State<VtmsApp> {
  late final AuthController _auth;
  late final GoRouter _router;
  late final bool _ownsAuth;

  @override
  void initState() {
    super.initState();
    _ownsAuth = widget.authController == null;
    _auth = widget.authController ?? AuthController();
    _router = createRouter(_auth);
    // 저장된 토큰으로 자동 로그인 시도 (주입된 컨트롤러는 호출자가 제어)
    if (_ownsAuth) _auth.bootstrap();
  }

  @override
  void dispose() {
    if (_ownsAuth) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: MaterialApp.router(
        title: 'VTMS 운송 관리 시스템',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }
}
