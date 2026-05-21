import 'package:collection/collection.dart';

import '../../../core/utils/json_utils.dart';

enum MusicItemType {
  song,
  album,
  artist,
  playlist,
  radio,
  channel,
  podcast,
  show,
  unknown;

  static MusicItemType parse(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'song':
        return MusicItemType.song;
      case 'album':
        return MusicItemType.album;
      case 'artist':
        return MusicItemType.artist;
      case 'playlist':
        return MusicItemType.playlist;
      case 'radio':
      case 'radio_station':
        return MusicItemType.radio;
      case 'channel':
        return MusicItemType.channel;
      case 'podcast':
        return MusicItemType.podcast;
      case 'show':
        return MusicItemType.show;
      default:
        return MusicItemType.unknown;
    }
  }
}

enum AudioQuality {
  auto,
  kbps12,
  kbps48,
  kbps96,
  kbps160,
  kbps320;

  String get key => switch (this) {
    AudioQuality.auto => 'auto',
    AudioQuality.kbps12 => '12kbps',
    AudioQuality.kbps48 => '48kbps',
    AudioQuality.kbps96 => '96kbps',
    AudioQuality.kbps160 => '160kbps',
    AudioQuality.kbps320 => '320kbps',
  };

  String get label => switch (this) {
    AudioQuality.auto => 'Auto',
    AudioQuality.kbps12 => 'Low',
    AudioQuality.kbps48 => 'Data Saver',
    AudioQuality.kbps96 => 'Balanced',
    AudioQuality.kbps160 => 'High',
    AudioQuality.kbps320 => 'Very High',
  };

  static AudioQuality fromKey(String? key) {
    return values.firstWhere(
      (quality) => quality.key == key,
      orElse: () => AudioQuality.auto,
    );
  }
}

class MediaImage {
  const MediaImage({required this.quality, required this.url});

  final String quality;
  final String url;

  factory MediaImage.fromJson(Map<String, dynamic> json) => MediaImage(
    quality: readString(json['quality']) ?? 'unknown',
    url: readString(json['url']) ?? '',
  );

  Map<String, dynamic> toJson() => {'quality': quality, 'url': url};
}

class AudioLink {
  const AudioLink({required this.quality, required this.url});

  final String quality;
  final String url;

  factory AudioLink.fromJson(Map<String, dynamic> json) => AudioLink(
    quality: readString(json['quality']) ?? 'unknown',
    url: (readString(json['url']) ?? '').trim(),
  );

  Map<String, dynamic> toJson() => {'quality': quality, 'url': url};
}

class ArtistRef {
  const ArtistRef({
    required this.id,
    required this.name,
    required this.role,
    required this.image,
    required this.url,
  });

  final String id;
  final String name;
  final String role;
  final List<MediaImage> image;
  final String? url;

  factory ArtistRef.fromJson(Map<String, dynamic> json) => ArtistRef(
    id: readString(json['id']) ?? '',
    name: readString(json['name']) ?? 'Unknown',
    role: readString(json['role']) ?? '',
    image: readMapList(json['image']).map(MediaImage.fromJson).toList(),
    url: readString(json['url']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'image': image.map((item) => item.toJson()).toList(),
    'url': url,
  };
}

class MediaSummary {
  const MediaSummary({
    required this.id,
    required this.title,
    required this.type,
    required this.image,
    required this.description,
    required this.subtitle,
    required this.url,
    required this.language,
    required this.songCount,
    required this.followerCount,
    required this.releaseDate,
    required this.artistText,
  });

  final String id;
  final String title;
  final MusicItemType type;
  final List<MediaImage> image;
  final String? description;
  final String? subtitle;
  final String? url;
  final String? language;
  final int? songCount;
  final int? followerCount;
  final DateTime? releaseDate;
  final String? artistText;

  String? get artworkUrl =>
      image.firstWhereOrNull((item) => item.quality == '500x500')?.url ??
      image.firstWhereOrNull((item) => item.quality == '150x150')?.url ??
      image.firstOrNull?.url;

  factory MediaSummary.fromJson(Map<String, dynamic> json) => MediaSummary(
    id: readString(json['id']) ?? '',
    title: readString(json['title']) ?? readString(json['name']) ?? 'Untitled',
    type: MusicItemType.parse(readString(json['type'])),
    image: readMapList(json['image']).map(MediaImage.fromJson).toList(),
    description: readString(json['description']),
    subtitle: readString(json['subtitle']),
    url: readString(json['url']),
    language: readString(json['language']),
    songCount: readInt(json['songCount']),
    followerCount: readInt(json['followerCount']),
    releaseDate: DateTime.tryParse(readString(json['releaseDate']) ?? ''),
    artistText:
        readString(json['artist']) ?? readString(json['primaryArtists']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'image': image.map((item) => item.toJson()).toList(),
    'description': description,
    'subtitle': subtitle,
    'url': url,
    'language': language,
    'songCount': songCount,
    'followerCount': followerCount,
    'releaseDate': releaseDate?.toIso8601String(),
    'artistText': artistText,
  };
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.albumId,
    required this.albumName,
    required this.duration,
    required this.image,
    required this.artists,
    required this.audioLinks,
    required this.language,
    required this.hasLyrics,
    required this.lyricsId,
    required this.url,
    required this.explicitContent,
    required this.year,
    required this.label,
    required this.playCount,
    required this.copyright,
    this.source = 'local',
    this.externalId,
  });

  final String id;
  final String title;
  final String? albumId;
  final String? albumName;
  final Duration? duration;
  final List<MediaImage> image;
  final List<ArtistRef> artists;
  final List<AudioLink> audioLinks;
  final String? language;
  final bool hasLyrics;
  final String? lyricsId;
  final String? url;
  final bool explicitContent;
  final String? year;
  final String? label;
  final int? playCount;
  final String? copyright;
  final String source;
  final String? externalId;

  String get artistNames {
    final names = artists.map((artist) => artist.name).join(', ').trim();
    if (names.isNotEmpty) {
      return names;
    }
    return albumName ?? 'Aurex';
  }

  String? get artworkUrl =>
      image.firstWhereOrNull((item) => item.quality == '500x500')?.url ??
      image.firstOrNull?.url;

  String? bestAudioUrl(AudioQuality quality) {
    final validLinks = audioLinks
        .where((item) => item.url.trim().isNotEmpty)
        .toList(growable: false);
    if (validLinks.isEmpty) {
      return null;
    }
    if (quality == AudioQuality.auto) {
      return validLinks
              .firstWhereOrNull(
                (item) => item.quality == AudioQuality.kbps160.key,
              )
              ?.url ??
          validLinks.last.url;
    }
    return validLinks
            .firstWhereOrNull((item) => item.quality == quality.key)
            ?.url ??
        validLinks.last.url;
  }

  bool get isAurexSource => source == 'aurex' || id.startsWith('aurex-');

  String? get aurexVideoId {
    if (!isAurexSource) {
      return null;
    }
    final candidate = externalId?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    return id.startsWith('aurex-') ? id.substring(6) : null;
  }

  factory Track.fromJson(Map<String, dynamic> json) {
    final artistsMap = readMap(json['artists']);
    final artistEntries = readMapList(artistsMap['all']).isNotEmpty
        ? readMapList(artistsMap['all'])
        : readMapList(artistsMap['primary']);

    final albumMap = readMap(json['album']);
    final showMap = readMap(json['show']);

    return Track(
      id: readString(json['id']) ?? '',
      title:
          readString(json['title']) ?? readString(json['name']) ?? 'Untitled',
      albumId: readString(albumMap['id']) ?? readString(showMap['id']),
      albumName:
          readString(albumMap['name']) ??
          readString(showMap['name']) ??
          readString(json['album']) ??
          readString(json['albumName']),
      duration: readInt(json['duration']) == null
          ? null
          : Duration(seconds: readInt(json['duration'])!),
      image: readMapList(json['image']).map(MediaImage.fromJson).toList(),
      artists: artistEntries.map(ArtistRef.fromJson).toList(),
      audioLinks: readMapList(
        json['downloadUrl'],
      ).map(AudioLink.fromJson).toList(),
      language: readString(json['language']),
      hasLyrics: readBool(json['hasLyrics']),
      lyricsId: readString(json['lyricsId']),
      url: readString(json['url']),
      explicitContent: readBool(json['explicitContent']),
      year: readString(json['year']),
      label: readString(json['label']),
      playCount: readInt(json['playCount']),
      copyright: readString(json['copyright']),
      source: readString(json['source']) ?? 'local',
      externalId: readString(json['externalId']) ?? readString(json['videoId']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'album': {'id': albumId, 'name': albumName},
    'duration': duration?.inSeconds,
    'image': image.map((item) => item.toJson()).toList(),
    'artists': {'all': artists.map((item) => item.toJson()).toList()},
    'downloadUrl': isAurexSource
        ? const <Map<String, dynamic>>[]
        : audioLinks.map((item) => item.toJson()).toList(),
    'language': language,
    'hasLyrics': hasLyrics,
    'lyricsId': lyricsId,
    'url': url,
    'explicitContent': explicitContent,
    'year': year,
    'label': label,
    'playCount': playCount,
    'copyright': copyright,
    'source': source,
    'externalId': externalId,
  };
}

class AurexSong {
  const AurexSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.channel,
    required this.duration,
    required this.thumbnail,
    required this.image,
    required this.videoId,
    required this.youtubeUrl,
  });

  final String id;
  final String source = 'aurex';
  final String title;
  final String artist;
  final String channel;
  final String? duration;
  final String? thumbnail;
  final String? image;
  final String videoId;
  final String? youtubeUrl;
  String? get audioUrl => null;

  Track toTrack({String? audioUrl}) {
    final artworkUrl = image ?? thumbnail;
    return Track(
      id: id,
      title: title,
      albumId: null,
      albumName: 'Aurex Online',
      duration: _parseDuration(duration),
      image: artworkUrl == null || artworkUrl.isEmpty
          ? const []
          : [
              MediaImage(quality: '500x500', url: artworkUrl),
              MediaImage(quality: '150x150', url: artworkUrl),
            ],
      artists: [
        ArtistRef(
          id: channel,
          name: artist,
          role: 'primary',
          image: const [],
          url: null,
        ),
      ],
      audioLinks: audioUrl == null || audioUrl.trim().isEmpty
          ? const []
          : [AudioLink(quality: AudioQuality.kbps160.key, url: audioUrl)],
      language: null,
      hasLyrics: false,
      lyricsId: null,
      url: youtubeUrl,
      explicitContent: false,
      year: null,
      label: 'Aurex API',
      playCount: null,
      copyright: null,
      source: source,
      externalId: videoId,
    );
  }

  static Duration? _parseDuration(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parts = value.split(':').map((part) => int.tryParse(part)).toList();
    if (parts.any((part) => part == null)) {
      return null;
    }
    if (parts.length == 2) {
      return Duration(minutes: parts[0]!, seconds: parts[1]!);
    }
    if (parts.length == 3) {
      return Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!);
    }
    return null;
  }
}

class AurexResolvedAudio {
  const AurexResolvedAudio({
    required this.videoId,
    required this.youtubeUrl,
    required this.streamLink,
    required this.directLink,
  });

  final String videoId;
  final String? youtubeUrl;
  final String? streamLink;
  final String? directLink;

  String? get playableUrl {
    final stream = streamLink?.trim();
    if (stream != null && stream.isNotEmpty) {
      return stream;
    }
    final direct = directLink?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    return null;
  }
}

class CollectionDetail {
  const CollectionDetail({
    required this.id,
    required this.title,
    required this.type,
    required this.description,
    required this.image,
    required this.artists,
    required this.songs,
    required this.songCount,
    required this.language,
    required this.year,
    required this.playCount,
  });

  final String id;
  final String title;
  final MusicItemType type;
  final String? description;
  final List<MediaImage> image;
  final List<ArtistRef> artists;
  final List<Track> songs;
  final int? songCount;
  final String? language;
  final String? year;
  final int? playCount;

  String? get artworkUrl =>
      image.firstWhereOrNull((item) => item.quality == '500x500')?.url ??
      image.firstOrNull?.url;

  factory CollectionDetail.fromJson(Map<String, dynamic> json) {
    final artistsRaw = json['artists'];
    final List<ArtistRef> artists;
    if (artistsRaw is List) {
      artists = artistsRaw
          .map((item) => ArtistRef.fromJson(readMap(item)))
          .toList();
    } else if (artistsRaw is Map) {
      final values = readMapList(readMap(artistsRaw)['primary']);
      artists = values.map(ArtistRef.fromJson).toList();
    } else {
      artists = const [];
    }

    return CollectionDetail(
      id: readString(json['id']) ?? '',
      title:
          readString(json['name']) ?? readString(json['title']) ?? 'Untitled',
      type: MusicItemType.parse(readString(json['type'])),
      description: readString(json['description']),
      image: readMapList(json['image']).map(MediaImage.fromJson).toList(),
      artists: artists,
      songs: readMapList(json['songs']).map(Track.fromJson).toList(),
      songCount: readInt(json['songCount']),
      language: readString(json['language']),
      year: readString(json['year']),
      playCount: readInt(json['playCount']),
    );
  }
}

class ArtistDetail {
  const ArtistDetail({
    required this.id,
    required this.name,
    required this.image,
    required this.bio,
    required this.followerCount,
    required this.topSongs,
    required this.topAlbums,
    required this.similarArtists,
    required this.availableLanguages,
    required this.isVerified,
  });

  final String id;
  final String name;
  final List<MediaImage> image;
  final String? bio;
  final int? followerCount;
  final List<Track> topSongs;
  final List<MediaSummary> topAlbums;
  final List<MediaSummary> similarArtists;
  final List<String> availableLanguages;
  final bool isVerified;

  String? get artworkUrl =>
      image.firstWhereOrNull((item) => item.quality == '500x500')?.url ??
      image.firstOrNull?.url;

  factory ArtistDetail.fromJson(Map<String, dynamic> json) => ArtistDetail(
    id: readString(json['id']) ?? '',
    name: readString(json['name']) ?? 'Unknown',
    image: readMapList(json['image']).map(MediaImage.fromJson).toList(),
    bio: readString(json['bio']) ?? readString(json['wiki']),
    followerCount: readInt(json['followerCount']) ?? readInt(json['fanCount']),
    topSongs: readMapList(json['topSongs']).map(Track.fromJson).toList(),
    topAlbums: readMapList(
      json['topAlbums'],
    ).map(MediaSummary.fromJson).toList(),
    similarArtists: readMapList(
      json['similarArtists'],
    ).map(MediaSummary.fromJson).toList(),
    availableLanguages:
        (json['availableLanguages'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const [],
    isVerified: readBool(json['isVerified']),
  );
}

class LyricsData {
  const LyricsData({
    required this.id,
    required this.lyrics,
    required this.lines,
    required this.snippet,
    required this.copyright,
  });

  final String id;
  final String lyrics;
  final List<String> lines;
  final String? snippet;
  final String? copyright;

  factory LyricsData.fromJson(Map<String, dynamic> json) => LyricsData(
    id: readString(json['id']) ?? '',
    lyrics: readString(json['lyrics']) ?? '',
    lines:
        (json['lines'] as List?)?.map((item) => item.toString()).toList() ??
        const [],
    snippet: readString(json['snippet']),
    copyright: readString(json['copyright']),
  );
}

class LyricsBundle {
  const LyricsBundle({
    this.synced,
    this.plain,
    this.sourceLabel = 'Current Source',
    this.usedFallback = false,
  });

  final SyncedLyricsData? synced;
  final LyricsData? plain;
  final String sourceLabel;
  final bool usedFallback;

  bool get hasSynced => synced != null && synced!.lines.isNotEmpty;
  bool get hasPlain =>
      plain != null &&
      (plain!.lyrics.trim().isNotEmpty || plain!.lines.isNotEmpty);
  bool get hasAny => hasSynced || hasPlain;
}

class DiscoveryDetail {
  const DiscoveryDetail({
    required this.source,
    required this.related,
    required this.nowPlaying,
    required this.message,
  });

  final MediaSummary source;
  final List<MediaSummary> related;
  final Track? nowPlaying;
  final String? message;
}

class DiscoverySearchResults {
  const DiscoverySearchResults({
    required this.songs,
    required this.playlists,
    required this.albums,
  });

  final List<MediaSummary> songs;
  final List<MediaSummary> playlists;
  final List<MediaSummary> albums;

  bool get isEmpty => songs.isEmpty && playlists.isEmpty && albums.isEmpty;
}

class PodcastDetail {
  const PodcastDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.language,
    required this.fanCount,
    required this.totalEpisodes,
    required this.episodes,
  });

  final String id;
  final String title;
  final String? description;
  final List<MediaImage> image;
  final String? language;
  final int? fanCount;
  final int? totalEpisodes;
  final List<Track> episodes;

  String? get artworkUrl =>
      image.firstWhereOrNull((item) => item.quality == '500x500')?.url ??
      image.firstOrNull?.url;

  factory PodcastDetail.fromJson(Map<String, dynamic> json) {
    final squareImages = readMapList(json['squareImage']);
    final images = squareImages.isNotEmpty
        ? squareImages
        : readMapList(json['image']);

    return PodcastDetail(
      id: readString(json['id']) ?? '',
      title:
          readString(json['name']) ?? readString(json['title']) ?? 'Untitled',
      description: readString(json['description']),
      image: images.map(MediaImage.fromJson).toList(),
      language: readString(json['language']),
      fanCount: readInt(json['fanCount']),
      totalEpisodes: readInt(json['totalEpisodes']),
      episodes: readMapList(json['episodes']).map(Track.fromJson).toList(),
    );
  }
}

class SyncedLyricLine {
  const SyncedLyricLine({
    required this.text,
    required this.startTimeMs,
    required this.endTimeMs,
  });

  final String text;
  final int startTimeMs;
  final int endTimeMs;

  factory SyncedLyricLine.fromJson(Map<String, dynamic> json) =>
      SyncedLyricLine(
        text: readString(json['text']) ?? '',
        startTimeMs: readInt(json['startTimeMs']) ?? 0,
        endTimeMs: readInt(json['endTimeMs']) ?? 0,
      );
}

class SyncedLyricsData {
  const SyncedLyricsData({
    required this.id,
    required this.hasSync,
    required this.duration,
    required this.lines,
    required this.source,
  });

  final String id;
  final bool hasSync;
  final int? duration;
  final List<SyncedLyricLine> lines;
  final String? source;

  factory SyncedLyricsData.fromJson(Map<String, dynamic> json) =>
      SyncedLyricsData(
        id: readString(json['id']) ?? '',
        hasSync: readBool(json['hasSync']),
        duration: readInt(json['duration']),
        lines: readMapList(
          json['lines'],
        ).map(SyncedLyricLine.fromJson).toList(),
        source: readString(json['source']),
      );
}

class HomeSection {
  const HomeSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.featured,
  });

  final String key;
  final String title;
  final String? subtitle;
  final List<MediaSummary> items;
  final bool featured;
}

class SearchResults {
  const SearchResults({
    required this.topQuery,
    required this.songs,
    required this.albums,
    required this.artists,
    required this.playlists,
  });

  final List<MediaSummary> topQuery;
  final List<MediaSummary> songs;
  final List<MediaSummary> albums;
  final List<MediaSummary> artists;
  final List<MediaSummary> playlists;

  bool get isEmpty =>
      topQuery.isEmpty &&
      songs.isEmpty &&
      albums.isEmpty &&
      artists.isEmpty &&
      playlists.isEmpty;
}
