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
            ? palette.surfaceElevated.withAlpha(118)
            : Colors.white.withAlpha(138));
    final borderColor = isDark
        ? Colors.white.withAlpha(52)
        : Colors.white.withAlpha(232);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withAlpha(isDark ? 132 : 54),
              blurRadius: 38,
              spreadRadius: -11,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: palette.accent.withAlpha(isDark ? 38 : 22),
              blurRadius: 34,
              spreadRadius: -18,
              offset: const Offset(0, 11),
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
                          Colors.white.withAlpha(isDark ? 34 : 116),
                          tint.withAlpha(isDark ? 104 : 126),
                          palette.accentStrong.withAlpha(isDark ? 22 : 12),
                          Colors.black.withAlpha(isDark ? 24 : 0),
                        ],
                        stops: const [0, 0.38, 0.72, 1],
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
                          Colors.white.withAlpha(isDark ? 24 : 64),
                          Colors.white.withAlpha(0),
                          Colors.black.withAlpha(isDark ? 44 : 0),
                        ],
                        stops: const [0, 0.58, 1],
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
                            Colors.white.withAlpha(isDark ? 28 : 74),
                            Colors.white.withAlpha(0),
                            Colors.black.withAlpha(isDark ? 26 : 0),
                          ],
                          stops: const [0, 0.34, 1],
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
                        border: Border.all(color: borderColor, width: 1.15),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 1,
                  height: 1.8,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0),
                            Colors.white.withAlpha(isDark ? 150 : 220),
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
