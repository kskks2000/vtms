import 'package:flutter/material.dart';

import '../common/module_scaffold.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScaffold(
      title: '운송계획',
      description: '오더를 묶어 편성하고 차량/기사를 배정·배차합니다.',
      features: [
        '편성 (오더 그룹핑)',
        '배정 (차량/기사)',
        '배차 (운행 확정)',
        '계획 시뮬레이션',
      ],
    );
  }
}
