import 'package:uuid/uuid.dart';

import '../../music/domain/music_models.dart';

class DownloadRecord {
  const DownloadRecord({
    required this.track,
    required this.localPath,
    required this.quality,
    required this.downloadedAt,
    required this.fileSizeBytes,
  });

  final Track track;
  final String localPath;
  final AudioQuality quality;
  final DateTime downloadedAt;
  final int? fileSizeBytes;

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
        track: Track.fromJson(Map<String, dynamic>.from(json['track'] as Map)),
        localPath: json['localPath'] as String,
        quality: AudioQuality.fromKey(json['quality'] as String?),
        downloadedAt: DateTime.parse(json['downloadedAt'] as String),
        fileSizeBytes: json['fileSizeBytes'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'track': track.toJson(),
        'localPath': localPath,
        'quality': quality.key,
        'downloadedAt': downloadedAt.toIso8601String(),
        'fileSizeBytes': fileSizeBytes,
      };
}

class UserPlaylist {
  UserPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.tracks,
  });

  factory UserPlaylist.create(String name) => UserPlaylist(
        id: const Uuid().v4(),
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        tracks: const [],
      );

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Track> tracks;

  UserPlaylist copyWith({
    String? name,
    DateTime? updatedAt,
    List<Track>? tracks,
  }) {
    return UserPlaylist(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tracks: tracks ?? this.tracks,
    );
  }

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        tracks: (json['tracks'] as List<dynamic>? ?? const [])
            .map((item) => Track.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'tracks': tracks.map((track) => track.toJson()).toList(),
      };
}
