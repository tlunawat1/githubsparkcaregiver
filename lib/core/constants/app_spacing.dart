import 'package:flutter/material.dart';

/// Spacing constants for consistent layout throughout the app.
class AppSpacing {
  AppSpacing._();

  /// Extra small spacing (4dp)
  static const double xs = 4.0;

  /// Small spacing (8dp)
  static const double sm = 8.0;

  /// Medium spacing (16dp)
  static const double md = 16.0;

  /// Large spacing (24dp)
  static const double lg = 24.0;

  /// Extra large spacing (32dp)
  static const double xl = 32.0;

  /// Double extra large spacing (48dp)
  static const double xxl = 48.0;

  /// Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(md);

  /// Screen padding horizontal only
  static const EdgeInsets screenPaddingHorizontal =
      EdgeInsets.symmetric(horizontal: md);

  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  /// List item padding
  static const EdgeInsets listItemPadding =
      EdgeInsets.symmetric(horizontal: md, vertical: sm);

  /// Button padding for elderly users (larger touch targets)
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Section spacing
  static const SizedBox sectionSpacing = SizedBox(height: lg);

  /// Item spacing
  static const SizedBox itemSpacing = SizedBox(height: md);

  /// Small item spacing
  static const SizedBox smallSpacing = SizedBox(height: sm);
}

/// Border radius constants
class AppRadius {
  AppRadius._();

  /// Small radius (8dp)
  static const double sm = 8.0;

  /// Medium radius (12dp)
  static const double md = 12.0;

  /// Large radius (16dp)
  static const double lg = 16.0;

  /// Extra large radius (24dp)
  static const double xl = 24.0;

  /// Circular radius (full)
  static const double circular = 100.0;

  /// Small border radius
  static BorderRadius get smallRadius => BorderRadius.circular(sm);

  /// Medium border radius
  static BorderRadius get mediumRadius => BorderRadius.circular(md);

  /// Large border radius
  static BorderRadius get largeRadius => BorderRadius.circular(lg);

  /// Extra large border radius
  static BorderRadius get xlargeRadius => BorderRadius.circular(xl);
}

/// Touch target sizes for accessibility
class AppTouchTargets {
  AppTouchTargets._();

  /// Minimum touch target (48dp - WCAG standard)
  static const double minimum = 48.0;

  /// Recommended touch target for elderly (64dp)
  static const double elderly = 64.0;

  /// Large touch target for critical actions (80dp)
  static const double large = 80.0;

  /// SOS button size (120dp)
  static const double sosButton = 120.0;
}
