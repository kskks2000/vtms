import 'package:flutter/material.dart';

import '../common/module_scaffold.dart';

class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScaffold(
      title: '정산',
      description: '운임을 정산하고 청구/지급을 관리합니다.',
      features: [
        '운임 계산',
        '청구 정산 (매출)',
        '지급 정산 (매입)',
        '세금계산서 / 마감',
      ],
    );
  }
}
