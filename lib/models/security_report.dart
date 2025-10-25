import 'security_issue.dart';

enum SecurityCategory {
  passwordStrength,
  passwordReuse,
  breaches,
  passwordAge,
  twoFactor,
}

class SecurityRecommendation {
  final String id;
  final String title;
  final String description;
  final SecurityIssuePriority priority;
  final String actionText;
  final List<int> affectedAccountIds;

  SecurityRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.actionText,
    required this.affectedAccountIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority.index,
      'actionText': actionText,
      'affectedAccountIds': affectedAccountIds,
    };
  }

  factory SecurityRecommendation.fromJson(Map<String, dynamic> json) {
    return SecurityRecommendation(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      priority: SecurityIssuePriority.values[json['priority']],
      actionText: json['actionText'],
      affectedAccountIds: List<int>.from(json['affectedAccountIds']),
    );
  }
}

class SecurityReport {
  final String vaultId;
  final double overallScore;
  final List<SecurityIssue> issues;
  final Map<SecurityCategory, int> categoryScores;
  final List<SecurityRecommendation> recommendations;
  final DateTime generatedAt;
  final int totalAccounts;
  final int secureAccounts;

  SecurityReport({
    required this.vaultId,
    required this.overallScore,
    required this.issues,
    required this.categoryScores,
    required this.recommendations,
    required this.generatedAt,
    required this.totalAccounts,
    required this.secureAccounts,
  });

  SecurityReport copyWith({
    String? vaultId,
    double? overallScore,
    List<SecurityIssue>? issues,
    Map<SecurityCategory, int>? categoryScores,
    List<SecurityRecommendation>? recommendations,
    DateTime? generatedAt,
    int? totalAccounts,
    int? secureAccounts,
  }) {
    return SecurityReport(
      vaultId: vaultId ?? this.vaultId,
      overallScore: overallScore ?? this.overallScore,
      issues: issues ?? this.issues,
      categoryScores: categoryScores ?? this.categoryScores,
      recommendations: recommendations ?? this.recommendations,
      generatedAt: generatedAt ?? this.generatedAt,
      totalAccounts: totalAccounts ?? this.totalAccounts,
      secureAccounts: secureAccounts ?? this.secureAccounts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vaultId': vaultId,
      'overallScore': overallScore,
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'categoryScores': categoryScores.map(
        (key, value) => MapEntry(key.index.toString(), value),
      ),
      'recommendations': recommendations.map((rec) => rec.toJson()).toList(),
      'generatedAt': generatedAt.millisecondsSinceEpoch,
      'totalAccounts': totalAccounts,
      'secureAccounts': secureAccounts,
    };
  }

  factory SecurityReport.fromJson(Map<String, dynamic> json) {
    return SecurityReport(
      vaultId: json['vaultId'],
      overallScore: json['overallScore'].toDouble(),
      issues: (json['issues'] as List)
          .map((issue) => SecurityIssue.fromJson(issue))
          .toList(),
      categoryScores: (json['categoryScores'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(SecurityCategory.values[int.parse(key)], value),
      ),
      recommendations: (json['recommendations'] as List)
          .map((rec) => SecurityRecommendation.fromJson(rec))
          .toList(),
      generatedAt: DateTime.fromMillisecondsSinceEpoch(json['generatedAt']),
      totalAccounts: json['totalAccounts'],
      secureAccounts: json['secureAccounts'],
    );
  }
}
