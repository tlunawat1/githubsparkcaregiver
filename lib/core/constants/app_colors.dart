import 'package:flutter/material.dart';

/// App color constants for consistent theming.
/// Uses a warm, caregiving-focused palette designed for trust and comfort.
class AppColors {
  AppColors._();

  // ============================================
  // Primary Color Palette - Warm Teal Theme
  // ============================================

  /// Primary color - Warm Teal (trust/healing)
  static const Color primary = Color(0xFF00BCD4);
  static const Color primaryLight = Color(0xFF62EFFF);
  static const Color primaryDark = Color(0xFF008BA3);

  /// Secondary color - Purple (wisdom/dignity)
  static const Color secondary = Color(0xFF9C27B0);
  static const Color secondaryLight = Color(0xFFD05CE3);
  static const Color secondaryDark = Color(0xFF6A0080);

  /// Accent color - Warm Orange (energy)
  static const Color accent = Color(0xFFFF9800);
  static const Color accentLight = Color(0xFFFFC947);
  static const Color accentDark = Color(0xFFC66900);

  /// Primary seed for Material 3 color scheme
  static const Color primarySeed = primary;

  // ============================================
  // Status Colors - Softer, Less Clinical
  // ============================================

  /// Success - Mint Green (softer than pure green)
  static const Color success = Color(0xFF26A69A);
  static const Color successLight = Color(0xFFE0F2F1);
  static const Color successDark = Color(0xFF00796B);

  /// Warning - Warm Amber
  static const Color warning = Color(0xFFFFB300);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color warningDark = Color(0xFFFF8F00);

  /// Error - Coral Red (softer than pure red)
  static const Color error = Color(0xFFEF5350);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorDark = Color(0xFFC62828);

  /// Snoozed/Info - Calming Blue
  static const Color info = Color(0xFF42A5F5);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color infoDark = Color(0xFF1565C0);

  // ============================================
  // SOS Colors - High Visibility
  // ============================================

  static const Color sosRed = Color(0xFFD32F2F);
  static const Color sosRedDark = Color(0xFFB71C1C);
  static const Color sosRedLight = Color(0xFFFFCDD2);

  // ============================================
  // Category Colors - For Reminder Types
  // ============================================

  /// Medicine - Purple (health/healing)
  static const Color categoryMedicine = Color(0xFF7E57C2);
  static const Color categoryMedicineLight = Color(0xFFEDE7F6);
  static const Color categoryMedicineDark = Color(0xFF512DA8);

  /// Meal - Orange (warmth/nourishment)
  static const Color categoryMeal = Color(0xFFFF7043);
  static const Color categoryMealLight = Color(0xFFFBE9E7);
  static const Color categoryMealDark = Color(0xFFE64A19);

  /// Exercise - Green (vitality/movement)
  static const Color categoryExercise = Color(0xFF66BB6A);
  static const Color categoryExerciseLight = Color(0xFFE8F5E9);
  static const Color categoryExerciseDark = Color(0xFF388E3C);

  /// Call - Blue (connection/communication)
  static const Color categoryCall = Color(0xFF42A5F5);
  static const Color categoryCallLight = Color(0xFFE3F2FD);
  static const Color categoryCallDark = Color(0xFF1976D2);

  /// General - Teal (default)
  static const Color categoryGeneral = Color(0xFF26A69A);
  static const Color categoryGeneralLight = Color(0xFFE0F2F1);
  static const Color categoryGeneralDark = Color(0xFF00796B);

  // ============================================
  // Gradient Definitions
  // ============================================

  /// Status gradients for light mode
  static const LinearGradient pendingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
  );

  static const LinearGradient completedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
  );

  static const LinearGradient missedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
  );

  static const LinearGradient snoozedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
  );

  /// Status gradients for dark mode
  static const LinearGradient pendingGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3E2723), Color(0xFF4E342E)],
  );

  static const LinearGradient completedGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF004D40), Color(0xFF00695C)],
  );

  static const LinearGradient missedGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4E0000), Color(0xFF6D0000)],
  );

  static const LinearGradient snoozedGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
  );

  /// Category gradients for light mode
  static const LinearGradient medicineGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEDE7F6), Color(0xFFD1C4E9)],
  );

  static const LinearGradient mealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBE9E7), Color(0xFFFFCCBC)],
  );

  static const LinearGradient exerciseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
  );

  static const LinearGradient callGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
  );

  static const LinearGradient generalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)],
  );

  /// Primary button gradient
  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient successButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successDark],
  );

  // ============================================
  // High Contrast Colors - Accessibility
  // ============================================

  static const Color highContrastText = Color(0xFF000000);
  static const Color highContrastBackground = Color(0xFFFFFFFF);
  static const Color highContrastTextDark = Color(0xFFFFFFFF);
  static const Color highContrastBackgroundDark = Color(0xFF121212);

  // ============================================
  // Surface Colors
  // ============================================

  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// Card background with subtle warmth
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark = Color(0xFF2C2C2C);

  // ============================================
  // Dependent Status Colors (Dashboard)
  // ============================================

  static const Color statusGreen = Color(0xFF26A69A); // All good
  static const Color statusYellow = Color(0xFFFFB300); // Needs attention
  static const Color statusRed = Color(0xFFEF5350); // Urgent

  // ============================================
  // Helper Methods
  // ============================================

  /// Get gradient for reminder status
  static LinearGradient getStatusGradient(String status, {bool isDark = false}) {
    if (isDark) {
      return switch (status) {
        'pending' => pendingGradientDark,
        'completed' => completedGradientDark,
        'missed' => missedGradientDark,
        'snoozed' => snoozedGradientDark,
        _ => pendingGradientDark,
      };
    }
    return switch (status) {
      'pending' => pendingGradient,
      'completed' => completedGradient,
      'missed' => missedGradient,
      'snoozed' => snoozedGradient,
      _ => pendingGradient,
    };
  }

  /// Get color for reminder status
  static Color getStatusColor(String status) {
    return switch (status) {
      'pending' => warning,
      'completed' => success,
      'missed' => error,
      'snoozed' => info,
      _ => warning,
    };
  }

  /// Get border color for reminder status
  static Color getStatusBorderColor(String status) {
    return switch (status) {
      'pending' => warningDark,
      'completed' => successDark,
      'missed' => errorDark,
      'snoozed' => infoDark,
      _ => warningDark,
    };
  }
}
