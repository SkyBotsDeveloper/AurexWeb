import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/glass_panel.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Aurex')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aurex', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  'Aurex is a premium music experience shaped by Siddhartha Abhimanyu, a solo developer who wanted listening to feel cleaner, calmer, and more personal.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'The idea behind Aurex was simple: music apps should feel fast, polished, and easy to live in every day. Good playback, good discovery, shared listening, and less clutter.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Aurex is being built with a strong focus on usability, smooth interaction, and a premium feel without making the experience heavy or confusing.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From The Developer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  'Siddhartha Abhimanyu is building this project independently, with attention on the details people actually notice: easier playback, cleaner layouts, better shared moments, and an app that keeps improving over time.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Connect',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _ContactTile(
            title: 'Telegram',
            value: '@iflexelite',
            uri: Uri.parse('https://t.me/iflexelite'),
          ),
          _ContactTile(
            title: 'Instagram',
            value: 'instagram.com/elite.sid',
            uri: Uri.parse('https://www.instagram.com/elite.sid/'),
          ),
          _ContactTile(
            title: 'Email',
            value: 'skybotsdeveloper@gmail.com',
            uri: Uri.parse('mailto:skybotsdeveloper@gmail.com'),
          ),
          _ContactTile(
            title: 'GitHub',
            value: 'github.com/SkyBotsDeveloper',
            uri: Uri.parse('https://github.com/SkyBotsDeveloper'),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.title,
    required this.value,
    required this.uri,
  });

  final String title;
  final String value;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.open_in_new_rounded),
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
  }
}
