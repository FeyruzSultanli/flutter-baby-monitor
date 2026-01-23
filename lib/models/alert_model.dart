class AlertModel {
  final DateTime timestamp;
  final String message;
  final double? decibel;

  AlertModel({
    required this.timestamp,
    required this.message,
    this.decibel,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'decibel': decibel,
    };
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
      decibel: json['decibel'] != null ? (json['decibel'] as num).toDouble() : null,
    );
  }
}
