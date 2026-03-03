import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// A convenience widget that resolves the current [DeviceType] and
/// [Orientation] using [LayoutBuilder] + [OrientationBuilder], then invokes
/// the appropriate builder callback.
///
/// At minimum you must supply [mobile]. The other builders fall back in
/// this order:
///   desktop → tablet → mobile → mobileSmall (if not provided)
///   mobileSmall → mobile (if not provided)
///
/// Example:
/// ```dart
/// ResponsiveBuilder(
///   mobile: (ctx, orientation) => MobileLayout(),
///   tablet: (ctx, orientation) => TabletLayout(),
/// )
/// ```
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    this.mobileSmall,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Builder for screens narrower than 360 lp.
  /// Falls back to [mobile] when omitted.
  final Widget Function(BuildContext context, Orientation orientation)?
      mobileSmall;

  /// Builder for standard mobile (360–600 lp). **Required**.
  final Widget Function(BuildContext context, Orientation orientation) mobile;

  /// Builder for tablet (600–1024 lp). Falls back to [mobile].
  final Widget Function(BuildContext context, Orientation orientation)? tablet;

  /// Builder for desktop (>1024 lp). Falls back to [tablet], then [mobile].
  final Widget Function(BuildContext context, Orientation orientation)? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = Breakpoints.fromConstraints(constraints);

        return OrientationBuilder(
          builder: (context, orientation) {
            return switch (deviceType) {
              DeviceType.mobileSmall =>
                (mobileSmall ?? mobile).call(context, orientation),
              DeviceType.mobile => mobile(context, orientation),
              DeviceType.tablet =>
                (tablet ?? mobile).call(context, orientation),
              DeviceType.desktop =>
                (desktop ?? tablet ?? mobile).call(context, orientation),
            };
          },
        );
      },
    );
  }
}

/// A simpler variant that only hands down the [DeviceType] without
/// orientation, useful for minor adaptive tweaks (padding, font size, etc.).
class AdaptiveBuilder extends StatelessWidget {
  const AdaptiveBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = Breakpoints.fromConstraints(constraints);
        return builder(context, deviceType);
      },
    );
  }
}
