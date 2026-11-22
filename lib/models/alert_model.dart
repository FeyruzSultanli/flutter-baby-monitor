class AlertModel {
  final DateTime timestamp;
  final String message;
  final double? decibel;
  /// How long the crying lasted (V2 5.9); null for older entries or while
  /// the cry is still going on.
  final int? durationSeconds;

  AlertModel({
    required this.timestamp,
    required this.message,
    this.decibel,
    this.durationSeconds,
  });

  Duration? get duration => durationSeconds == null ? null : Duration(seconds: durationSeconds!);

  AlertModel copyWith({int? durationSeconds}) => AlertModel(
        timestamp: timestamp,
        message: message,
        decibel: decibel,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'decibel': decibel,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
      decibel: json['decibel'] != null ? (json['decibel'] as num).toDouble() : null,
      durationSeconds: (json['durationSeconds'] as num?)?.round(),
    );
  }
}
