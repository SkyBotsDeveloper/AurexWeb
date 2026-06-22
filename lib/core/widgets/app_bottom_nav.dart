import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/rooms/data/room_session_controller.dart';
import '../theme/app_colors.dart';

class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.embedded = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveRoom = ref
        .watch(roomSessionControllerProvider)
        .hasActiveRoom;
    final compact = MediaQuery.sizeOf(context).width < 430;
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.search_rounded, 'Search'),
      (Icons.groups_rounded, 'Rooms'),
      (Icons.library_music_rounded, 'Library'),
      (Icons.person_rounded, 'Profile'),
    ];

    final nav = Container(
      margin: embedded
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: EdgeInsets.fromLTRB(
        embedded ? 7 : 8,
        embedded ? 7 : 8,
        embedded ? 7 : 8,
        embedded ? 8 : 8,
      ),
      decoration: embedded
          ? null
          : BoxDecoration(
              gradient: palette.navGradient,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: palette.border.withAlpha(220)),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow.withAlpha(90),
                  blurRadius: 36,
                  offset: Offset(0, 20),
                ),
              ],
            ),
      child: _LiquidNavItems(
        items: items,
        currentIndex: currentIndex,
        compact: compact,
        isDark: isDark,
        hasActiveRoom: hasActiveRoom,
        onTap: onTap,
      ),
    );

    if (embedded) {
      return nav;
    }

    return SafeArea(top: false, child: nav);
  }
}

class _LiquidNavItems extends StatelessWidget {
  const _LiquidNavItems({
    required this.items,
    required this.currentIndex,
    required this.compact,
    required this.isDark,
    required this.hasActiveRoom,
    required this.onTap,
  });

  final List<(IconData, String)> items;
  final int currentIndex;
  final bool compact;
  final bool isDark;
  final bool hasActiveRoom;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / items.length;
        final indicatorWidth = math.min(
          itemWidth - (compact ? 12 : 16),
          compact ? 74.0 : 88.0,
        );
        final indicatorLeft =
            (currentIndex * itemWidth) + ((itemWidth - indicatorWidth) / 2);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              left: indicatorLeft,
              top: compact ? 5 : 6,
              bottom: compact ? 5 : 6,
              width: indicatorWidth,
              child: _LiquidNavIndicator(compact: compact, isDark: isDark),
            ),
            Row(
              children: [
                for (var index = 0; index < items.length; index++)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onTap(index),
                      child: _LiquidNavItem(
                        icon: items[index].$1,
                        label: items[index].$2,
                        selected: index == currentIndex,
                        compact: compact,
                        showLiveDot: index == 2 && hasActiveRoom,
                        palette: palette,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LiquidNavIndicator extends StatelessWidget {
  const _LiquidNavIndicator({required this.compact, required this.isDark});

  final bool compact;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 20 : 22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(isDark ? 58 : 138),
            palette.accent.withAlpha(isDark ? 48 : 30),
            palette.accentStrong.withAlpha(isDark ? 38 : 22),
            Colors.white.withAlpha(isDark ? 16 : 74),
          ],
          stops: const [0, 0.4, 0.72, 1],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(42)
              : Colors.white.withAlpha(190),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.glow.withAlpha(isDark ? 50 : 26),
            blurRadius: 28,
            spreadRadius: -9,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(isDark ? 28 : 82),
            blurRadius: 18,
            spreadRadius: -11,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 20 : 22),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.24),
                  radius: 0.92,
                  colors: [
                    Colors.white.withAlpha(isDark ? 62 : 132),
                    Colors.white.withAlpha(0),
                    Colors.black.withAlpha(isDark ? 10 : 0),
                  ],
                  stops: const [0, 0.68, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 1,
            height: 1.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withAlpha(isDark ? 128 : 208),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidNavItem extends StatelessWidget {
  const _LiquidNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.showLiveDot,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final bool showLiveDot;
  final AurexPalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      scale: selected ? 1.035 : 1,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 8 : 9,
          horizontal: compact ? 2 : 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    end: selected
                        ? palette.accent
                        : palette.textSecondary.withAlpha(190),
                  ),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  builder: (context, color, _) =>
                      Icon(icon, size: compact ? 22 : 24, color: color),
                ),
                if (showLiveDot)
                  const Positioned(right: -1, top: -1, child: _LiveDot()),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  end: selected
                      ? palette.textPrimary.withAlpha(238)
                      : palette.textSecondary.withAlpha(178),
                ),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, color, child) => Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 9.6 : 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: palette.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: palette.glow, blurRadius: 12, spreadRadius: 1),
        ],
      ),
    );
  }
}
