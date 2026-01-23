class VideoSettings {
  final int fps;
  final String quality; // 'LOW', 'MEDIUM', 'HIGH'

  const VideoSettings({
    this.fps = 15,
    this.quality = 'MEDIUM',
  });

  Map<String, dynamic> toJson() => {
        'fps': fps,
        'quality': quality,
      };

  factory VideoSettings.fromJson(Map<String, dynamic> json) {
    return VideoSettings(
      fps: json['fps'] as int? ?? 15,
      quality: json['quality'] as String? ?? 'MEDIUM',
    );
  }

  VideoSettings copyWith({
    int? fps,
    String? quality,
  }) {
    return VideoSettings(
      fps: fps ?? this.fps,
      quality: quality ?? this.quality,
    );
  }
}
