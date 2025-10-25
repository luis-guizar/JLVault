import 'package:flutter/material.dart';
import '../models/security_report.dart';
import '../models/security_issue.dart';

class SecurityRecommendationsList extends StatelessWidget {
  final List<SecurityRecommendation> recommendations;
  final Function(SecurityRecommendation) onRecommendationSelected;

  const SecurityRecommendationsList({
    super.key,
    required this.recommendations,
    required this.onRecommendationSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No Recommendations!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your security is excellent.\nKeep up the good work!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group recommendations by priority
    final groupedRecommendations = _groupRecommendationsByPriority(
      recommendations,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        const SizedBox(height: 16),
        ...groupedRecommendations.entries.map(
          (entry) => _buildPrioritySection(entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalAffectedAccounts = recommendations
        .expand((rec) => rec.affectedAccountIds)
        .toSet()
        .length;

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Security Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'We found ${recommendations.length} recommendations to improve your vault security.',
              style: const TextStyle(color: Colors.grey),
            ),
            if (totalAffectedAccounts > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$totalAffectedAccounts accounts could benefit from these improvements.',
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<SecurityIssuePriority, List<SecurityRecommendation>>
  _groupRecommendationsByPriority(
    List<SecurityRecommendation> recommendations,
  ) {
    final grouped = <SecurityIssuePriority, List<SecurityRecommendation>>{};

    for (final recommendation in recommendations) {
      grouped
          .putIfAbsent(recommendation.priority, () => [])
          .add(recommendation);
    }

    // Sort by priority (critical first)
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.key.index.compareTo(a.key.index));

    return Map.fromEntries(sortedEntries);
  }

  Widget _buildPrioritySection(
    SecurityIssuePriority priority,
    List<SecurityRecommendation> recommendations,
  ) {
    final priorityInfo = _getPriorityInfo(priority);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                priorityInfo['icon'] as IconData,
                color: priorityInfo['color'] as Color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${priorityInfo['label']} Priority (${recommendations.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: priorityInfo['color'] as Color,
                ),
              ),
            ],
          ),
        ),
        ...recommendations.map(
          (recommendation) => _buildRecommendationCard(recommendation),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRecommendationCard(SecurityRecommendation recommendation) {
    final priorityInfo = _getPriorityInfo(recommendation.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onRecommendationSelected(recommendation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: priorityInfo['color'] as Color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendation.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (priorityInfo['color'] as Color).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      priorityInfo['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: priorityInfo['color'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                recommendation.description,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.account_circle, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${recommendation.affectedAccountIds.length} accounts',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => onRecommendationSelected(recommendation),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(recommendation.actionText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: priorityInfo['color'] as Color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getPriorityInfo(SecurityIssuePriority priority) {
    switch (priority) {
      case SecurityIssuePriority.critical:
        return {
          'label': 'Critical',
          'color': Colors.red[700],
          'icon': Icons.dangerous,
        };
      case SecurityIssuePriority.high:
        return {
          'label': 'High',
          'color': Colors.orange[700],
          'icon': Icons.warning,
        };
      case SecurityIssuePriority.medium:
        return {
          'label': 'Medium',
          'color': Colors.yellow[700],
          'icon': Icons.info,
        };
      case SecurityIssuePriority.low:
        return {
          'label': 'Low',
          'color': Colors.blue[700],
          'icon': Icons.info_outline,
        };
    }
  }
}
