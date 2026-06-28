import 'package:flutter/material.dart';

import '../common/module_scaffold.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScaffold(
      title: '오더 생성',
      description: '운송 오더를 등록하고 관리합니다.',
      features: [
        '오더 등록',
        '오더 목록 / 검색',
        '오더 일괄 업로드',
        '오더 상태 관리',
      ],
    );
  }
}
