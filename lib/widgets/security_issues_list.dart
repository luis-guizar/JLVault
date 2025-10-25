import 'package:flutter/material.dart';
import '../models/security_issue.dart';

class SecurityIssuesList extends StatelessWidget {
  final List<SecurityIssue> issues;
  final Function(SecurityIssue) onIssueSelected;

  const SecurityIssuesList({
    super.key,
    required this.issues,
    required this.onIssueSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No Security Issues Found!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your vault is secure and well-protected.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group issues by priority
    final groupedIssues = _groupIssuesByPriority(issues);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...groupedIssues.entries.map(
          (entry) => _buildPrioritySection(entry.key, entry.value),
        ),
      ],
    );
  }

  Map<SecurityIssuePriority, List<SecurityIssue>> _groupIssuesByPriority(
    List<SecurityIssue> issues,
  ) {
    final grouped = <SecurityIssuePriority, List<SecurityIssue>>{};

    for (final issue in issues) {
      grouped.putIfAbsent(issue.priority, () => []).add(issue);
    }

    // Sort by priority (critical first)
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.key.index.compareTo(a.key.index));

    return Map.fromEntries(sortedEntries);
  }

  Widget _buildPrioritySection(
    SecurityIssuePriority priority,
    List<SecurityIssue> issues,
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
                '${priorityInfo['label']} Priority (${issues.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: priorityInfo['color'] as Color,
                ),
              ),
            ],
          ),
        ),
        ...issues.map((issue) => _buildIssueCard(issue)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildIssueCard(SecurityIssue issue) {
    final priorityInfo = _getPriorityInfo(issue.priority);
    final typeInfo = _getTypeInfo(issue.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onIssueSelected(issue),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    typeInfo['icon'] as IconData,
                    color: priorityInfo['color'] as Color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      issue.title,
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
                issue.description,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.account_circle, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${issue.affectedAccountIds.length} accounts affected',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(issue.detectedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  Map<String, dynamic> _getTypeInfo(SecurityIssueType type) {
    switch (type) {
      case SecurityIssueType.weakPassword:
        return {'icon': Icons.password, 'label': 'Weak Password'};
      case SecurityIssueType.reusedPassword:
        return {'icon': Icons.content_copy, 'label': 'Reused Password'};
      case SecurityIssueType.breachedPassword:
        return {'icon': Icons.shield_outlined, 'label': 'Breached Password'};
      case SecurityIssueType.oldPassword:
        return {'icon': Icons.schedule, 'label': 'Old Password'};
      case SecurityIssueType.noTwoFactor:
        return {'icon': Icons.security, 'label': 'No 2FA'};
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
