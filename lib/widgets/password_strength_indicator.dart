import 'package:flutter/material.dart';
import '../services/password_generator_service.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showDetails;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final strength = PasswordGeneratorService.calculateStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: strength.score / 100,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade700
                    : Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getStrengthColor(strength.level),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _getStrengthText(strength.level),
              style: TextStyle(
                color: _getStrengthColor(strength.level),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (showDetails && password.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _getStrengthIcon(strength.level),
                size: 16,
                color: _getStrengthColor(strength.level),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  strength.feedback,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade300
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getStrengthColor(StrengthLevel level) {
    switch (level) {
      case StrengthLevel.veryWeak:
        return Colors.red.shade700;
      case StrengthLevel.weak:
        return Colors.orange.shade700;
      case StrengthLevel.medium:
        return Colors.yellow.shade700;
      case StrengthLevel.strong:
        return Colors.lightGreen.shade700;
      case StrengthLevel.veryStrong:
        return Colors.green.shade700;
    }
  }

  String _getStrengthText(StrengthLevel level) {
    switch (level) {
      case StrengthLevel.veryWeak:
        return 'Muy débil';
      case StrengthLevel.weak:
        return 'Débil';
      case StrengthLevel.medium:
        return 'Medio';
      case StrengthLevel.strong:
        return 'Fuerte';
      case StrengthLevel.veryStrong:
        return 'Muy Fuerte';
    }
  }

  IconData _getStrengthIcon(StrengthLevel level) {
    switch (level) {
      case StrengthLevel.veryWeak:
      case StrengthLevel.weak:
        return Icons.warning;
      case StrengthLevel.medium:
        return Icons.info;
      case StrengthLevel.strong:
      case StrengthLevel.veryStrong:
        return Icons.check_circle;
    }
  }
}
