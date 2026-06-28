import 'package:flutter/material.dart';

import '../common/module_scaffold.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScaffold(
      title: '실적',
      description: '운송 실적을 집계하고 분석합니다.',
      features: [
        '운송 실적 집계',
        '기간별 / 거점별 분석',
        '차량 / 기사 가동률',
        '실적 리포트',
      ],
    );
  }
}
