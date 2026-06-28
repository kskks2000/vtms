import 'package:flutter/material.dart';

import '../common/module_scaffold.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: 네이버 지도 API 연동 (웹: JS SDK, 안드로이드: 네이티브 SDK)
    return const ModuleScaffold(
      title: '트래킹',
      description: '차량/화물 위치를 네이버 지도로 실시간 추적합니다.',
      features: [
        '실시간 차량 위치',
        '운송 경로 추적',
        '도착 예정 시간(ETA)',
        '지오펜스 알림',
      ],
    );
  }
}
