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
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 8 : 10,
                    horizontal: compact ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: index == currentIndex
                        ? LinearGradient(
                            colors: [
                              palette.accentSoft,
                              palette.glow.withAlpha(18),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    border: index == currentIndex
                        ? Border.all(color: palette.border)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            items[index].$1,
                            size: compact ? 22 : 24,
                            color: index == currentIndex
                                ? palette.accent
                                : palette.textSecondary,
                          ),
                          if (index == 2 && hasActiveRoom)
                            const Positioned(
                              right: -1,
                              top: -1,
                              child: _LiveDot(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10 : 11,
                          fontWeight: index == currentIndex
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: index == currentIndex
                              ? palette.textPrimary
                              : palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (embedded) {
      return nav;
    }

    return SafeArea(top: false, child: nav);
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
