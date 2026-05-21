import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/artwork_card.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../../core/widgets/network_artwork.dart';
import '../../../core/widgets/screen_intro_panel.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../core/widgets/state_scaffold.dart';
import '../../music/data/aurex_api_client.dart';
import '../../music/data/music_repository.dart';
import '../../music/domain/music_models.dart';
import '../../music/presentation/open_media_summary.dart';
import '../../player/data/playback_controller.dart';

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
  bool _onlineSearchRequested = false;
  bool _onlineSearchLoading = false;
  String? _onlineSearchError;
  List<AurexSong> _onlineResults = const [];
  String? _loadingOnlineSongId;

  @override
  void initState() {
    super.initState();
    _trendingFuture = ref.read(musicRepositoryProvider).fetchTrendingSections();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _onlineSearchCancelToken?.cancel('Search screen disposed');
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
        _onlineSearchRequested = false;
        _onlineSearchLoading = false;
        _onlineSearchError = null;
        _onlineResults = const [];
        _loadingOnlineSongId = null;
        _searchFuture = query.length < 2
            ? null
            : ref.read(musicRepositoryProvider).searchAll(query);
      });
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
      _onlineSearchRequested = false;
      _onlineSearchLoading = false;
      _onlineSearchError = null;
      _onlineResults = const [];
      _loadingOnlineSongId = null;
    });
  }

  void _startOnlineSearchAfterFrame() {
    if (_query.length < 2 || _onlineSearchRequested || _onlineSearchLoading) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _onlineSearchRequested || _onlineSearchLoading) {
        return;
      }
      unawaited(_startOnlineSearch());
    });
  }

  Future<void> _startOnlineSearch() async {
    final query = _query.trim();
    if (query.length < 2) {
      return;
    }

    _onlineSearchCancelToken?.cancel('Superseded online search');
    final version = ++_onlineSearchVersion;
    final cancelToken = CancelToken();

    setState(() {
      _onlineSearchCancelToken = cancelToken;
      _onlineSearchRequested = true;
      _onlineSearchLoading = true;
      _onlineSearchError = null;
    });

    try {
      final results = await ref
          .read(aurexApiClientProvider)
          .searchAurexSongs(query, cancelToken: cancelToken);
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

  Future<void> _playOnlineSong(AurexSong song) async {
    if (_loadingOnlineSongId == song.id) {
      return;
    }
    setState(() => _loadingOnlineSongId = song.id);

    try {
      final track = await ref
          .read(aurexApiClientProvider)
          .resolvePlayableTrack(song);
      await ref.read(playbackControllerProvider).playTrack(track);
    } catch (error) {
      if (!mounted) {
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
      if (mounted && _loadingOnlineSongId == song.id) {
        setState(() => _loadingOnlineSongId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, isCompact ? 18 : 24, 20, 32),
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
                if (snapshot.hasError) {
                  return StateScaffold(
                    icon: Icons.error_outline_rounded,
                    title: 'Search failed',
                    message: friendlyErrorMessage(snapshot.error),
                  );
                }
                final result = snapshot.data;
                if (result == null || result.isEmpty) {
                  _startOnlineSearchAfterFrame();
                  return _OnlineResultsSection(
                    showEmptyLocalMessage: true,
                    isLoading: _onlineSearchLoading || !_onlineSearchRequested,
                    error: _onlineSearchError,
                    results: _onlineResults,
                    loadingSongId: _loadingOnlineSongId,
                    onRetry: _startOnlineSearch,
                    onSongSelected: _playOnlineSong,
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.topQuery.isNotEmpty) ...[
                      _TopResultCard(item: result.topQuery.first),
                      const SizedBox(height: 24),
                    ],
                    _SearchGroup(title: 'Songs', items: result.songs),
                    _SearchGroup(title: 'Albums', items: result.albums),
                    _SearchGroup(title: 'Artists', items: result.artists),
                    _SearchGroup(title: 'Playlists', items: result.playlists),
                    _SearchOnlineAction(
                      isLoading: _onlineSearchLoading,
                      isRequested: _onlineSearchRequested,
                      onPressed: _startOnlineSearch,
                    ),
                    _OnlineResultsSection(
                      isLoading: _onlineSearchLoading,
                      error: _onlineSearchError,
                      results: _onlineResults,
                      loadingSongId: _loadingOnlineSongId,
                      onRetry: _startOnlineSearch,
                      onSongSelected: _playOnlineSong,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SearchOnlineAction extends StatelessWidget {
  const _SearchOnlineAction({
    required this.isLoading,
    required this.isRequested,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isRequested;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isRequested ? 'Refresh online results' : 'Search online too';
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.public_rounded),
          label: Text(isLoading ? 'Searching online...' : label),
        ),
      ),
    );
  }
}

class _OnlineResultsSection extends StatelessWidget {
  const _OnlineResultsSection({
    required this.isLoading,
    required this.error,
    required this.results,
    required this.loadingSongId,
    required this.onRetry,
    required this.onSongSelected,
    this.showEmptyLocalMessage = false,
  });

  final bool isLoading;
  final String? error;
  final List<AurexSong> results;
  final String? loadingSongId;
  final VoidCallback onRetry;
  final ValueChanged<AurexSong> onSongSelected;
  final bool showEmptyLocalMessage;

  @override
  Widget build(BuildContext context) {
    if (!showEmptyLocalMessage &&
        !isLoading &&
        error == null &&
        results.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = AppColors.of(context);
    final subtitle = showEmptyLocalMessage
        ? 'No local results. Searching online...'
        : 'Aurex API fallback results';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Online results',
          subtitle: isLoading ? subtitle : 'Resolve only when you press play',
          trailing: results.isEmpty
              ? null
              : Text(
                  '${results.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
        ),
        const SizedBox(height: 12),
        if (isLoading && results.isEmpty)
          const ResultsListSkeleton(groupCount: 1, rowCount: 4)
        else if (error != null)
          GlassPanel(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: palette.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          )
        else if (results.isEmpty)
          const StateScaffold(
            icon: Icons.search_off_rounded,
            title: 'No online results',
            message: 'Try a different song title or artist.',
          )
        else
          GlassPanel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                if (isLoading) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Searching online...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Divider(color: palette.border.withAlpha(120), height: 22),
                ],
                for (var index = 0; index < results.length; index++) ...[
                  _OnlineResultTile(
                    song: results[index],
                    isLoading: loadingSongId == results[index].id,
                    onSelected: onSongSelected,
                  ),
                  if (index < results.length - 1)
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

class _OnlineResultTile extends StatelessWidget {
  const _OnlineResultTile({
    required this.song,
    required this.isLoading,
    required this.onSelected,
  });

  final AurexSong song;
  final bool isLoading;
  final ValueChanged<AurexSong> onSelected;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      song.channel,
      if ((song.duration ?? '').trim().isNotEmpty) song.duration!,
    ];

    return ListTile(
      enabled: !isLoading,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 54,
          height: 54,
          child: NetworkArtwork(
            imageUrl: song.image ?? song.thumbnail,
            fallbackIcon: Icons.music_note_rounded,
            iconSize: 28,
          ),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        isLoading ? 'Loading song...' : subtitleParts.join(' - '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : FilledButton.tonalIcon(
              onPressed: () => onSelected(song),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play'),
            ),
      onTap: isLoading ? null : () => onSelected(song),
    );
  }
}

class _TopResultCard extends ConsumerWidget {
  const _TopResultCard({required this.item});

  final MediaSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppColors.of(context);
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: InkWell(
        onTap: () => openMediaSummary(context, ref, item),
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
              child: Icon(Icons.play_arrow_rounded, color: palette.background),
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
    final visibleItems = items.take(5).toList();

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
                _SearchResultTile(item: visibleItems[index]),
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

class _SearchResultTile extends ConsumerWidget {
  const _SearchResultTile({required this.item});

  final MediaSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      onTap: () => openMediaSummary(context, ref, item),
    );
  }
}
