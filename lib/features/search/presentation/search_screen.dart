import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/artwork_card.dart';
import '../../../core/widgets/app_shell_scope.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/screen_intro_panel.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../library/data/library_repository.dart';
import '../../music/data/aurex_api_client.dart';
import '../../music/data/music_repository.dart';
import '../../music/domain/music_models.dart';
import '../../music/presentation/open_media_summary.dart';
import '../../player/data/playback_controller.dart';
import '../../rooms/data/room_session_controller.dart';

const _searchGroupVisibleLimit = 5;
const _searchQueueRelatedLimit = 3;
const _relatedSearchTrackTimeout = Duration(seconds: 2);

class _MergedSongResult {
  const _MergedSongResult.primary(this.primarySong) : onlineSong = null;

  const _MergedSongResult.online(this.onlineSong) : primarySong = null;

  final MediaSummary? primarySong;
  final AurexSong? onlineSong;

  bool get isOnline => onlineSong != null;
  String get id => onlineSong?.id ?? primarySong!.id;
  String get title => onlineSong?.title ?? primarySong!.title;
  String get artist =>
      onlineSong?.channel ??
      primarySong!.artistText ??
      primarySong!.subtitle ??
      'Unknown artist';
  String? get artworkUrl =>
      onlineSong?.image ?? onlineSong?.thumbnail ?? primarySong?.artworkUrl;
}

class _SongIdentity {
  const _SongIdentity({required this.title, required this.artist});

  final String title;
  final String artist;

  bool matches(_SongIdentity other) {
    if (title.isEmpty || title != other.title) {
      return false;
    }
    if (artist.isEmpty || other.artist.isEmpty) {
      return false;
    }
    if (artist == other.artist) {
      return true;
    }
    final shorterLength = artist.length < other.artist.length
        ? artist.length
        : other.artist.length;
    return shorterLength >= 4 &&
        (artist.contains(other.artist) || other.artist.contains(artist));
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  Future<SearchResults>? _searchFuture;
  late final Future<List<HomeSection>> _trendingFuture;
  String _query = '';
  CancelToken? _onlineSearchCancelToken;
  int _onlineSearchVersion = 0;
  bool _onlineSearchLoading = false;
  String? _onlineSearchError;
  List<AurexSong> _onlineResults = const [];
  String? _loadingLocalSongId;
  String? _loadingOnlineSongId;
  int _songPlaybackVersion = 0;

  @override
  void initState() {
    super.initState();
    _trendingFuture = ref.read(musicRepositoryProvider).fetchTrendingSections();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _onlineSearchCancelToken?.cancel('Search screen disposed');
    _songPlaybackVersion++;
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final query = value.trim();
      if (!mounted) {
        return;
      }
      _onlineSearchCancelToken?.cancel('Query changed');
      setState(() {
        _query = query;
        _onlineSearchCancelToken = null;
        _onlineSearchVersion++;
        _onlineSearchLoading = false;
        _onlineSearchError = null;
        _onlineResults = const [];
        _loadingLocalSongId = null;
        _loadingOnlineSongId = null;
        _songPlaybackVersion++;
        _searchFuture = query.length < 2
            ? null
            : ref.read(musicRepositoryProvider).searchAll(query);
      });
      if (query.length >= 2) {
        unawaited(_startOnlineSearch());
      }
    });
  }

  void _applySuggestion(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _onChanged(value);
    setState(() {});
  }

  void _clearSearch() {
    _controller.clear();
    _debounce?.cancel();
    _onlineSearchCancelToken?.cancel('Search cleared');
    setState(() {
      _query = '';
      _searchFuture = null;
      _onlineSearchCancelToken = null;
      _onlineSearchVersion++;
      _onlineSearchLoading = false;
      _onlineSearchError = null;
      _onlineResults = const [];
      _loadingLocalSongId = null;
      _loadingOnlineSongId = null;
      _songPlaybackVersion++;
    });
  }

  Future<void> _startOnlineSearch({bool forceRefresh = false}) async {
    final query = _query.trim();
    if (query.length < 2) {
      return;
    }

    _onlineSearchCancelToken?.cancel('Superseded online search');
    final version = ++_onlineSearchVersion;
    final cancelToken = CancelToken();

    setState(() {
      _onlineSearchCancelToken = cancelToken;
      _onlineSearchLoading = true;
      _onlineSearchError = null;
    });

    try {
      final results = await ref
          .read(aurexApiClientProvider)
          .searchAurexSongs(
            query,
            cancelToken: cancelToken,
            forceRefresh: forceRefresh,
          );
      if (!mounted || version != _onlineSearchVersion) {
        return;
      }
      setState(() {
        _onlineSearchLoading = false;
        _onlineResults = results;
        _onlineSearchCancelToken = null;
      });
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }
      if (!mounted || version != _onlineSearchVersion) {
        return;
      }
      setState(() {
        _onlineSearchLoading = false;
        _onlineSearchError = 'Online search is temporarily unavailable.';
        _onlineSearchCancelToken = null;
      });
    } catch (error) {
      if (!mounted || version != _onlineSearchVersion) {
        return;
      }
      setState(() {
        _onlineSearchLoading = false;
        _onlineSearchError = friendlyErrorMessage(
          error,
          fallback: 'Online search is temporarily unavailable.',
        );
        _onlineSearchCancelToken = null;
      });
    }
  }

  Future<void> _playOnlineSong(
    AurexSong song,
    List<AurexSong> onlineCandidates,
  ) async {
    if (!_canStartPlayback() || _loadingOnlineSongId == song.id) {
      return;
    }
    final playbackVersion = ++_songPlaybackVersion;
    setState(() {
      _loadingLocalSongId = null;
      _loadingOnlineSongId = song.id;
    });

    try {
      final client = ref.read(aurexApiClientProvider);
      final controller = ref.read(playbackControllerProvider);
      final track = await client.resolvePlayableTrack(song);
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }
      await controller.setQueue([track], initialTrackId: track.id);
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }
      unawaited(
        _appendOnlineSuggestions(
          selected: song,
          candidates: onlineCandidates,
          selectedTrackId: track.id,
          playbackVersion: playbackVersion,
          client: client,
          controller: controller,
        ),
      );
    } catch (error) {
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: 'Could not load this song. Please try another result.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted &&
          playbackVersion == _songPlaybackVersion &&
          _loadingOnlineSongId == song.id) {
        setState(() => _loadingOnlineSongId = null);
      }
    }
  }

  Future<void> _playPrimarySearchSong(
    MediaSummary selected,
    List<MediaSummary> visibleSongs,
    List<AurexSong> onlineCandidates,
  ) async {
    if (selected.type != MusicItemType.song) {
      await openMediaSummary(context, ref, selected);
      return;
    }
    if (!_canStartPlayback()) {
      return;
    }

    final playbackVersion = ++_songPlaybackVersion;
    setState(() {
      _loadingLocalSongId = selected.id;
      _loadingOnlineSongId = null;
    });

    try {
      final repository = ref.read(musicRepositoryProvider);
      final selectedTrack = await repository.fetchSong(selected.id);
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }

      final candidates = _orderedPrimaryCandidates(selected, visibleSongs);
      final related = candidates.where((item) => item.id != selected.id);
      final relatedEntries = await Future.wait(
        related.map((item) async {
          try {
            return MapEntry(
              item.id,
              await repository
                  .fetchSong(item.id)
                  .timeout(_relatedSearchTrackTimeout),
            );
          } catch (error, stackTrace) {
            AppLogger.instance.w(
              'Skipping primary search queue item ${item.id}',
              error: error,
              stackTrace: stackTrace,
            );
            return null;
          }
        }),
      );
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }

      final tracksBySummaryId = <String, Track>{selected.id: selectedTrack};
      for (final entry in relatedEntries) {
        if (entry != null) {
          tracksBySummaryId[entry.key] = entry.value;
        }
      }

      final relatedTracks = <Track>[];
      final relatedTrackIds = <String>{};
      for (final item in candidates) {
        if (item.id == selected.id) {
          continue;
        }
        final track = tracksBySummaryId[item.id];
        if (track == null || !relatedTrackIds.add(track.id)) {
          continue;
        }
        relatedTracks.add(track);
      }
      final rankedRelated = relatedTracks.length > _searchQueueRelatedLimit
          ? await ref
                .read(libraryRepositoryProvider)
                .rankSuggestions(relatedTracks, limit: _searchQueueRelatedLimit)
          : relatedTracks;
      final queue = <Track>[selectedTrack, ...rankedRelated];

      final controller = ref.read(playbackControllerProvider);
      await controller.setQueue(
        queue,
        initialIndex: 0,
        initialTrackId: selectedTrack.id,
      );
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }
      unawaited(
        _appendRankedOnlineTracks(
          suggestions: onlineCandidates,
          selectedTrackId: selectedTrack.id,
          playbackVersion: playbackVersion,
          client: ref.read(aurexApiClientProvider),
          controller: controller,
        ),
      );
    } catch (error) {
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: 'Could not load this song. Please try another result.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted &&
          playbackVersion == _songPlaybackVersion &&
          _loadingLocalSongId == selected.id) {
        setState(() => _loadingLocalSongId = null);
      }
    }
  }

  List<MediaSummary> _orderedPrimaryCandidates(
    MediaSummary selected,
    List<MediaSummary> visibleSongs,
  ) {
    final candidates = <MediaSummary>[];
    final seenIds = <String>{};
    for (final item in visibleSongs.take(_searchGroupVisibleLimit)) {
      if (item.type == MusicItemType.song && seenIds.add(item.id)) {
        candidates.add(item);
      }
    }
    if (seenIds.add(selected.id)) {
      candidates.insert(0, selected);
    }
    return candidates;
  }

  Future<void> _appendOnlineSuggestions({
    required AurexSong selected,
    required List<AurexSong> candidates,
    required String selectedTrackId,
    required int playbackVersion,
    required AurexApiClient client,
    required PlaybackController controller,
  }) async {
    final selectedIndex = candidates.indexWhere(
      (result) => result.id == selected.id,
    );
    if (selectedIndex < 0 || candidates.length < 2) {
      return;
    }

    final suggestions = <AurexSong>[];
    for (var offset = 1; offset < candidates.length; offset++) {
      suggestions.add(candidates[(selectedIndex + offset) % candidates.length]);
    }

    await _appendRankedOnlineTracks(
      suggestions: suggestions,
      selectedTrackId: selectedTrackId,
      playbackVersion: playbackVersion,
      client: client,
      controller: controller,
    );
  }

  Future<void> _appendRankedOnlineTracks({
    required List<AurexSong> suggestions,
    required String selectedTrackId,
    required int playbackVersion,
    required AurexApiClient client,
    required PlaybackController controller,
  }) async {
    final ranked = await _rankOnlineSuggestions(suggestions, limit: 3);
    await _appendOnlineTracks(
      suggestions: ranked,
      selectedTrackId: selectedTrackId,
      playbackVersion: playbackVersion,
      client: client,
      controller: controller,
    );
  }

  Future<List<AurexSong>> _rankOnlineSuggestions(
    List<AurexSong> candidates, {
    required int limit,
  }) async {
    if (candidates.length <= limit) {
      return candidates.take(limit).toList(growable: false);
    }
    final byTrackId = {for (final song in candidates) song.id: song};
    final rankedTracks = await ref
        .read(libraryRepositoryProvider)
        .rankSuggestions(
          candidates.map((song) => song.toTrack()),
          limit: limit,
        );
    return rankedTracks
        .map((track) => byTrackId[track.id])
        .whereType<AurexSong>()
        .toList(growable: false);
  }

  Future<void> _appendOnlineTracks({
    required List<AurexSong> suggestions,
    required String selectedTrackId,
    required int playbackVersion,
    required AurexApiClient client,
    required PlaybackController controller,
  }) async {
    for (final suggestion in suggestions) {
      if (!mounted || playbackVersion != _songPlaybackVersion) {
        return;
      }
      if (controller.snapshot.currentTrack?.id != selectedTrackId) {
        return;
      }
      try {
        final track = await client.resolvePlayableTrack(suggestion);
        if (!mounted || playbackVersion != _songPlaybackVersion) {
          return;
        }
        await controller.appendToQueue([
          track,
        ], expectedCurrentTrackId: selectedTrackId);
      } catch (error, stackTrace) {
        AppLogger.instance.w(
          'Skipping Aurex search queue suggestion ${suggestion.id}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  List<_MergedSongResult> _mergeSongResults(
    List<MediaSummary> primarySongs,
    List<AurexSong> onlineSongs,
  ) {
    final merged = <_MergedSongResult>[];
    final identities = <_SongIdentity>[];
    final seenIds = <String>{};

    for (final song in primarySongs.take(_searchGroupVisibleLimit)) {
      if (!seenIds.add(song.id.trim().toLowerCase())) {
        continue;
      }
      merged.add(_MergedSongResult.primary(song));
      identities.add(
        _SongIdentity(
          title: _normalizeSongPart(song.title),
          artist: _normalizeSongPart(song.artistText ?? song.subtitle ?? ''),
        ),
      );
    }

    for (final song in onlineSongs) {
      if (merged.length >= 10) {
        break;
      }
      final id = song.id.trim().toLowerCase();
      final identity = _SongIdentity(
        title: _normalizeSongPart(song.title),
        artist: _normalizeSongPart(song.channel),
      );
      if (!seenIds.add(id) ||
          identities.any((existing) => existing.matches(identity))) {
        continue;
      }
      merged.add(_MergedSongResult.online(song));
      identities.add(identity);
    }
    return merged;
  }

  String _normalizeSongPart(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(
          RegExp(
            r'\b(official|video|audio|lyrics?|lyrical|hd|4k|full song)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _canStartPlayback() {
    final roomSession = ref.read(roomSessionControllerProvider);
    if (!roomSession.controlsLocked) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(roomPlaybackLockedMessage(roomSession))),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          isCompact ? 18 : 24,
          20,
          AppShellScope.bottomInsetOf(context, fallback: 32),
        ),
        children: [
          ScreenIntroPanel(
            compact: isCompact,
            eyebrow: 'Search',
            title: isCompact
                ? 'Find the next song quickly.'
                : 'Find the next song, artist, album, or playlist quickly.',
            description: isCompact
                ? 'Search once and jump straight into the right result.'
                : 'No guessing where to tap next. Search once and move directly into the result that matters.',
            footer: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'What do you want to hear?',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _clearSearch();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_searchFuture == null)
            FutureBuilder<List<HomeSection>>(
              future: _trendingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const MediaRailSkeleton();
                }

                final sections = snapshot.data ?? const <HomeSection>[];
                final suggestions = sections
                    .expand((section) => section.items)
                    .map((item) => item.title)
                    .where((title) => title.trim().isNotEmpty)
                    .toSet()
                    .take(8)
                    .toList();
                final browseItems = sections
                    .expand((section) => section.items)
                    .where((item) => item.title.trim().isNotEmpty)
                    .take(isCompact ? 6 : 8)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (suggestions.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Popular Searches',
                        subtitle: isCompact
                            ? 'Jump in fast'
                            : 'Tap a suggestion and we handle the rest',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final suggestion in suggestions)
                            ActionChip(
                              label: Text(suggestion),
                              onPressed: () => _applySuggestion(suggestion),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (browseItems.isNotEmpty) ...[
                      SectionHeader(
                        title: 'Trending Right Now',
                        subtitle: isCompact
                            ? 'Tap once to explore'
                            : 'A cleaner way to browse what listeners are opening most',
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: browseItems.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isCompact ? 2 : 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: isCompact ? 1.14 : 1.2,
                        ),
                        itemBuilder: (context, index) {
                          final item = browseItems[index];
                          return _BrowseTile(item: item);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    for (final section in sections) ...[
                      SectionHeader(
                        title: section.title,
                        subtitle: section.subtitle,
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
                      const SizedBox(height: 24),
                    ],
                  ],
                );
              },
            )
          else
            FutureBuilder<SearchResults>(
              future: _searchFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ResultsListSkeleton(groupCount: 2);
                }
                final result =
                    snapshot.data ??
                    const SearchResults(
                      topQuery: [],
                      songs: [],
                      albums: [],
                      artists: [],
                      playlists: [],
                    );
                final mergedSongs = _mergeSongResults(
                  result.songs,
                  _onlineResults,
                );
                final mergedOnlineSongs = mergedSongs
                    .where((item) => item.onlineSong != null)
                    .map((item) => item.onlineSong!)
                    .toList(growable: false);
                final hasAnyResults =
                    result.topQuery.isNotEmpty ||
                    mergedSongs.isNotEmpty ||
                    result.albums.isNotEmpty ||
                    result.artists.isNotEmpty ||
                    result.playlists.isNotEmpty;
                if (!hasAnyResults && !_onlineSearchLoading) {
                  final failed =
                      snapshot.hasError && _onlineSearchError != null;
                  return StateScaffold(
                    icon: failed
                        ? Icons.error_outline_rounded
                        : Icons.search_off_rounded,
                    title: failed ? 'Search failed' : 'No results found',
                    message: failed
                        ? friendlyErrorMessage(
                            snapshot.error,
                            fallback: _onlineSearchError!,
                          )
                        : 'Try a different song title or artist.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.topQuery.isNotEmpty) ...[
                      _TopResultCard(
                        item: result.topQuery.first,
                        isLoading:
                            _loadingLocalSongId == result.topQuery.first.id,
                        onTap: () => _playPrimarySearchSong(
                          result.topQuery.first,
                          result.songs,
                          mergedOnlineSongs,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    _MergedSongsSection(
                      items: mergedSongs,
                      isFindingMore: _onlineSearchLoading,
                      onlineError: _onlineSearchError,
                      loadingLocalSongId: _loadingLocalSongId,
                      loadingOnlineSongId: _loadingOnlineSongId,
                      onRetry: () => _startOnlineSearch(forceRefresh: true),
                      onPrimarySelected: (item) => _playPrimarySearchSong(
                        item,
                        result.songs,
                        mergedOnlineSongs,
                      ),
                      onOnlineSelected: (song) =>
                          _playOnlineSong(song, mergedOnlineSongs),
                    ),
                    _SearchGroup(title: 'Albums', items: result.albums),
                    _SearchGroup(title: 'Artists', items: result.artists),
                    _SearchGroup(title: 'Playlists', items: result.playlists),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MergedSongsSection extends StatelessWidget {
  const _MergedSongsSection({
    required this.items,
    required this.isFindingMore,
    required this.onlineError,
    required this.loadingLocalSongId,
    required this.loadingOnlineSongId,
    required this.onRetry,
    required this.onPrimarySelected,
    required this.onOnlineSelected,
  });

  final List<_MergedSongResult> items;
  final bool isFindingMore;
  final String? onlineError;
  final String? loadingLocalSongId;
  final String? loadingOnlineSongId;
  final VoidCallback onRetry;
  final ValueChanged<MediaSummary> onPrimarySelected;
  final ValueChanged<AurexSong> onOnlineSelected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final hasStatus = isFindingMore || onlineError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Songs',
          subtitle: 'Best matches first',
          trailing: items.isEmpty
              ? null
              : Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _MergedSongTile(
                  item: items[index],
                  isLoading: items[index].isOnline
                      ? loadingOnlineSongId == items[index].id
                      : loadingLocalSongId == items[index].id,
                  onTap: () {
                    final onlineSong = items[index].onlineSong;
                    if (onlineSong != null) {
                      onOnlineSelected(onlineSong);
                    } else {
                      onPrimarySelected(items[index].primarySong!);
                    }
                  },
                ),
                if (index < items.length - 1 || hasStatus)
                  Divider(color: palette.border.withAlpha(120), height: 20),
              ],
              if (isFindingMore)
                const _SearchSongsStatus(
                  icon: CircularProgressIndicator(strokeWidth: 2),
                  message: 'Finding more songs...',
                )
              else if (onlineError != null)
                _SearchSongsStatus(
                  icon: Icon(
                    Icons.cloud_off_rounded,
                    color: palette.textSecondary,
                  ),
                  message: 'More songs are temporarily unavailable.',
                  action: TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                )
              else if (items.isEmpty)
                const _SearchSongsStatus(
                  icon: Icon(Icons.search_off_rounded),
                  message: 'No songs found for this search.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _SearchSongsStatus extends StatelessWidget {
  const _SearchSongsStatus({
    required this.icon,
    required this.message,
    this.action,
  });

  final Widget icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(dimension: 20, child: Center(child: icon)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        ?action,
      ],
    );
  }
}

class _MergedSongTile extends StatelessWidget {
  const _MergedSongTile({
    required this.item,
    required this.isLoading,
    required this.onTap,
  });

  final _MergedSongResult item;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return ListTile(
      enabled: !isLoading,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 54,
          height: 54,
          child: NetworkArtwork(
            imageUrl: item.artworkUrl,
            cleanArtworkQuery: item.title,
            cleanArtworkType: 'song',
            cleanArtworkSubtitle: item.artist,
            fallbackIcon: Icons.music_note_rounded,
            iconSize: 28,
          ),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: isLoading
          ? const Text('Preparing queue...')
          : Row(
              children: [
                Expanded(
                  child: Text(
                    item.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isOnline) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent.withAlpha(24),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.accent.withAlpha(70)),
                    ),
                    child: Text(
                      'Online',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
      trailing: isLoading
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          : const Icon(Icons.play_arrow_rounded),
      onTap: isLoading ? null : onTap,
    );
  }
}

class _TopResultCard extends StatelessWidget {
  const _TopResultCard({
    required this.item,
    required this.isLoading,
    required this.onTap,
  });

  final MediaSummary item;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 76,
                height: 76,
                child: NetworkArtwork(
                  imageUrl: item.artworkUrl,
                  cleanArtworkQuery: item.title,
                  cleanArtworkType: item.type.name,
                  cleanArtworkSubtitle:
                      item.artistText ?? item.description ?? item.subtitle,
                  fallbackIcon: Icons.music_note_rounded,
                  iconSize: 34,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Result',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.artistText ??
                        item.subtitle ??
                        item.description ??
                        'Open details',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: palette.accent,
              child: isLoading
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: palette.background,
                      ),
                    )
                  : Icon(Icons.play_arrow_rounded, color: palette.background),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchGroup extends ConsumerWidget {
  const _SearchGroup({required this.title, required this.items});

  final String title;
  final List<MediaSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = AppColors.of(context);
    final visibleItems = items.take(_searchGroupVisibleLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          subtitle: 'Best matches first',
          trailing: Text(
            '${items.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (var index = 0; index < visibleItems.length; index++) ...[
                _SearchResultTile(
                  item: visibleItems[index],
                  onTap: () =>
                      openMediaSummary(context, ref, visibleItems[index]),
                ),
                if (index < visibleItems.length - 1)
                  Divider(color: palette.border.withAlpha(120), height: 20),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _BrowseTile extends ConsumerWidget {
  const _BrowseTile({required this.item});

  final MediaSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => openMediaSummary(context, ref, item),
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: NetworkArtwork(
                  imageUrl: item.artworkUrl,
                  cleanArtworkQuery: item.title,
                  cleanArtworkType: item.type.name,
                  cleanArtworkSubtitle:
                      item.artistText ?? item.description ?? item.subtitle,
                  fallbackIcon: Icons.music_note_rounded,
                  iconSize: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.artistText ?? item.subtitle ?? item.type.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final MediaSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 54,
          height: 54,
          child: NetworkArtwork(
            imageUrl: item.artworkUrl,
            cleanArtworkQuery: item.title,
            cleanArtworkType: item.type.name,
            cleanArtworkSubtitle:
                item.artistText ?? item.description ?? item.subtitle,
            fallbackIcon: Icons.music_note_rounded,
            iconSize: 28,
          ),
        ),
      ),
      title: Text(item.title),
      subtitle: Text(item.artistText ?? item.subtitle ?? item.type.name),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
