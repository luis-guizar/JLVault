import '../models/account.dart';
import '../models/security_metrics.dart';
import '../models/security_report.dart';
import '../models/security_issue.dart';
import 'password_security_analyzer.dart';
import 'breach_checking_service.dart';

class SecurityScoringService {
  // Scoring weights (must sum to 100)
  static const double _passwordStrengthWeight = 40.0;
  static const double _passwordReuseWeight = 25.0;
  static const double _breachWeight = 20.0;
  static const double _passwordAgeWeight = 10.0;
  static const double _twoFactorWeight = 5.0;

  /// Calculates overall security score for a vault (0-100)
  static Future<double> calculateVaultSecurityScore(
    List<Account> accounts,
    Map<String, BreachCheckResult>? breachResults,
  ) async {
    // Handle empty password database - return 0% instead of 100%
    if (accounts.isEmpty) return 0.0;

    double totalScore = 0.0;
    int accountCount = accounts.length;

    for (final account in accounts) {
      final accountScore = await calculateAccountSecurityScore(
        account,
        accounts,
        breachResults?[account.password],
      );
      totalScore += accountScore;
    }

    return totalScore / accountCount;
  }

  /// Calculates security score for individual account
  static Future<double> calculateAccountSecurityScore(
    Account account,
    List<Account> allAccounts,
    BreachCheckResult? breachResult,
  ) async {
    double score = 0.0;

    // Password strength component (40%)
    final strengthScore = PasswordSecurityAnalyzer.analyzePasswordStrength(
      account.password,
    );
    score += (strengthScore / 100.0) * _passwordStrengthWeight;

    // Password reuse component (25%)
    final isReused = allAccounts
        .where(
          (acc) => acc.id != account.id && acc.password == account.password,
        )
        .isNotEmpty;
    if (!isReused) {
      score += _passwordReuseWeight;
    }

    // Breach component (20%)
    if (breachResult != null && !breachResult.isBreached) {
      score += _breachWeight;
    } else if (breachResult == null) {
      // If we couldn't check, give partial credit
      score += _breachWeight * 0.5;
    }

    // Password age component (10%)
    final ageRisk = PasswordSecurityAnalyzer.analyzePasswordAge(
      account.createdAt,
    );
    switch (ageRisk) {
      case SecurityRisk.low:
        score += _passwordAgeWeight;
        break;
      case SecurityRisk.medium:
        score += _passwordAgeWeight * 0.6;
        break;
      case SecurityRisk.high:
        score += _passwordAgeWeight * 0.2;
        break;
      case SecurityRisk.critical:
        // No points for critical age
        break;
    }

    // Two-factor authentication component (5%)
    if (account.totpConfig != null) {
      score += _twoFactorWeight;
    }

    return score.clamp(0.0, 100.0);
  }

  /// Calculates category-specific scores
  static Future<Map<SecurityCategory, int>> calculateCategoryScores(
    List<Account> accounts,
    Map<String, BreachCheckResult>? breachResults,
  ) async {
    // Handle empty password database - return 0% for all categories
    if (accounts.isEmpty) {
      return {
        SecurityCategory.passwordStrength: 0,
        SecurityCategory.passwordReuse: 0,
        SecurityCategory.breaches: 0,
        SecurityCategory.passwordAge: 0,
        SecurityCategory.twoFactor: 0,
      };
    }

    int totalStrengthScore = 0;
    int reuseViolations = 0;
    int breachedPasswords = 0;
    int oldPasswords = 0;
    int accountsWithTwoFactor = 0;

    // Analyze password reuse
    final passwordGroups = PasswordSecurityAnalyzer.detectPasswordReuse(
      accounts,
    );
    final reusedAccountIds = <int>{};
    for (final group in passwordGroups.values) {
      reusedAccountIds.addAll(group.map((acc) => acc.id!));
    }
    reuseViolations = reusedAccountIds.length;

    for (final account in accounts) {
      // Password strength
      final strengthScore = PasswordSecurityAnalyzer.analyzePasswordStrength(
        account.password,
      );
      totalStrengthScore += strengthScore;

      // Breach status
      final breachResult = breachResults?[account.password];
      if (breachResult?.isBreached == true) {
        breachedPasswords++;
      }

      // Password age
      final ageRisk = PasswordSecurityAnalyzer.analyzePasswordAge(
        account.createdAt,
      );
      if (ageRisk == SecurityRisk.high || ageRisk == SecurityRisk.critical) {
        oldPasswords++;
      }

      // Two-factor authentication
      if (account.totpConfig != null) {
        accountsWithTwoFactor++;
      }
    }

    return {
      SecurityCategory.passwordStrength: (totalStrengthScore / accounts.length)
          .round(),
      SecurityCategory.passwordReuse:
          ((accounts.length - reuseViolations) / accounts.length * 100).round(),
      SecurityCategory.breaches:
          ((accounts.length - breachedPasswords) / accounts.length * 100)
              .round(),
      SecurityCategory.passwordAge:
          ((accounts.length - oldPasswords) / accounts.length * 100).round(),
      SecurityCategory.twoFactor:
          (accountsWithTwoFactor / accounts.length * 100).round(),
    };
  }

  /// Generates security issues for a vault
  static Future<List<SecurityIssue>> generateSecurityIssues(
    String vaultId,
    List<Account> accounts,
    Map<String, BreachCheckResult>? breachResults,
  ) async {
    final issues = <SecurityIssue>[];

    // Weak password issues
    final weakPasswords = accounts.where((account) {
      final strength = PasswordSecurityAnalyzer.analyzePasswordStrength(
        account.password,
      );
      return strength < 60;
    }).toList();

    if (weakPasswords.isNotEmpty) {
      issues.add(
        SecurityIssue(
          id: 'weak_passwords_$vaultId',
          type: SecurityIssueType.weakPassword,
          priority: SecurityIssuePriority.high,
          title: 'Weak Passwords Detected',
          description:
              '${weakPasswords.length} passwords are weak and easily guessable.',
          recommendation:
              'Use the password generator to create strong, unique passwords.',
          affectedAccountIds: weakPasswords.map((acc) => acc.id!).toList(),
          detectedAt: DateTime.now(),
        ),
      );
    }

    // Password reuse issues
    final passwordGroups = PasswordSecurityAnalyzer.detectPasswordReuse(
      accounts,
    );
    if (passwordGroups.isNotEmpty) {
      final reusedAccountIds = <int>[];
      for (final group in passwordGroups.values) {
        reusedAccountIds.addAll(group.map((acc) => acc.id!));
      }

      issues.add(
        SecurityIssue(
          id: 'reused_passwords_$vaultId',
          type: SecurityIssueType.reusedPassword,
          priority: SecurityIssuePriority.high,
          title: 'Password Reuse Detected',
          description:
              '${reusedAccountIds.length} accounts are using duplicate passwords.',
          recommendation:
              'Change reused passwords to unique ones for each account.',
          affectedAccountIds: reusedAccountIds,
          detectedAt: DateTime.now(),
        ),
      );
    }

    // Breached password issues
    if (breachResults != null) {
      final breachedAccounts = accounts.where((account) {
        final breachResult = breachResults[account.password];
        return breachResult?.isBreached == true;
      }).toList();

      if (breachedAccounts.isNotEmpty) {
        issues.add(
          SecurityIssue(
            id: 'breached_passwords_$vaultId',
            type: SecurityIssueType.breachedPassword,
            priority: SecurityIssuePriority.critical,
            title: 'Breached Passwords Found',
            description:
                '${breachedAccounts.length} passwords have been found in data breaches.',
            recommendation:
                'Change these passwords immediately to secure alternatives.',
            affectedAccountIds: breachedAccounts.map((acc) => acc.id!).toList(),
            detectedAt: DateTime.now(),
          ),
        );
      }
    }

    // Old password issues
    final oldPasswords = accounts.where((account) {
      final ageRisk = PasswordSecurityAnalyzer.analyzePasswordAge(
        account.createdAt,
      );
      return ageRisk == SecurityRisk.high || ageRisk == SecurityRisk.critical;
    }).toList();

    if (oldPasswords.isNotEmpty) {
      issues.add(
        SecurityIssue(
          id: 'old_passwords_$vaultId',
          type: SecurityIssueType.oldPassword,
          priority: SecurityIssuePriority.medium,
          title: 'Old Passwords Detected',
          description:
              '${oldPasswords.length} passwords are over 3 months old.',
          recommendation:
              'Consider updating old passwords for better security.',
          affectedAccountIds: oldPasswords.map((acc) => acc.id!).toList(),
          detectedAt: DateTime.now(),
        ),
      );
    }

    // Missing two-factor authentication
    final accountsWithoutTwoFactor = accounts
        .where((account) => account.totpConfig == null)
        .toList();
    if (accountsWithoutTwoFactor.length > accounts.length * 0.5) {
      issues.add(
        SecurityIssue(
          id: 'missing_2fa_$vaultId',
          type: SecurityIssueType.noTwoFactor,
          priority: SecurityIssuePriority.low,
          title: 'Limited Two-Factor Authentication',
          description:
              'Most accounts don\'t have two-factor authentication enabled.',
          recommendation:
              'Enable 2FA on important accounts for additional security.',
          affectedAccountIds: accountsWithoutTwoFactor
              .map((acc) => acc.id!)
              .toList(),
          detectedAt: DateTime.now(),
        ),
      );
    }

    return issues;
  }

  /// Generates security recommendations
  static List<SecurityRecommendation> generateRecommendations(
    List<SecurityIssue> issues,
  ) {
    final recommendations = <SecurityRecommendation>[];

    for (final issue in issues) {
      switch (issue.type) {
        case SecurityIssueType.weakPassword:
          recommendations.add(
            SecurityRecommendation(
              id: 'strengthen_passwords',
              title: 'Strengthen Weak Passwords',
              description:
                  'Use the built-in password generator to create strong passwords.',
              priority: issue.priority,
              actionText: 'Generate Strong Passwords',
              affectedAccountIds: issue.affectedAccountIds,
            ),
          );
          break;

        case SecurityIssueType.reusedPassword:
          recommendations.add(
            SecurityRecommendation(
              id: 'fix_reuse',
              title: 'Fix Password Reuse',
              description:
                  'Create unique passwords for each account to prevent credential stuffing attacks.',
              priority: issue.priority,
              actionText: 'Update Duplicate Passwords',
              affectedAccountIds: issue.affectedAccountIds,
            ),
          );
          break;

        case SecurityIssueType.breachedPassword:
          recommendations.add(
            SecurityRecommendation(
              id: 'change_breached',
              title: 'Change Breached Passwords',
              description:
                  'These passwords have been exposed in data breaches and should be changed immediately.',
              priority: issue.priority,
              actionText: 'Change Passwords Now',
              affectedAccountIds: issue.affectedAccountIds,
            ),
          );
          break;

        case SecurityIssueType.oldPassword:
          recommendations.add(
            SecurityRecommendation(
              id: 'rotate_old',
              title: 'Rotate Old Passwords',
              description:
                  'Regular password rotation helps maintain security over time.',
              priority: issue.priority,
              actionText: 'Update Old Passwords',
              affectedAccountIds: issue.affectedAccountIds,
            ),
          );
          break;

        case SecurityIssueType.noTwoFactor:
          recommendations.add(
            SecurityRecommendation(
              id: 'enable_2fa',
              title: 'Enable Two-Factor Authentication',
              description:
                  'Add an extra layer of security with TOTP authentication.',
              priority: issue.priority,
              actionText: 'Set Up 2FA',
              affectedAccountIds: issue.affectedAccountIds,
            ),
          );
          break;
      }
    }

    return recommendations;
  }

  /// Gets security score color for UI display
  static String getScoreColor(double score) {
    if (score >= 80) return 'green';
    if (score >= 60) return 'orange';
    if (score >= 40) return 'red';
    return 'darkred';
  }

  /// Gets security score description
  static String getScoreDescription(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Good';
    if (score >= 60) return 'Fair';
    if (score >= 40) return 'Poor';
    return 'Critical';
  }

  /// Gets improvement suggestions based on score
  static List<String> getImprovementSuggestions(
    double score,
    Map<SecurityCategory, int> categoryScores,
  ) {
    final suggestions = <String>[];

    if (categoryScores[SecurityCategory.passwordStrength]! < 70) {
      suggestions.add('Strengthen weak passwords using the password generator');
    }

    if (categoryScores[SecurityCategory.passwordReuse]! < 90) {
      suggestions.add('Replace duplicate passwords with unique ones');
    }

    if (categoryScores[SecurityCategory.breaches]! < 100) {
      suggestions.add('Change passwords that have been found in data breaches');
    }

    if (categoryScores[SecurityCategory.passwordAge]! < 80) {
      suggestions.add('Update passwords that are over 3 months old');
    }

    if (categoryScores[SecurityCategory.twoFactor]! < 50) {
      suggestions.add('Enable two-factor authentication on important accounts');
    }

    if (suggestions.isEmpty) {
      suggestions.add(
        'Your vault security is excellent! Keep up the good work.',
      );
    }

    return suggestions;
  }
}
