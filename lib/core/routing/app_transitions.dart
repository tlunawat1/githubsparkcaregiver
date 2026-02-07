import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Custom page transitions for the app.
/// Provides smooth, accessible transitions that respect reduced motion settings.
class AppTransitions {
  AppTransitions._();

  /// Default transition duration
  static const Duration defaultDuration = Duration(milliseconds: 300);

  /// Fade + slide up transition (default for most screens)
  static CustomTransitionPage<T> fadeSlide<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = defaultDuration,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final reduceMotion = MediaQuery.of(context).disableAnimations;

        // Return child without animation if reduced motion is enabled
        if (reduceMotion) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        }

        // Fade + subtle slide up
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }

  /// Scale + fade transition (for modals and detail screens)
  static CustomTransitionPage<T> scaleFade<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = defaultDuration,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final reduceMotion = MediaQuery.of(context).disableAnimations;

        if (reduceMotion) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        }

        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.95,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide from right transition (for push navigation)
  static CustomTransitionPage<T> slideFromRight<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = defaultDuration,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final reduceMotion = MediaQuery.of(context).disableAnimations;

        if (reduceMotion) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        }

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide from bottom transition (for bottom sheets / modals)
  static CustomTransitionPage<T> slideFromBottom<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = defaultDuration,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final reduceMotion = MediaQuery.of(context).disableAnimations;

        if (reduceMotion) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        }

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// Simple fade transition
  static CustomTransitionPage<T> fade<T>({
    required Widget child,
    required GoRouterState state,
    Duration duration = defaultDuration,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    );
  }

  /// No transition (instant)
  static CustomTransitionPage<T> none<T>({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }
}
