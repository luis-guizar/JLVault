import 'dart:math';

class PasswordGeneratorService {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _symbols = '!@#\$%^&*()-_=+[]{};:,.<>?';
  static const String _ambiguous = 'il1Lo0O';

  /// Generate a password with the specified parameters
  static String generatePassword(PasswordGenerationOptions options) {
    String charset = '';

    // Build character set based on options
    if (options.includeLowercase) charset += _lowercase;
    if (options.includeUppercase) charset += _uppercase;
    if (options.includeNumbers) charset += _numbers;
    if (options.includeSymbols) charset += _symbols;

    // Remove ambiguous characters if requested
    if (options.excludeAmbiguous) {
      for (String char in _ambiguous.split('')) {
        charset = charset.replaceAll(char, '');
      }
    }

    if (charset.isEmpty) {
      throw ArgumentError('At least one character type must be selected');
    }

    final random = Random.secure();
    final password = StringBuffer();

    // Ensure at least one character from each selected type
    if (options.includeLowercase) {
      password.write(
        _getRandomChar(_lowercase, random, options.excludeAmbiguous),
      );
    }
    if (options.includeUppercase) {
      password.write(
        _getRandomChar(_uppercase, random, options.excludeAmbiguous),
      );
    }
    if (options.includeNumbers) {
      password.write(
        _getRandomChar(_numbers, random, options.excludeAmbiguous),
      );
    }
    if (options.includeSymbols) {
      password.write(
        _getRandomChar(_symbols, random, options.excludeAmbiguous),
      );
    }

    // Fill remaining length with random characters
    while (password.length < options.length) {
      password.write(charset[random.nextInt(charset.length)]);
    }

    // Shuffle the password to avoid predictable patterns
    final passwordList = password.toString().split('');
    passwordList.shuffle(random);

    return passwordList.take(options.length).join();
  }

  static String _getRandomChar(
    String charset,
    Random random,
    bool excludeAmbiguous,
  ) {
    String availableChars = charset;
    if (excludeAmbiguous) {
      for (String char in _ambiguous.split('')) {
        availableChars = availableChars.replaceAll(char, '');
      }
    }
    return availableChars[random.nextInt(availableChars.length)];
  }

  /// Calculate password strength score (0-100)
  static PasswordStrength calculateStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength(
        score: 0,
        level: StrengthLevel.veryWeak,
        feedback: 'Password is empty',
      );
    }

    int score = 0;
    List<String> feedback = [];

    // Length scoring
    if (password.length >= 12) {
      score += 25;
    } else if (password.length >= 8) {
      score += 15;
      feedback.add('Consider using at least 12 characters');
    } else {
      score += 5;
      feedback.add('Password is too short (minimum 8 characters)');
    }

    // Character variety scoring
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasNumbers = password.contains(RegExp(r'[0-9]'));
    bool hasSymbols = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    int varietyCount = 0;
    if (hasLower) varietyCount++;
    if (hasUpper) varietyCount++;
    if (hasNumbers) varietyCount++;
    if (hasSymbols) varietyCount++;

    score += varietyCount * 15;

    if (varietyCount < 3) {
      feedback.add('Use a mix of uppercase, lowercase, numbers, and symbols');
    }

    // Pattern detection (basic)
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
      score -= 10;
      feedback.add('Avoid repeating characters');
    }

    if (RegExp(
      r'(012|123|234|345|456|567|678|789|890|abc|bcd|cde|def)',
    ).hasMatch(password.toLowerCase())) {
      score -= 15;
      feedback.add('Avoid sequential characters');
    }

    // Common patterns
    if (RegExp(
      r'(password|123456|qwerty|admin)',
      caseSensitive: false,
    ).hasMatch(password)) {
      score -= 25;
      feedback.add('Avoid common passwords');
    }

    // Ensure score is within bounds
    score = score.clamp(0, 100);

    // Determine strength level
    StrengthLevel level;
    if (score >= 80) {
      level = StrengthLevel.veryStrong;
    } else if (score >= 60) {
      level = StrengthLevel.strong;
    } else if (score >= 40) {
      level = StrengthLevel.medium;
    } else if (score >= 20) {
      level = StrengthLevel.weak;
    } else {
      level = StrengthLevel.veryWeak;
    }

    return PasswordStrength(
      score: score,
      level: level,
      feedback: feedback.isEmpty ? 'Strong password!' : feedback.join('. '),
    );
  }

  /// Generate multiple passwords with the same options
  static List<String> generateMultiplePasswords(
    PasswordGenerationOptions options,
    int count,
  ) {
    return List.generate(count, (_) => generatePassword(options));
  }
}

class PasswordGenerationOptions {
  final int length;
  final bool includeLowercase;
  final bool includeUppercase;
  final bool includeNumbers;
  final bool includeSymbols;
  final bool excludeAmbiguous;

  const PasswordGenerationOptions({
    this.length = 16,
    this.includeLowercase = true,
    this.includeUppercase = true,
    this.includeNumbers = true,
    this.includeSymbols = true,
    this.excludeAmbiguous = false,
  });

  PasswordGenerationOptions copyWith({
    int? length,
    bool? includeLowercase,
    bool? includeUppercase,
    bool? includeNumbers,
    bool? includeSymbols,
    bool? excludeAmbiguous,
  }) {
    return PasswordGenerationOptions(
      length: length ?? this.length,
      includeLowercase: includeLowercase ?? this.includeLowercase,
      includeUppercase: includeUppercase ?? this.includeUppercase,
      includeNumbers: includeNumbers ?? this.includeNumbers,
      includeSymbols: includeSymbols ?? this.includeSymbols,
      excludeAmbiguous: excludeAmbiguous ?? this.excludeAmbiguous,
    );
  }
}

class PasswordStrength {
  final int score;
  final StrengthLevel level;
  final String feedback;

  const PasswordStrength({
    required this.score,
    required this.level,
    required this.feedback,
  });
}

enum StrengthLevel { veryWeak, weak, medium, strong, veryStrong }
