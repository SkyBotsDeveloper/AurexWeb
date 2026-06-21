import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blurSigma = 20,
    this.tintColor,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Color? tintColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint =
        tintColor ??
        (isDark
            ? palette.surfaceElevated.withAlpha(178)
            : Colors.white.withAlpha(184));
    final borderColor = isDark
        ? Colors.white.withAlpha(38)
        : Colors.white.withAlpha(220);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withAlpha(isDark ? 112 : 54),
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: palette.accent.withAlpha(isDark ? 22 : 14),
              blurRadius: 24,
              spreadRadius: -14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tint,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withAlpha(isDark ? 24 : 104),
                    tint.withAlpha(isDark ? 164 : 176),
                    palette.accent.withAlpha(isDark ? 12 : 8),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
