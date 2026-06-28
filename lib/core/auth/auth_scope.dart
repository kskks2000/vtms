import 'package:flutter/widgets.dart';

import 'auth_controller.dart';

/// AuthController 를 위젯 트리 전역에 노출한다.
/// `AuthScope.of(context)` 로 어디서든 접근 가능.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope 가 위젯 트리에 없습니다.');
    return scope!.notifier!;
  }
}
