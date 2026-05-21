import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artwork_card.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';
import '../data/music_repository.dart';
import '../domain/music_models.dart';
import 'open_media_summary.dart';

enum DiscoveryKind { radio, channel }

class DiscoveryDetailScreen extends ConsumerWidget {
  const DiscoveryDetailScreen({
    super.key,
    required this.id,
    required this.kind,
    this.initial,
  });

  final String id;
  final DiscoveryKind kind;
  final MediaSummary? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = _load(ref);
    final bottomPadding = MediaQuery.sizeOf(context).width >= 1120
        ? 32.0
        : 140.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(kind == DiscoveryKind.radio ? 'Radio' : 'Category'),
      ),
      body: FutureBuilder<_DiscoveryPageData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return StateScaffold(
              icon: Icons.error_outline_rounded,
              title: 'Unable to open this section',
              message: snapshot.error.toString(),
            );
          }

          final data = snapshot.data!;
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
            children: [
              _DiscoveryHero(data: data),
              const SizedBox(height: 22),
              if (data.search.songs.isNotEmpty) ...[
                SectionHeader(
                  title: 'Playable Mix',
                  subtitle: 'Tap a track or start the full mix',
                  trailing: Text(
                    '${data.search.songs.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 12),
                _SongResultsList(items: data.search.songs),
                const SizedBox(height: 24),
              ],
              if (data.search.playlists.isNotEmpty) ...[
                _SummaryRail(
                  title: 'Playlists',
                  subtitle: 'Curated sets for this vibe',
                  items: data.search.playlists,
                ),
                const SizedBox(height: 24),
              ],
              if (data.search.albums.isNotEmpty) ...[
                _SummaryRail(
                  title: 'Albums',
                  subtitle: 'Related albums and releases',
                  items: data.search.albums,
                ),
                const SizedBox(height: 24),
              ],
              if (data.detail.related.isNotEmpty) ...[
                _SummaryRail(
                  title: 'Related Categories',
                  subtitle: 'Keep browsing without dead ends',
                  items: data.detail.related,
                ),
                const SizedBox(height: 24),
              ],
              if (data.search.isEmpty && data.detail.related.isEmpty)
                const StateScaffold(
                  icon: Icons.travel_explore_rounded,
                  title: 'Nothing matched yet',
                  message:
                      'This station is available, but matching songs were not returned by the music source right now.',
                ),
            ],
          );
        },
      ),
    );
  }

  Future<_DiscoveryPageData> _load(WidgetRef ref) async {
    final repository = ref.read(musicRepositoryProvider);
    final detail = kind == DiscoveryKind.radio
        ? await repository.fetchRadioStation(id)
        : await repository.fetchChannel(id);
    final source = _mergeInitial(detail.source);
    final query = _searchQuery(source);
    final search = await repository.searchDiscovery(query);
    return _DiscoveryPageData(
      detail: DiscoveryDetail(
        source: source,
        related: detail.related,
        nowPlaying: detail.nowPlaying,
        message: detail.message,
      ),
      search: search,
      kind: kind,
    );
  }

  MediaSummary _mergeInitial(MediaSummary fetched) {
    final fallback = initial;
    if (fallback == null) {
      return fetched;
    }
    return MediaSummary(
      id: fetched.id.isNotEmpty ? fetched.id : fallback.id,
      title: fetched.title.trim().isNotEmpty ? fetched.title : fallback.title,
      type: fetched.type == MusicItemType.unknown
          ? fallback.type
          : fetched.type,
      image: fetched.image.isNotEmpty ? fetched.image : fallback.image,
      description: fetched.description ?? fallback.description,
      subtitle: fetched.subtitle ?? fallback.subtitle,
      url: fetched.url ?? fallback.url,
      language: fetched.language ?? fallback.language,
      songCount: fetched.songCount ?? fallback.songCount,
      followerCount: fetched.followerCount ?? fallback.followerCount,
      releaseDate: fetched.releaseDate ?? fallback.releaseDate,
      artistText: fetched.artistText ?? fallback.artistText,
    );
  }

  String _searchQuery(MediaSummary source) {
    final base = source.title.trim();
    if (base.isEmpty) {
      return id;
    }
    if (kind == DiscoveryKind.radio &&
        (source.subtitle ?? '').toLowerCase().contains('hindi')) {
      return '$base Hindi';
    }
    return base;
  }
}

class _DiscoveryPageData {
  const _DiscoveryPageData({
    required this.detail,
    required this.search,
    required this.kind,
  });

  final DiscoveryDetail detail;
  final DiscoverySearchResults search;
  final DiscoveryKind kind;
}

class _DiscoveryHero extends ConsumerWidget {
  const _DiscoveryHero({required this.data});

  final _DiscoveryPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final roomSession = ref.watch(roomSessionControllerProvider);
    final source = data.detail.source;
    final playableCount =
        data.search.songs.length + (data.detail.nowPlaying == null ? 0 : 1);
    final description =
        source.description ??
        source.subtitle ??
        (data.kind == DiscoveryKind.radio
            ? 'A radio-inspired mix with matching songs and playlists.'
            : 'A focused category page with songs, playlists, albums, and related moods.');

    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 144,
              height: 144,
              child: NetworkArtwork(
                imageUrl: source.artworkUrl,
                fallbackIcon: data.kind == DiscoveryKind.radio
                    ? Icons.radio_rounded
                    : Icons.category_rounded,
                iconSize: 42,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    data.kind == DiscoveryKind.radio ? 'Radio' : 'Category',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  source.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(description, style: Theme.of(context).textTheme.bodyLarge),
                if (data.detail.message != null &&
                    data.detail.nowPlaying == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    data.detail.message!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
                if (roomSession.controlsLocked) ...[
                  const SizedBox(height: 10),
                  Text(
                    roomPlaybackLockedMessage(roomSession),
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: palette.warning),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          playableCount == 0 || roomSession.controlsLocked
                          ? null
                          : () => _playDiscoveryMix(context, ref, data),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play Mix'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          playableCount == 0 || roomSession.controlsLocked
                          ? null
                          : () => _loadDiscoveryMix(context, ref, data),
                      icon: const Icon(Icons.queue_music_rounded),
                      label: const Text('Load Mix'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SongResultsList extends ConsumerWidget {
  const _SongResultsList({required this.items});

  final List<MediaSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    final visibleItems = items.take(8).toList();

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var index = 0; index < visibleItems.length; index++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: NetworkArtwork(
                    imageUrl: visibleItems[index].artworkUrl,
                    fallbackIcon: Icons.music_note_rounded,
                    iconSize: 28,
                  ),
                ),
              ),
              title: Text(visibleItems[index].title),
              subtitle: Text(
                visibleItems[index].artistText ??
                    visibleItems[index].subtitle ??
                    'Song',
              ),
              trailing: const Icon(Icons.play_arrow_rounded),
              onTap: () => openMediaSummary(context, ref, visibleItems[index]),
            ),
            if (index < visibleItems.length - 1)
              Divider(color: palette.border.withAlpha(120), height: 16),
          ],
        ],
      ),
    );
  }
}

class _SummaryRail extends ConsumerWidget {
  const _SummaryRail({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<MediaSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 12),
        SizedBox(
          height: compact ? 212 : 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) => ArtworkCard(
              item: items[index],
              width: compact ? 148 : 172,
              height: compact ? 204 : 232,
              onTap: () => openMediaSummary(context, ref, items[index]),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _playDiscoveryMix(
  BuildContext context,
  WidgetRef ref,
  _DiscoveryPageData data,
) async {
  await _setDiscoveryQueue(context, ref, data, autoplay: true);
}

Future<void> _loadDiscoveryMix(
  BuildContext context,
  WidgetRef ref,
  _DiscoveryPageData data,
) async {
  await _setDiscoveryQueue(context, ref, data, autoplay: false);
}

Future<void> _setDiscoveryQueue(
  BuildContext context,
  WidgetRef ref,
  _DiscoveryPageData data, {
  required bool autoplay,
}) async {
  try {
    final repository = ref.read(musicRepositoryProvider);
    final tracks = <Track>[
      if (data.detail.nowPlaying != null) data.detail.nowPlaying!,
    ];
    for (final item in data.search.songs.take(8)) {
      final track = await repository.fetchSong(item.id);
      if (!tracks.any((existing) => existing.id == track.id)) {
        tracks.add(track);
      }
    }
    if (tracks.isEmpty) {
      throw StateError('No playable songs were found for this mix.');
    }
    await ref
        .read(playbackControllerProvider)
        .setQueue(tracks, autoplay: autoplay);
    if (!context.mounted) {
      return;
    }
    if (autoplay) {
      context.push('/player');
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${tracks.length} songs loaded')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
