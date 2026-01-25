import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// App theme configuration using Material Design 3.
/// Designed with accessibility in mind for elderly users.
class AppTheme {
  AppTheme._();

  /// Minimum touch target size for accessibility (48dp recommended, 64dp for elderly)
  static const double minTouchTargetSize = 48.0;
  static const double elderlyTouchTargetSize = 64.0;

  /// Font size constants for accessibility
  static const double fontSizeSmall = 14.0;
  static const double fontSizeNormal = 18.0; // Minimum for elderly
  static const double fontSizeLarge = 24.0; // Recommended for elderly
  static const double fontSizeXLarge = 32.0;
  static const double fontSizeTitle = 28.0;
  static const double fontSizeHeadline = 36.0;

  /// Light theme
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primarySeed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: _buildAppBarTheme(colorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      floatingActionButtonTheme: _buildFabTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme),
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme),
      iconTheme: IconThemeData(
        size: 28,
        color: colorScheme.onSurface,
      ),
      snackBarTheme: _buildSnackBarTheme(colorScheme),
      dialogTheme: _buildDialogTheme(colorScheme),
      bottomNavigationBarTheme: _buildBottomNavTheme(colorScheme),
    );
  }

  /// Dark theme
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primarySeed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      textTheme: _buildTextTheme(colorScheme),
      appBarTheme: _buildAppBarTheme(colorScheme),
      elevatedButtonTheme: _buildElevatedButtonTheme(colorScheme),
      outlinedButtonTheme: _buildOutlinedButtonTheme(colorScheme),
      textButtonTheme: _buildTextButtonTheme(colorScheme),
      floatingActionButtonTheme: _buildFabTheme(colorScheme),
      cardTheme: _buildCardTheme(colorScheme),
      inputDecorationTheme: _buildInputDecorationTheme(colorScheme),
      iconTheme: IconThemeData(
        size: 28,
        color: colorScheme.onSurface,
      ),
      snackBarTheme: _buildSnackBarTheme(colorScheme),
      dialogTheme: _buildDialogTheme(colorScheme),
      bottomNavigationBarTheme: _buildBottomNavTheme(colorScheme),
    );
  }

  /// High contrast light theme for accessibility
  static ThemeData get highContrastLightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primarySeed,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.highContrastBackground,
      onSurface: AppColors.highContrastText,
    );

    return lightTheme.copyWith(
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(colorScheme, highContrast: true),
    );
  }

  /// High contrast dark theme for accessibility
  static ThemeData get highContrastDarkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primarySeed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: AppColors.highContrastBackgroundDark,
      onSurface: AppColors.highContrastTextDark,
    );

    return darkTheme.copyWith(
      colorScheme: colorScheme,
      textTheme: _buildTextTheme(colorScheme, highContrast: true),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme,
      {bool highContrast = false}) {
    final fontWeight = highContrast ? FontWeight.w600 : FontWeight.normal;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: fontSizeHeadline,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontSize: fontSizeNormal,
        fontWeight: fontWeight,
        color: colorScheme.onSurface,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        fontWeight: fontWeight,
        color: colorScheme.onSurface,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: fontWeight,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        fontSize: fontSizeNormal,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(ColorScheme colorScheme) {
    return AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 3,
      centerTitle: true,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(
        size: 28,
        color: colorScheme.onSurface,
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(
      ColorScheme colorScheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(minTouchTargetSize, elderlyTouchTargetSize),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: TextStyle(
          fontSize: fontSizeNormal,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(
      ColorScheme colorScheme) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(minTouchTargetSize, elderlyTouchTargetSize),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: TextStyle(
          fontSize: fontSizeNormal,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide(width: 2, color: colorScheme.primary),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(ColorScheme colorScheme) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: TextStyle(
          fontSize: fontSizeNormal,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static FloatingActionButtonThemeData _buildFabTheme(ColorScheme colorScheme) {
    return FloatingActionButtonThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      extendedTextStyle: TextStyle(
        fontSize: fontSizeNormal,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static CardThemeData _buildCardTheme(ColorScheme colorScheme) {
    return CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(8),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(
      ColorScheme colorScheme) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(fontSize: fontSizeNormal),
      hintStyle: TextStyle(
        fontSize: fontSizeNormal,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  static SnackBarThemeData _buildSnackBarTheme(ColorScheme colorScheme) {
    return SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentTextStyle: TextStyle(
        fontSize: fontSizeNormal,
        color: colorScheme.onInverseSurface,
      ),
    );
  }

  static DialogThemeData _buildDialogTheme(ColorScheme colorScheme) {
    return DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      titleTextStyle: TextStyle(
        fontSize: fontSizeLarge,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      contentTextStyle: TextStyle(
        fontSize: fontSizeNormal,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  static BottomNavigationBarThemeData _buildBottomNavTheme(
      ColorScheme colorScheme) {
    return BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(
        fontSize: fontSizeSmall,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: fontSizeSmall,
      ),
      selectedIconTheme: IconThemeData(size: 28),
      unselectedIconTheme: IconThemeData(size: 24),
    );
  }
}
