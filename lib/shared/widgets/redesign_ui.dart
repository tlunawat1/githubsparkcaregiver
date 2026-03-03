import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/redesign_tokens.dart';

class RedesignBackground extends StatelessWidget {
  const RedesignBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF10222B), Color(0xFF141A1D)],
              )
            : RedesignTokens.pageGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            left: -70.w,
            top: -50.h,
            child: _BackgroundBubble(
              size: 220.r,
              color: RedesignTokens.primary.withValues(alpha: 0.20),
            ),
          ),
          Positioned(
            right: -90.w,
            bottom: -70.h,
            child: _BackgroundBubble(
              size: 280.r,
              color: const Color(0xFF6366F1).withValues(alpha: 0.16),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _BackgroundBubble extends StatelessWidget {
  const _BackgroundBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin = const EdgeInsets.symmetric(vertical: AppSpacing.sm),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RedesignTokens.glassBorder.withValues(alpha: 0.55),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GradientPrimaryButton extends StatelessWidget {
  const GradientPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      width: double.infinity,
      height: 58.h.clamp(48.0, 62.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RedesignTokens.buttonGradient(brightness),
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3313C8EC),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.r),
            ),
          ),
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(icon ?? Icons.arrow_forward_rounded),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
