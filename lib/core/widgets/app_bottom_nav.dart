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
        embedded ? 6 : 8,
        embedded ? 6 : 8,
        embedded ? 6 : 8,
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
        final gutter = compact ? 2.0 : 3.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutBack,
              left: currentIndex * itemWidth + gutter,
              top: compact ? 1 : 0,
              bottom: compact ? 1 : 0,
              width: itemWidth - (gutter * 2),
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
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withAlpha(isDark ? 34 : 122),
            palette.accent.withAlpha(isDark ? 54 : 34),
            palette.accentStrong.withAlpha(isDark ? 34 : 20),
          ],
          stops: const [0, 0.46, 1],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(58)
              : Colors.white.withAlpha(210),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.glow.withAlpha(isDark ? 46 : 24),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withAlpha(isDark ? 14 : 74),
            blurRadius: 16,
            spreadRadius: -10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 18 : 20),
                gradient: RadialGradient(
                  center: const Alignment(0, -0.18),
                  radius: 1,
                  colors: [
                    Colors.white.withAlpha(isDark ? 38 : 116),
                    Colors.white.withAlpha(0),
                    Colors.black.withAlpha(isDark ? 28 : 0),
                  ],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            top: 1,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withAlpha(isDark ? 96 : 190),
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
          vertical: compact ? 8 : 10,
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
                    end: selected ? palette.accent : palette.textSecondary,
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
                  end: selected ? palette.textPrimary : palette.textSecondary,
                ),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, color, child) => Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
