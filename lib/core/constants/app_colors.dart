import 'package:flutter/material.dart';

/// App color constants for consistent theming.
/// Uses Material Design 3 color system with accessibility in mind.
class AppColors {
  AppColors._();

  /// Primary seed color - Blue for trust and calm
  static const Color primarySeed = Color(0xFF2196F3);

  /// Status colors
  static const Color success = Color(0xFF4CAF50); // Green - completed
  static const Color warning = Color(0xFFFF9800); // Orange/Amber - pending
  static const Color error = Color(0xFFF44336); // Red - missed/SOS/critical

  /// Status color variants for backgrounds
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color errorLight = Color(0xFFFFEBEE);

  /// SOS specific colors
  static const Color sosRed = Color(0xFFD32F2F);
  static const Color sosRedDark = Color(0xFFB71C1C);

  /// Dependent status colors
  static const Color statusGreen = Color(0xFF4CAF50); // All good
  static const Color statusYellow = Color(0xFFFFC107); // Needs attention
  static const Color statusRed = Color(0xFFF44336); // Urgent

  /// High contrast colors for accessibility
  static const Color highContrastText = Color(0xFF000000);
  static const Color highContrastBackground = Color(0xFFFFFFFF);
  static const Color highContrastTextDark = Color(0xFFFFFFFF);
  static const Color highContrastBackgroundDark = Color(0xFF121212);
}
