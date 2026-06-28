import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/password_reset_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/execution/execution_screen.dart';
import '../../features/master/master_screen.dart';
import '../../features/order/order_screen.dart';
import '../../features/performance/performance_screen.dart';
import '../../features/planning/planning_screen.dart';
import '../../features/settlement/settlement_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../auth/auth_controller.dart';
import 'app_shell.dart';

/// 인증 상태에 따라 리다이렉트하는 라우터를 생성한다.
/// StatefulShellRoute로 7개 모듈 탭의 상태를 각각 보존하며,
/// go_router 덕분에 웹에서는 URL 경로(/master 등)가 그대로 동작한다.
GoRouter createRouter(AuthController auth) {
  // 미인증 상태에서도 접근 가능한 공개 인증 경로.
  const publicPaths = {'/login', '/signup', '/reset-password'};

  return GoRouter(
    initialLocation: '/master',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      switch (auth.status) {
        case AuthStatus.unknown:
          // 부팅 중: 스플래시 유지
          return loc == '/splash' ? null : '/splash';
        case AuthStatus.unauthenticated:
          // 로그인/회원가입/비밀번호 초기화는 그대로 두고, 그 외는 로그인으로
          return publicPaths.contains(loc) ? null : '/login';
        case AuthStatus.authenticated:
          // 로그인 관련 화면이나 스플래시에 머물러 있으면 메인으로
          if (loc == '/splash' || publicPaths.contains(loc)) return '/master';
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const PasswordResetScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/master',
                builder: (context, state) => const MasterScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/order',
                builder: (context, state) => const OrderScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/planning',
                builder: (context, state) => const PlanningScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/execution',
                builder: (context, state) => const ExecutionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tracking',
                builder: (context, state) => const TrackingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/performance',
                builder: (context, state) => const PerformanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settlement',
                builder: (context, state) => const SettlementScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
