import 'dart:math';

import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Lightweight helper that provides proportional sizing relative to a
/// reference design (393 × 852 – the Pixel 7 / iPhone 14 viewport the app
/// was originally designed for).
///
/// Unlike `flutter_screenutil` (which is already used in the project),
/// [SizeConfig] focuses on **safe proportional spacing** with clamping so
/// that values never become impractically small on tiny screens (320 lp)
/// or oversized on tablets (768+ lp).
///
/// Usage:
/// ```dart
/// // Initialise once at the top of your widget tree (after MediaQuery).
/// final sc = SizeConfig.of(context);
///
/// Container(
///   padding: EdgeInsets.all(sc.space(16)),   // 16dp on design, proportional on device
///   width: sc.widthPercent(80),              // 80% of screen width
///   child: Text('Hello', style: TextStyle(fontSize: sc.fontSize(16))),
/// );
/// ```
class SizeConfig {
  SizeConfig._({
    required this.screenWidth,
    required this.screenHeight,
    required this.deviceType,
    required this.orientation,
    required this.pixelRatio,
  });

  /// Reference design dimensions (logical pixels).
  static const double _designWidth = 393;
  static const double _designHeight = 852;

  final double screenWidth;
  final double screenHeight;
  final DeviceType deviceType;
  final Orientation orientation;
  final double pixelRatio;

  /// Create a [SizeConfig] from the nearest [MediaQuery].
  factory SizeConfig.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    return SizeConfig._(
      screenWidth: size.width,
      screenHeight: size.height,
      deviceType: Breakpoints.deviceType(size.width),
      orientation: mq.orientation,
      pixelRatio: mq.devicePixelRatio,
    );
  }

  // ── Proportional helpers ──────────────────────────────────────────────

  /// Horizontal scale factor relative to the design width.
  double get scaleWidth => screenWidth / _designWidth;

  /// Vertical scale factor relative to the design height.
  double get scaleHeight => screenHeight / _designHeight;

  /// Uniform scale factor (the smaller of the two axes so nothing overflows).
  double get scaleFactor => min(scaleWidth, scaleHeight);

  /// Scale a spacing/dimension value proportionally and clamp it so it stays
  /// between 75 %…125 % of the original on extreme screens.
  double space(double value) =>
      (value * scaleFactor).clamp(value * 0.75, value * 1.25);

  /// Scale a font size proportionally (clamped 80 %…120 %).
  double fontSize(double value) =>
      (value * scaleFactor).clamp(value * 0.80, value * 1.20);

  /// Scale an icon size proportionally (clamped 75 %…130 %).
  double iconSize(double value) =>
      (value * scaleFactor).clamp(value * 0.75, value * 1.30);

  /// A percentage of the screen width (0-100).
  double widthPercent(double percent) => screenWidth * percent / 100;

  /// A percentage of the screen height (0-100).
  double heightPercent(double percent) => screenHeight * percent / 100;

  // ── Responsive value picker ───────────────────────────────────────────

  /// Return a value that varies by device type.
  ///
  /// ```dart
  /// final padding = sc.responsive<double>(
  ///   mobileSmall: 8,
  ///   mobile: 16,
  ///   tablet: 24,
  ///   desktop: 32,
  /// );
  /// ```
  T responsive<T>({
    T? mobileSmall,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return switch (deviceType) {
      DeviceType.mobileSmall => mobileSmall ?? mobile,
      DeviceType.mobile => mobile,
      DeviceType.tablet => tablet ?? mobile,
      DeviceType.desktop => desktop ?? tablet ?? mobile,
    };
  }

  // ── Convenience booleans ──────────────────────────────────────────────

  bool get isSmallMobile => deviceType == DeviceType.mobileSmall;
  bool get isMobile =>
      deviceType == DeviceType.mobileSmall || deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;
  bool get isLandscape => orientation == Orientation.landscape;
  bool get isPortrait => orientation == Orientation.portrait;
}
