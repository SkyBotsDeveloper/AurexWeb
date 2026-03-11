import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artwork_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/screen_intro_panel.dart';
import '../../../core/widgets/section_header.dart';
import '../../library/data/library_repository.dart';
import '../../music/data/music_repository.dart';
import '../../music/domain/music_models.dart';
import '../../music/presentation/open_media_summary.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';

final homeSectionsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(musicRepositoryProvider).fetchHomeSections(),
);
final recentlyPlayedProvider = StreamProvider.autoDispose<List<Track>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchHistory(),
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final sections = ref.watch(homeSectionsProvider);
    final recentTracks = ref.watch(recentlyPlayedProvider);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final recentItems = (recentTracks.asData?.value ?? const <Track>[])
        .take(4)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeSectionsProvider.future),
        child: AsyncValueView(
          value: sections,
          data: (items) {
            final featuredItem = items.isEmpty || items.first.items.isEmpty
                ? null
                : items.first.items.first;

            return ListView(
              padding: EdgeInsets.fromLTRB(20, isCompact ? 18 : 24, 20, 32),
              children: [
                _HomeHero(
                  featuredItem: featuredItem,
                  roomSession: roomSession,
                  isCompact: isCompact,
                  onSettings: () => context.push('/settings'),
                  onSearch: () => context.go('/search'),
                  onLibrary: () => context.go('/library'),
                  onRoom: () => roomSession.hasActiveRoom
                      ? context.push('/room/${roomSession.roomId}')
                      : context.go('/room'),
                  onFeatured: featuredItem == null
                      ? null
                      : () => openMediaSummary(context, ref, featuredItem),
                ),
                const SizedBox(height: 18),
                if (roomSession.hasActiveRoom) ...[
                  GlassPanel(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            color: palette.accent,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roomSession.roomName ?? 'Active Room',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                roomSession.isHost
                                    ? 'You are hosting. Anything you play syncs across the room.'
                                    : 'You can browse freely, but playback stays under the host until you leave.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: () =>
                              context.push('/room/${roomSession.roomId}'),
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (recentItems.isNotEmpty) ...[
                  SectionHeader(
                    title: 'Jump Back In',
                    subtitle: isCompact
                        ? 'Resume in one tap'
                        : 'Your fastest way back to what you were hearing',
                    trailing: TextButton(
                      onPressed: () => context.go('/library'),
                      child: const Text('Library'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (isCompact)
                    Column(
                      children: [
                        for (var index = 0; index < recentItems.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == recentItems.length - 1 ? 0 : 12,
                            ),
                            child: _RecentTrackTile(
                              track: recentItems[index],
                              lockedMessage: roomSession.controlsLocked
                                  ? roomPlaybackLockedMessage(roomSession)
                                  : null,
                              onTap: () async {
                                if (roomSession.controlsLocked) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        roomPlaybackLockedMessage(roomSession),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                await ref
                                    .read(playbackControllerProvider)
                                    .playTrack(recentItems[index]);
                              },
                            ),
                          ),
                      ],
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth >= 760
                            ? 3
                            : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recentItems.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 2.45,
                              ),
                          itemBuilder: (context, index) {
                            final track = recentItems[index];
                            return _RecentTrackTile(
                              track: track,
                              lockedMessage: roomSession.controlsLocked
                                  ? roomPlaybackLockedMessage(roomSession)
                                  : null,
                              onTap: () async {
                                if (roomSession.controlsLocked) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        roomPlaybackLockedMessage(roomSession),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                await ref
                                    .read(playbackControllerProvider)
                                    .playTrack(track);
                              },
                            );
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 28),
                ],
                for (final section in items) ...[
                  SectionHeader(
                    title: section.title,
                    subtitle: section.subtitle,
                    trailing: Text(
                      '${section.items.length} picks',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: isCompact ? 212 : 240,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: section.items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final item = section.items[index];
                        return ArtworkCard(
                          item: item,
                          width: isCompact ? 148 : 172,
                          height: isCompact ? 204 : 232,
                          onTap: () => openMediaSummary(context, ref, item),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.featuredItem,
    required this.roomSession,
    required this.isCompact,
    required this.onSettings,
    required this.onSearch,
    required this.onLibrary,
    required this.onRoom,
    required this.onFeatured,
  });

  final MediaSummary? featuredItem;
  final RoomSessionState roomSession;
  final bool isCompact;
  final VoidCallback onSettings;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onRoom;
  final VoidCallback? onFeatured;

  @override
  Widget build(BuildContext context) {
    return ScreenIntroPanel(
      compact: isCompact,
      eyebrow: roomSession.hasActiveRoom
          ? roomSession.isHost
                ? 'Room is live'
                : 'Listening with your room'
          : 'Welcome back',
      title: isCompact
          ? 'Pick up the next song faster.'
          : 'Pick up the next song without slowing down.',
      description: roomSession.hasActiveRoom
          ? roomSession.isHost
                ? 'You are hosting. Anything you play from anywhere in the app keeps the room together.'
                : 'Browse the app freely while the host controls playback for everyone in the room.'
          : 'Search fast, jump back in, or open a room without digging through the app first.',
      trailing: IconButton.filledTonal(
        onPressed: onSettings,
        icon: const Icon(Icons.tune_rounded),
      ),
      actions: [
        FilledButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded),
          label: const Text('Search'),
        ),
        OutlinedButton.icon(
          onPressed: onLibrary,
          icon: const Icon(Icons.library_music_rounded),
          label: const Text('Library'),
        ),
        OutlinedButton.icon(
          onPressed: onRoom,
          icon: Icon(
            roomSession.hasActiveRoom
                ? Icons.graphic_eq_rounded
                : Icons.groups_rounded,
          ),
          label: Text(roomSession.hasActiveRoom ? 'Open Room' : 'Rooms'),
        ),
      ],
      footer: featuredItem == null
          ? null
          : _FeaturedStrip(item: featuredItem!, onPressed: onFeatured),
    );
  }
}

class _FeaturedStrip extends StatelessWidget {
  const _FeaturedStrip({required this.item, required this.onPressed});

  final MediaSummary item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceInset,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 52,
              height: 52,
              child: item.artworkUrl == null
                  ? Container(
                      color: palette.accentSoft,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: palette.accent,
                      ),
                    )
                  : Image.network(item.artworkUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try this next',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  item.artistText ??
                      item.subtitle ??
                      item.description ??
                      'Featured pick',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonal(onPressed: onPressed, child: const Text('Play')),
        ],
      ),
    );
  }
}

class _RecentTrackTile extends StatelessWidget {
  const _RecentTrackTile({
    required this.track,
    required this.onTap,
    required this.lockedMessage,
  });

  final Track track;
  final VoidCallback onTap;
  final String? lockedMessage;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: palette.tileGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: palette.surfaceBright,
                ),
                clipBehavior: Clip.antiAlias,
                child: track.artworkUrl == null
                    ? Icon(Icons.music_note_rounded, color: palette.accent)
                    : Image.network(track.artworkUrl!, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lockedMessage ?? track.artistNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lockedMessage == null
                      ? palette.accentSoft
                      : palette.surfaceInset,
                ),
                child: Icon(
                  lockedMessage == null
                      ? Icons.play_arrow_rounded
                      : Icons.lock_outline_rounded,
                  color: lockedMessage == null
                      ? palette.accent
                      : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
