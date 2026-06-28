import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// 화면 크기별로 다른 위젯을 그릴 때 쓰는 빌더.
///
/// ```dart
/// ResponsiveBuilder(
///   builder: (context, size) => size.isMobile ? MobileView() : WideView(),
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenSize size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.fromWidth(constraints.maxWidth);
        return builder(context, size);
      },
    );
  }
}

/// 모바일/태블릿/데스크탑 위젯을 직접 매핑할 때 쓰는 헬퍼.
/// tablet/desktop을 생략하면 한 단계 작은 레이아웃으로 폴백한다.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, size) {
        switch (size) {
          case ScreenSize.desktop:
            return desktop ?? tablet ?? mobile;
          case ScreenSize.tablet:
            return tablet ?? mobile;
          case ScreenSize.mobile:
            return mobile;
        }
      },
    );
  }
}

/// 콘텐츠 폭을 제한하고 가운데 정렬하는 래퍼.
/// 초광폭 화면에서 본문이 과하게 늘어나는 것을 막는다.
class ContentConstrained extends StatelessWidget {
  const ContentConstrained({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
