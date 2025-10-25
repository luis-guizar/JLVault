import 'package:flutter/material.dart';
import '../models/security_report.dart';

class SecurityCategoryScores extends StatelessWidget {
  final Map<SecurityCategory, int> categoryScores;

  const SecurityCategoryScores({super.key, required this.categoryScores});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Security Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...categoryScores.entries.map(
              (entry) => _buildCategoryItem(entry.key, entry.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(SecurityCategory category, int score) {
    final categoryInfo = _getCategoryInfo(category);
    final color = _getScoreColor(score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(categoryInfo['icon'] as IconData, size: 24, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      categoryInfo['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      categoryInfo['description'] as String,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getCategoryInfo(SecurityCategory category) {
    switch (category) {
      case SecurityCategory.passwordStrength:
        return {
          'title': 'Password Strength',
          'description': 'How strong your passwords are',
          'icon': Icons.password,
        };
      case SecurityCategory.passwordReuse:
        return {
          'title': 'Password Uniqueness',
          'description': 'Avoiding duplicate passwords',
          'icon': Icons.content_copy,
        };
      case SecurityCategory.breaches:
        return {
          'title': 'Breach Protection',
          'description': 'Passwords not found in breaches',
          'icon': Icons.shield,
        };
      case SecurityCategory.passwordAge:
        return {
          'title': 'Password Freshness',
          'description': 'How recently passwords were changed',
          'icon': Icons.schedule,
        };
      case SecurityCategory.twoFactor:
        return {
          'title': 'Two-Factor Auth',
          'description': 'Accounts with 2FA enabled',
          'icon': Icons.security,
        };
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.deepOrange;
    return Colors.red;
  }
}
