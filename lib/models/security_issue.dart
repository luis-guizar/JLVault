enum SecurityIssueType {
  weakPassword,
  reusedPassword,
  breachedPassword,
  oldPassword,
  noTwoFactor,
}

enum SecurityIssuePriority { low, medium, high, critical }

class SecurityIssue {
  final String id;
  final SecurityIssueType type;
  final SecurityIssuePriority priority;
  final String title;
  final String description;
  final String recommendation;
  final List<int> affectedAccountIds;
  final DateTime detectedAt;

  SecurityIssue({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.recommendation,
    required this.affectedAccountIds,
    required this.detectedAt,
  });

  SecurityIssue copyWith({
    String? id,
    SecurityIssueType? type,
    SecurityIssuePriority? priority,
    String? title,
    String? description,
    String? recommendation,
    List<int>? affectedAccountIds,
    DateTime? detectedAt,
  }) {
    return SecurityIssue(
      id: id ?? this.id,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      recommendation: recommendation ?? this.recommendation,
      affectedAccountIds: affectedAccountIds ?? this.affectedAccountIds,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'priority': priority.index,
      'title': title,
      'description': description,
      'recommendation': recommendation,
      'affectedAccountIds': affectedAccountIds,
      'detectedAt': detectedAt.millisecondsSinceEpoch,
    };
  }

  factory SecurityIssue.fromJson(Map<String, dynamic> json) {
    return SecurityIssue(
      id: json['id'],
      type: SecurityIssueType.values[json['type']],
      priority: SecurityIssuePriority.values[json['priority']],
      title: json['title'],
      description: json['description'],
      recommendation: json['recommendation'],
      affectedAccountIds: List<int>.from(json['affectedAccountIds']),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(json['detectedAt']),
    );
  }
}
