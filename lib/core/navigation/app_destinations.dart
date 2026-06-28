import 'package:flutter/material.dart';

/// TMS 7개 모듈 메뉴 정의. 네비게이션과 라우팅이 공유한다.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

const List<AppDestination> appDestinations = [
  AppDestination(
    label: '마스터',
    path: '/master',
    icon: Icons.dataset_outlined,
    selectedIcon: Icons.dataset,
  ),
  AppDestination(
    label: '오더 생성',
    path: '/order',
    icon: Icons.note_add_outlined,
    selectedIcon: Icons.note_add,
  ),
  AppDestination(
    label: '운송계획',
    path: '/planning',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note,
  ),
  AppDestination(
    label: '실행',
    path: '/execution',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
  AppDestination(
    label: '트래킹',
    path: '/tracking',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map,
  ),
  AppDestination(
    label: '실적',
    path: '/performance',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
  ),
  AppDestination(
    label: '정산',
    path: '/settlement',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
];
