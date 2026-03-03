import 'package:flutter/widgets.dart';

/// Device type classification based on screen width.
enum DeviceType {
  mobileSmall,
  mobile,
  tablet,
  desktop,
}

/// Responsive breakpoint thresholds (in logical pixels).
class Breakpoints {
  Breakpoints._();

  /// Screens narrower than this are "mobile small" (e.g. iPhone SE, 320px).
  static const double mobileSmall = 360;

  /// Screens from [mobileSmall] up to this value are standard "mobile".
  static const double mobile = 600;

  /// Screens from [mobile] up to this value are "tablet".
  static const double tablet = 1024;

  // Anything above [tablet] is "desktop".

  /// Resolve the [DeviceType] for a given [width].
  static DeviceType deviceType(double width) {
    if (width < mobileSmall) return DeviceType.mobileSmall;
    if (width < mobile) return DeviceType.mobile;
    if (width < tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  /// Convenience: resolve from a [BoxConstraints] (from LayoutBuilder).
  static DeviceType fromConstraints(BoxConstraints constraints) =>
      deviceType(constraints.maxWidth);

  /// Convenience: resolve from a [BuildContext] using MediaQuery.
  static DeviceType fromContext(BuildContext context) =>
      deviceType(MediaQuery.sizeOf(context).width);

  /// True when the screen width is below [mobileSmall].
  static bool isSmallMobile(BuildContext context) =>
      fromContext(context) == DeviceType.mobileSmall;

  /// True when the screen width is below [mobile] (includes small-mobile).
  static bool isMobile(BuildContext context) {
    final t = fromContext(context);
    return t == DeviceType.mobileSmall || t == DeviceType.mobile;
  }

  /// True when the screen is at least tablet-width.
  static bool isTabletOrAbove(BuildContext context) {
    final t = fromContext(context);
    return t == DeviceType.tablet || t == DeviceType.desktop;
  }
}
