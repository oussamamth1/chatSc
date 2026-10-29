class VideoInfo {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final double? durationSeconds;

  const VideoInfo({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.durationSeconds,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      thumbnailUrl: json['thumbnail']?.toString(),
      durationSeconds: (json['duration'] as num?)?.toDouble(),
    );
  }
}
