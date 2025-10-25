import 'package:flutter/material.dart';
import '../services/security_scoring_service.dart';

class SecurityScoreCard extends StatelessWidget {
  final double score;
  final int totalAccounts;
  final int secureAccounts;
  final DateTime lastUpdated;

  const SecurityScoreCard({
    super.key,
    required this.score,
    required this.totalAccounts,
    required this.secureAccounts,
    required this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor(score);
    final scoreDescription = SecurityScoringService.getScoreDescription(score);

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scoreColor.withOpacity(0.1), scoreColor.withOpacity(0.05)],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Security Score',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            score.toInt().toString(),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              '/100',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        scoreDescription,
                        style: TextStyle(
                          fontSize: 16,
                          color: scoreColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _buildCircularProgress(score, scoreColor),
                    const SizedBox(height: 16),
                    _buildSecureAccountsIndicator(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLastUpdated(),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularProgress(double score, Color color) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Center(child: Icon(_getScoreIcon(score), size: 32, color: color)),
        ],
      ),
    );
  }

  Widget _buildSecureAccountsIndicator() {
    final percentage = totalAccounts > 0
        ? (secureAccounts / totalAccounts)
        : 0.0;

    return Column(
      children: [
        Text(
          '$secureAccounts/$totalAccounts',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Secure Accounts',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.grey[300],
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: percentage >= 0.8
                    ? Colors.green
                    : percentage >= 0.6
                    ? Colors.orange
                    : Colors.red,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLastUpdated() {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    String timeAgo;
    if (difference.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (difference.inHours < 1) {
      timeAgo = '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      timeAgo = '${difference.inHours}h ago';
    } else {
      timeAgo = '${difference.inDays}d ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            'Updated $timeAgo',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.red;
    return Colors.red[800]!;
  }

  IconData _getScoreIcon(double score) {
    if (score >= 90) return Icons.security;
    if (score >= 80) return Icons.verified_user;
    if (score >= 60) return Icons.warning;
    if (score >= 40) return Icons.error;
    return Icons.dangerous;
  }
}
