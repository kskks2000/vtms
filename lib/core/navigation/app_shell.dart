import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_scope.dart';
import '../responsive/breakpoints.dart';
import 'app_destinations.dart';

/// 7개 모듈을 감싸는 반응형 네비게이션 셸.
///
/// - 모바일(<600): 하단 NavigationBar
/// - 태블릿(600~1024): 접힌 NavigationRail
/// - 데스크탑(>=1024): 펼쳐진 고정 사이드바
///
/// go_router의 StatefulShellRoute와 함께 사용하여 탭별 상태를 유지한다.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final currentIndex = navigationShell.currentIndex;

    // 모바일: 하단 네비게이션 바
    if (size.isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(appDestinations[currentIndex].label),
          actions: [
            IconButton(
              tooltip: '로그아웃',
              icon: const Icon(Icons.logout),
              onPressed: () => AuthScope.of(context).logout(),
            ),
          ],
        ),
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _goBranch,
          destinations: [
            for (final d in appDestinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    // 태블릿/데스크탑: 좌측 레일 또는 사이드바 + 본문
    final extended = size.isDesktop;
    return Scaffold(
      body: Row(
        children: [
          _SideNavigation(
            currentIndex: currentIndex,
            extended: extended,
            onSelected: _goBranch,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: appDestinations[currentIndex].label),
                const Divider(height: 1, thickness: 1),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.currentIndex,
    required this.extended,
    required this.onSelected,
  });

  final int currentIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 220,
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping, color: theme.colorScheme.primary),
            if (extended) ...[
              const SizedBox(width: 8),
              Text(
                'VTMS',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: [
        for (final d in appDestinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const Spacer(),
          IconButton(
            tooltip: '알림',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          _UserMenu(),
        ],
      ),
    );
  }
}

/// 데스크탑 상단바의 사용자 메뉴 (이름 표시 + 로그아웃).
class _UserMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final name = auth.user?.fullName ?? '사용자';
    return PopupMenuButton<String>(
      tooltip: name,
      onSelected: (value) {
        if (value == 'logout') auth.logout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(name, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 8),
              Text('로그아웃'),
            ],
          ),
        ),
      ],
      child: const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 18)),
    );
  }
}
