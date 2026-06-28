import 'package:flutter/material.dart';

import '../common/module_scaffold.dart';

class ExecutionScreen extends StatelessWidget {
  const ExecutionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScaffold(
      title: '실행',
      description: '배차된 운송 건의 실행 상태를 관리합니다.',
      features: [
        '운행 시작 / 종료',
        '상/하차 처리',
        '인수증 / 전자서명',
        '이상 / 사고 보고',
      ],
    );
  }
}
