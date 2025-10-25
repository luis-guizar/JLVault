import 'dart:math';
import '../models/account.dart';
import '../models/security_metrics.dart';

class PasswordSecurityAnalyzer {
  static const int _minSecureLength = 12;
  static const int _recommendedLength = 16;
  static const int _maxPasswordAge = 365; // days
  static const int _recommendedPasswordAge = 90; // days

  /// Analyzes password strength and returns a score from 0-100
  static int analyzePasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // Length scoring (40 points max)
    if (password.length >= _recommendedLength) {
      score += 40;
    } else if (password.length >= _minSecureLength) {
      score += 30;
    } else if (password.length >= 8) {
      score += 20;
    } else if (password.length >= 6) {
      score += 10;
    }

    // Character variety scoring (30 points max)
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    int varietyCount = 0;
    if (hasLower) varietyCount++;
    if (hasUpper) varietyCount++;
    if (hasDigits) varietyCount++;
    if (hasSpecial) varietyCount++;

    score += varietyCount * 7; // 7 points per character type

    // Entropy scoring (20 points max)
    double entropy = _calculateEntropy(password);
    if (entropy >= 60) {
      score += 20;
    } else if (entropy >= 40) {
      score += 15;
    } else if (entropy >= 25) {
      score += 10;
    } else if (entropy >= 15) {
      score += 5;
    }

    // Pattern penalties (up to -20 points)
    score -= _calculatePatternPenalties(password);

    // Bonus for very long passwords (10 points max)
    if (password.length >= 20) {
      score += 10;
    } else if (password.length >= 18) {
      score += 5;
    }

    return score.clamp(0, 100);
  }

  /// Calculates password entropy
  static double _calculateEntropy(String password) {
    if (password.isEmpty) return 0;

    Map<String, int> charFrequency = {};
    for (int i = 0; i < password.length; i++) {
      String char = password[i];
      charFrequency[char] = (charFrequency[char] ?? 0) + 1;
    }

    double entropy = 0;
    int length = password.length;

    for (int frequency in charFrequency.values) {
      double probability = frequency / length;
      entropy -= probability * (log(probability) / ln2);
    }

    return entropy * length;
  }

  /// Calculates penalties for common patterns
  static int _calculatePatternPenalties(String password) {
    int penalties = 0;

    // Sequential characters penalty
    if (_hasSequentialChars(password)) {
      penalties += 10;
    }

    // Repeated characters penalty
    if (_hasRepeatedChars(password)) {
      penalties += 5;
    }

    // Common patterns penalty
    if (_hasCommonPatterns(password)) {
      penalties += 10;
    }

    // Dictionary words penalty (simplified)
    if (_hasCommonWords(password)) {
      penalties += 15;
    }

    return penalties;
  }

  /// Checks for sequential characters (abc, 123, etc.)
  static bool _hasSequentialChars(String password) {
    for (int i = 0; i < password.length - 2; i++) {
      int char1 = password.codeUnitAt(i);
      int char2 = password.codeUnitAt(i + 1);
      int char3 = password.codeUnitAt(i + 2);

      if (char2 == char1 + 1 && char3 == char2 + 1) {
        return true;
      }
    }
    return false;
  }

  /// Checks for repeated characters (aaa, 111, etc.)
  static bool _hasRepeatedChars(String password) {
    for (int i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] &&
          password[i + 1] == password[i + 2]) {
        return true;
      }
    }
    return false;
  }

  /// Checks for common patterns
  static bool _hasCommonPatterns(String password) {
    List<String> commonPatterns = [
      'password',
      '123456',
      'qwerty',
      'abc123',
      'admin',
      'letmein',
      'welcome',
      'monkey',
      'dragon',
      'master',
    ];

    String lowerPassword = password.toLowerCase();
    for (String pattern in commonPatterns) {
      if (lowerPassword.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  /// Checks for common dictionary words (simplified)
  static bool _hasCommonWords(String password) {
    List<String> commonWords = [
      'love',
      'god',
      'sex',
      'money',
      'secret',
      'summer',
      'internet',
      'service',
      'computer',
      'football',
      'baseball',
      'welcome',
      'login',
      'admin',
      'user',
      'guest',
      'test',
      'temp',
    ];

    String lowerPassword = password.toLowerCase();
    for (String word in commonWords) {
      if (lowerPassword.contains(word)) {
        return true;
      }
    }
    return false;
  }

  /// Detects password reuse across accounts
  static Map<String, List<Account>> detectPasswordReuse(
    List<Account> accounts,
  ) {
    Map<String, List<Account>> passwordGroups = {};

    for (Account account in accounts) {
      String password = account.password;
      if (passwordGroups.containsKey(password)) {
        passwordGroups[password]!.add(account);
      } else {
        passwordGroups[password] = [account];
      }
    }

    // Return only groups with more than one account (reused passwords)
    return Map.fromEntries(
      passwordGroups.entries.where((entry) => entry.value.length > 1),
    );
  }

  /// Analyzes password age and returns recommendations
  static SecurityRisk analyzePasswordAge(DateTime? createdAt) {
    if (createdAt == null) return SecurityRisk.medium;

    int daysSinceCreated = DateTime.now().difference(createdAt).inDays;

    if (daysSinceCreated > _maxPasswordAge) {
      return SecurityRisk.high;
    } else if (daysSinceCreated > _recommendedPasswordAge) {
      return SecurityRisk.medium;
    } else {
      return SecurityRisk.low;
    }
  }

  /// Generates security metrics for an account
  static SecurityMetrics generateSecurityMetrics(
    Account account,
    List<Account> allAccounts, {
    bool isBreached = false,
    DateTime? lastBreachCheck,
  }) {
    int strengthScore = analyzePasswordStrength(account.password);

    // Check for password reuse
    bool isReused = allAccounts
        .where(
          (acc) => acc.id != account.id && acc.password == account.password,
        )
        .isNotEmpty;

    int daysSinceCreated = account.createdAt != null
        ? DateTime.now().difference(account.createdAt!).inDays
        : 0;

    SecurityRisk ageRisk = analyzePasswordAge(account.createdAt);

    // Determine overall risk level
    SecurityRisk riskLevel = SecurityRisk.low;
    if (isBreached) {
      riskLevel = SecurityRisk.critical;
    } else if (strengthScore < 30 || isReused) {
      riskLevel = SecurityRisk.high;
    } else if (strengthScore < 60 || ageRisk == SecurityRisk.high) {
      riskLevel = SecurityRisk.medium;
    } else if (ageRisk == SecurityRisk.medium) {
      riskLevel = SecurityRisk.low;
    }

    return SecurityMetrics(
      strengthScore: strengthScore,
      isReused: isReused,
      isBreached: isBreached,
      lastBreachCheck: lastBreachCheck,
      daysSinceCreated: daysSinceCreated,
      riskLevel: riskLevel,
    );
  }

  /// Gets password strength description
  static String getStrengthDescription(int score) {
    if (score >= 80) return 'Very Strong';
    if (score >= 60) return 'Strong';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Weak';
    return 'Very Weak';
  }

  /// Gets password age recommendation
  static String getAgeRecommendation(int daysSinceCreated) {
    if (daysSinceCreated > _maxPasswordAge) {
      return 'Password is over a year old. Consider changing it immediately.';
    } else if (daysSinceCreated > _recommendedPasswordAge) {
      return 'Password is getting old. Consider changing it soon.';
    } else {
      return 'Password age is acceptable.';
    }
  }
}
