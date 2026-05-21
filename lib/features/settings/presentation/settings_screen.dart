import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/glass_panel.dart';
import '../../library/data/library_repository.dart';
import '../../music/domain/music_models.dart';
import '../../player/data/download_manager.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsRepositoryProvider);
    final library = ref.watch(libraryRepositoryProvider);

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
