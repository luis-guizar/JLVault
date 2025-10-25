enum SecurityRisk { low, medium, high, critical }

class SecurityMetrics {
  final int strengthScore; // 0-100
  final bool isReused;
  final bool isBreached;
  final DateTime? lastBreachCheck;
  final int daysSinceCreated;
  final SecurityRisk riskLevel;

  SecurityMetrics({
    required this.strengthScore,
    required this.isReused,
    required this.isBreached,
    this.lastBreachCheck,
    required this.daysSinceCreated,
    required this.riskLevel,
  });

  SecurityMetrics copyWith({
    int? strengthScore,
    bool? isReused,
    bool? isBreached,
    DateTime? lastBreachCheck,
    int? daysSinceCreated,
    SecurityRisk? riskLevel,
  }) {
    return SecurityMetrics(
      strengthScore: strengthScore ?? this.strengthScore,
      isReused: isReused ?? this.isReused,
      isBreached: isBreached ?? this.isBreached,
      lastBreachCheck: lastBreachCheck ?? this.lastBreachCheck,
      daysSinceCreated: daysSinceCreated ?? this.daysSinceCreated,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strengthScore': strengthScore,
      'isReused': isReused,
      'isBreached': isBreached,
      'lastBreachCheck': lastBreachCheck?.millisecondsSinceEpoch,
      'daysSinceCreated': daysSinceCreated,
      'riskLevel': riskLevel.index,
    };
  }

  factory SecurityMetrics.fromJson(Map<String, dynamic> json) {
    return SecurityMetrics(
      strengthScore: json['strengthScore'] ?? 0,
      isReused: json['isReused'] ?? false,
      isBreached: json['isBreached'] ?? false,
      lastBreachCheck: json['lastBreachCheck'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastBreachCheck'])
          : null,
      daysSinceCreated: json['daysSinceCreated'] ?? 0,
      riskLevel: SecurityRisk.values[json['riskLevel'] ?? 0],
    );
  }
}
