import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FrostedGlass extends StatelessWidget {
  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blurSigma = 14,
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
            ? palette.surfaceElevated.withAlpha(92)
            : Colors.white.withAlpha(120));
    final borderColor = isDark
        ? Colors.white.withAlpha(42)
        : Colors.white.withAlpha(210);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withAlpha(isDark ? 118 : 48),
              blurRadius: 42,
              spreadRadius: -14,
              offset: const Offset(0, 22),
            ),
            BoxShadow(
              color: palette.accent.withAlpha(isDark ? 30 : 18),
              blurRadius: 38,
              spreadRadius: -20,
              offset: const Offset(0, 13),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: borderRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withAlpha(isDark ? 48 : 120),
                          tint.withAlpha(isDark ? 74 : 112),
                          palette.accentStrong.withAlpha(isDark ? 24 : 14),
                          Colors.black.withAlpha(isDark ? 13 : 0),
                        ],
                        stops: const [0, 0.34, 0.74, 1],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.08),
                        radius: 1.08,
                        colors: [
                          Colors.white.withAlpha(isDark ? 38 : 72),
                          Colors.white.withAlpha(0),
                          Colors.black.withAlpha(isDark ? 22 : 0),
                        ],
                        stops: const [0, 0.64, 1],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withAlpha(isDark ? 36 : 82),
                            Colors.white.withAlpha(0),
                            Colors.black.withAlpha(isDark ? 18 : 0),
                          ],
                          stops: const [0, 0.38, 1],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.all(color: borderColor, width: 0.9),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 1,
                  height: 2.2,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(isDark ? 168 : 228),
                            Colors.white.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 1,
                  height: 1,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0),
                            palette.accent.withAlpha(isDark ? 34 : 24),
                            Colors.white.withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
