import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/rooms/data/room_session_controller.dart';
import '../theme/app_colors.dart';
import 'glass_panel.dart';

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (_NavItem(Icons.home_rounded, 'Home')),
    (_NavItem(Icons.search_rounded, 'Search')),
    (_NavItem(Icons.groups_rounded, 'Rooms')),
    (_NavItem(Icons.library_music_rounded, 'Library')),
    (_NavItem(Icons.person_rounded, 'Profile')),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final hasActiveRoom = ref
        .watch(roomSessionControllerProvider)
        .hasActiveRoom;

    return SizedBox(
      width: 116,
      child: Column(
        children: [
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.all(9),
                  child: Image.asset(
                    'assets/branding/aurex_logo_square.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Aurex', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                children: [
                  for (var index = 0; index < _items.length; index++) ...[
                    _RailDestination(
                      item: _items[index],
                      selected: currentIndex == index,
                      showLiveDot: index == 2 && hasActiveRoom,
                      onTap: () => onTap(index),
                    ),
                    if (index < _items.length - 1) const SizedBox(height: 8),
                  ],
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Settings',
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.item,
    required this.selected,
    required this.showLiveDot,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final bool showLiveDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: selected ? Border.all(color: palette.border) : null,
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    item.icon,
                    color: selected ? palette.accent : palette.textSecondary,
                  ),
                  if (showLiveDot)
                    const Positioned(right: -2, top: -2, child: _LiveDot()),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? palette.textPrimary : palette.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
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
          BoxShadow(color: palette.glow, blurRadius: 10, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.label);

  final IconData icon;
  final String label;
}
