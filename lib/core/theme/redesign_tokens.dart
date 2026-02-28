import 'package:flutter/material.dart';

/// Shared visual tokens aligned with stitch 2 redesign.
class RedesignTokens {
  RedesignTokens._();

  static const Color primary = Color(0xFF13C8EC);
  static const Color primaryDark = Color(0xFF0BA6C5);
  static const Color surfaceTint = Color(0xFFE8F7FB);
  static const Color pageTop = Color(0xFFE0F7FA);
  static const Color pageBottom = Color(0xFFF6F8F8);
  static const Color glassBorder = Color(0x66FFFFFF);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [pageTop, pageBottom],
  );

  static LinearGradient buttonGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F7E96), Color(0xFF0BA6C5)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, primaryDark],
    );
  }
}
