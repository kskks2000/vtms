import 'package:flutter/widgets.dart';

/// 화면 크기 구간. 너비 기준으로 분기한다.
enum ScreenSize { mobile, tablet, desktop }

/// 반응형 브레이크포인트 정의.
class Breakpoints {
  Breakpoints._();

  /// 이 값 미만은 모바일(앱) 레이아웃.
  static const double mobileMax = 600;

  /// 이 값 미만은 태블릿 레이아웃, 이상은 데스크탑(웹) 레이아웃.
  static const double tabletMax = 1024;

  /// 콘텐츠 최대 폭. 초광폭 모니터에서 본문이 과하게 늘어나는 것을 막는다.
  static const double contentMaxWidth = 1440;

  static ScreenSize of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static ScreenSize fromWidth(double width) {
    if (width < mobileMax) return ScreenSize.mobile;
    if (width < tabletMax) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }
}

extension ScreenSizeX on ScreenSize {
  bool get isMobile => this == ScreenSize.mobile;
  bool get isTablet => this == ScreenSize.tablet;
  bool get isDesktop => this == ScreenSize.desktop;

  /// 태블릿 이상 (넓은 화면) 여부.
  bool get isWide => this != ScreenSize.mobile;
}
