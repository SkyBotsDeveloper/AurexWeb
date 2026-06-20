import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../library/data/library_repository.dart';
import '../../music/domain/music_models.dart';
import '../../player/data/aurex_audio_cache_repository.dart';
import '../../player/data/download_manager.dart';
import '../../player/data/playback_controller.dart';
import '../data/settings_repository.dart';

final _smartCacheSizeProvider = FutureProvider.autoDispose<int?>((ref) {
  return ref.watch(aurexAudioCacheRepositoryProvider).cacheSizeBytes();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isClearingSmartCache = false;

  Future<void> _clearSmartCache() async {
    if (_isClearingSmartCache) {
      return;
    }
    setState(() => _isClearingSmartCache = true);
    try {
      final protectedFilePath = await ref
          .read(playbackControllerProvider)
          .currentAurexCacheFilePath();
      final result = await ref
          .read(aurexAudioCacheRepositoryProvider)
          .clearCache(protectedFilePath: protectedFilePath);
      ref.invalidate(_smartCacheSizeProvider);
      if (!mounted) {
        return;
      }
      final message = result.retainedCurrentFile
          ? 'Smart Cache cleared except the song currently playing.'
          : result.deletedFileCount == 0
          ? 'Smart Cache is already empty.'
          : 'Smart Cache cleared.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: 'Smart Cache could not be cleared. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearingSmartCache = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsRepositoryProvider);
    final library = ref.watch(libraryRepositoryProvider);
    final smartCacheSize = ref.watch(_smartCacheSizeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder(
        valueListenable: settings.notifier,
        builder: (context, current, child) {
          final palette = AppColors.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppThemePreference.values.map((preference) {
                        final selected = current.themePreference == preference;
                        return ChoiceChip(
                          avatar: Icon(
                            preference == AppThemePreference.light
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            size: 18,
                            color: selected
                                ? palette.accent
                                : palette.textSecondary,
                          ),
                          label: Text(preference.label),
                          selected: selected,
                          onSelected: (_) =>
                              settings.updateThemePreference(preference),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Theme Color',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppThemeColorPreference.values.map((
                        preference,
                      ) {
                        final selected =
                            current.themeColorPreference == preference;
                        return ChoiceChip(
                          avatar: _ThemeColorSwatch(
                            color: preference.accent,
                            selected: selected,
                          ),
                          label: Text(preference.label),
                          selected: selected,
                          onSelected: (_) =>
                              settings.updateThemeColorPreference(preference),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Streaming Quality',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: AudioQuality.values.map((quality) {
                        return ChoiceChip(
                          label: Text(quality.label),
                          selected: current.streamingQuality == quality,
                          onSelected: (_) =>
                              settings.updateStreamingQuality(quality),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Download Quality',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: AudioQuality.values
                          .where((quality) => quality != AudioQuality.auto)
                          .map((quality) {
                            return ChoiceChip(
                              label: Text(quality.label),
                              selected: current.downloadQuality == quality,
                              onSelected: (_) =>
                                  settings.updateDownloadQuality(quality),
                            );
                          })
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Cache',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: kIsWeb ? false : current.smartCacheEnabled,
                      onChanged: kIsWeb ? null : settings.setSmartCacheEnabled,
                      title: const Text('Cache online songs'),
                      subtitle: Text(
                        kIsWeb
                            ? 'Smart Cache is available on Android and desktop.'
                            : current.smartCacheEnabled
                            ? 'Replay recently used Aurex songs from this device.'
                            : 'Online songs will use stream playback only.',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.storage_rounded),
                      title: const Text('Storage used'),
                      subtitle: Text(
                        kIsWeb
                            ? 'Local audio caching is unavailable in browsers.'
                            : smartCacheSize.when(
                                data: (bytes) => bytes == null
                                    ? 'Cache size is unavailable.'
                                    : '${formatBytes(bytes)} used',
                                error: (_, _) => 'Cache size is unavailable.',
                                loading: () => 'Calculating storage...',
                              ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_sweep_rounded),
                      title: const Text('Clear Smart Cache'),
                      subtitle: const Text(
                        'Remove temporary Aurex audio stored on this device.',
                      ),
                      trailing: _isClearingSmartCache
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: kIsWeb || _isClearingSmartCache
                          ? null
                          : _clearSmartCache,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Playback',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: current.autoQuality,
                      onChanged: settings.setAutoQuality,
                      title: const Text('Auto quality'),
                      subtitle: const Text(
                        'Prefer balanced quality when bandwidth is uncertain.',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: current.rememberQueue,
                      onChanged: settings.setRememberQueue,
                      title: const Text('Resume playback state'),
                      subtitle: const Text(
                        'Restore queue, track index, and position on relaunch.',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: current.autoResyncRooms,
                      onChanged: settings.setAutoResyncRooms,
                      title: const Text('Auto-resync rooms'),
                      subtitle: const Text(
                        'Prefer timestamp correction when room drift crosses threshold.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    FutureBuilder<int>(
                      future: library.totalDownloadBytes(),
                      builder: (context, snapshot) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Storage usage'),
                        subtitle: Text(
                          '${formatBytes(snapshot.data ?? 0)} in downloads',
                        ),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Clear downloads'),
                      trailing: const Icon(Icons.delete_sweep_rounded),
                      onTap: () =>
                          ref.read(downloadManagerProvider).clearDownloads(),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('About Us'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/about'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: selected ? palette.textPrimary : palette.border,
          width: selected ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: color.withAlpha(90), blurRadius: 10)],
      ),
    );
  }
}
