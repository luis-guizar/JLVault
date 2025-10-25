import 'dart:convert';

/// Supported TOTP algorithms
enum TOTPAlgorithm {
  sha1,
  sha256,
  sha512;

  /// Get the algorithm name as used in TOTP URIs
  String get name {
    switch (this) {
      case TOTPAlgorithm.sha1:
        return 'SHA1';
      case TOTPAlgorithm.sha256:
        return 'SHA256';
      case TOTPAlgorithm.sha512:
        return 'SHA512';
    }
  }

  /// Parse algorithm from string
  static TOTPAlgorithm fromString(String algorithm) {
    switch (algorithm.toUpperCase()) {
      case 'SHA1':
        return TOTPAlgorithm.sha1;
      case 'SHA256':
        return TOTPAlgorithm.sha256;
      case 'SHA512':
        return TOTPAlgorithm.sha512;
      default:
        return TOTPAlgorithm.sha1; // Default fallback
    }
  }
}

/// Configuration for TOTP (Time-based One-Time Password) generation
class TOTPConfig {
  /// The secret key used for TOTP generation (base32 encoded)
  final String secret;

  /// The issuer name (e.g., "Google", "GitHub")
  final String issuer;

  /// The account name (e.g., user email or username)
  final String accountName;

  /// Number of digits in the generated code (usually 6)
  final int digits;

  /// Time period in seconds for code generation (usually 30)
  final int period;

  /// Hash algorithm to use for TOTP generation
  final TOTPAlgorithm algorithm;

  const TOTPConfig({
    required this.secret,
    required this.issuer,
    required this.accountName,
    this.digits = 6,
    this.period = 30,
    this.algorithm = TOTPAlgorithm.sha1,
  });

  /// Create a copy with updated values
  TOTPConfig copyWith({
    String? secret,
    String? issuer,
    String? accountName,
    int? digits,
    int? period,
    TOTPAlgorithm? algorithm,
  }) {
    return TOTPConfig(
      secret: secret ?? this.secret,
      issuer: issuer ?? this.issuer,
      accountName: accountName ?? this.accountName,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      algorithm: algorithm ?? this.algorithm,
    );
  }

  /// Convert to JSON map for storage
  Map<String, dynamic> toMap() {
    return {
      'secret': secret,
      'issuer': issuer,
      'account_name': accountName,
      'digits': digits,
      'period': period,
      'algorithm': algorithm.name,
    };
  }

  /// Create from JSON map
  factory TOTPConfig.fromMap(Map<String, dynamic> map) {
    return TOTPConfig(
      secret: map['secret'] ?? '',
      issuer: map['issuer'] ?? '',
      accountName: map['account_name'] ?? '',
      digits: map['digits'] ?? 6,
      period: map['period'] ?? 30,
      algorithm: TOTPAlgorithm.fromString(map['algorithm'] ?? 'SHA1'),
    );
  }

  /// Convert to JSON string for encrypted storage
  String toJson() => json.encode(toMap());

  /// Create from JSON string
  factory TOTPConfig.fromJson(String source) {
    return TOTPConfig.fromMap(json.decode(source));
  }

  /// Generate TOTP URI for QR code generation
  String toUri() {
    final params = <String, String>{
      'secret': secret,
      'issuer': issuer,
      'algorithm': algorithm.name,
      'digits': digits.toString(),
      'period': period.toString(),
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return 'otpauth://totp/${Uri.encodeComponent(issuer)}:${Uri.encodeComponent(accountName)}?$queryString';
  }

  /// Parse TOTP configuration from URI
  static TOTPConfig? fromUri(String uri) {
    try {
      final parsedUri = Uri.parse(uri);

      if (parsedUri.scheme != 'otpauth' || parsedUri.host != 'totp') {
        return null;
      }

      final secret = parsedUri.queryParameters['secret'];
      if (secret == null || secret.isEmpty) {
        return null;
      }

      // Extract issuer and account from path
      final pathSegments = parsedUri.path.split(':');
      String issuer = '';
      String accountName = '';

      if (pathSegments.length >= 2) {
        issuer = Uri.decodeComponent(pathSegments[0].replaceFirst('/', ''));
        accountName = Uri.decodeComponent(pathSegments[1]);
      } else if (pathSegments.length == 1) {
        accountName = Uri.decodeComponent(
          pathSegments[0].replaceFirst('/', ''),
        );
      }

      // Override issuer if provided as parameter
      if (parsedUri.queryParameters['issuer'] != null) {
        issuer = parsedUri.queryParameters['issuer']!;
      }

      return TOTPConfig(
        secret: secret,
        issuer: issuer,
        accountName: accountName,
        digits: int.tryParse(parsedUri.queryParameters['digits'] ?? '6') ?? 6,
        period: int.tryParse(parsedUri.queryParameters['period'] ?? '30') ?? 30,
        algorithm: TOTPAlgorithm.fromString(
          parsedUri.queryParameters['algorithm'] ?? 'SHA1',
        ),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TOTPConfig &&
        other.secret == secret &&
        other.issuer == issuer &&
        other.accountName == accountName &&
        other.digits == digits &&
        other.period == period &&
        other.algorithm == algorithm;
  }

  @override
  int get hashCode {
    return secret.hashCode ^
        issuer.hashCode ^
        accountName.hashCode ^
        digits.hashCode ^
        period.hashCode ^
        algorithm.hashCode;
  }

  @override
  String toString() {
    return 'TOTPConfig(issuer: $issuer, accountName: $accountName, digits: $digits, period: $period, algorithm: ${algorithm.name})';
  }
}
