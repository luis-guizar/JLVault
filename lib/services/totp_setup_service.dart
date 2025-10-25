import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/totp_config.dart';
import 'totp_generator.dart';

/// Service for setting up TOTP configurations
class TOTPSetupService {
  /// Parse TOTP configuration from a QR code or manual entry
  static TOTPConfig? parseTOTPUri(String uri) {
    return TOTPConfig.fromUri(uri);
  }

  /// Validate a manually entered TOTP secret
  static bool validateSecret(String secret) {
    if (secret.isEmpty) return false;

    // Remove spaces and convert to uppercase
    final cleanSecret = secret.replaceAll(' ', '').toUpperCase();

    // Check if it's valid base32
    return TOTPGenerator.isValidSecret(cleanSecret);
  }

  /// Clean and format a TOTP secret for storage
  static String cleanSecret(String secret) {
    return secret.replaceAll(' ', '').toUpperCase();
  }

  /// Generate a test TOTP code to verify the configuration
  static String generateTestCode(TOTPConfig config) {
    return TOTPGenerator.generateCode(config);
  }

  /// Validate a TOTP configuration by generating a test code
  static bool validateConfiguration(TOTPConfig config) {
    try {
      final testCode = generateTestCode(config);
      return testCode.isNotEmpty && testCode != '000000';
    } catch (e) {
      return false;
    }
  }

  /// Check if camera permission is granted
  static Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Create a TOTP configuration from manual entry
  static TOTPConfig createManualConfig({
    required String secret,
    required String issuer,
    required String accountName,
    int digits = 6,
    int period = 30,
    TOTPAlgorithm algorithm = TOTPAlgorithm.sha1,
  }) {
    return TOTPConfig(
      secret: cleanSecret(secret),
      issuer: issuer,
      accountName: accountName,
      digits: digits,
      period: period,
      algorithm: algorithm,
    );
  }

  /// Validate that all required fields are provided for manual setup
  static String? validateManualSetup({
    required String secret,
    required String issuer,
    required String accountName,
  }) {
    if (secret.trim().isEmpty) {
      return 'Secret key is required';
    }

    if (!validateSecret(secret)) {
      return 'Invalid secret key format';
    }

    if (issuer.trim().isEmpty) {
      return 'Issuer name is required';
    }

    if (accountName.trim().isEmpty) {
      return 'Account name is required';
    }

    return null; // No validation errors
  }

  /// Extract common issuers from TOTP URIs for suggestions
  static List<String> getCommonIssuers() {
    return [
      'Google',
      'Microsoft',
      'GitHub',
      'Facebook',
      'Twitter',
      'Amazon',
      'Apple',
      'Discord',
      'Dropbox',
      'LinkedIn',
      'Netflix',
      'PayPal',
      'Reddit',
      'Slack',
      'Steam',
      'Twitch',
      'WhatsApp',
      'Yahoo',
    ];
  }

  /// Get algorithm options for manual setup
  static List<TOTPAlgorithm> getSupportedAlgorithms() {
    return TOTPAlgorithm.values;
  }

  /// Get digit options for manual setup
  static List<int> getSupportedDigits() {
    return [6, 7, 8];
  }

  /// Get period options for manual setup
  static List<int> getSupportedPeriods() {
    return [15, 30, 60];
  }

  /// Copy text to clipboard
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Get text from clipboard
  static Future<String?> getFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  /// Check if clipboard contains a potential TOTP URI
  static Future<bool> clipboardContainsTOTPUri() async {
    final clipboardText = await getFromClipboard();
    if (clipboardText == null) return false;

    return clipboardText.toLowerCase().startsWith('otpauth://totp/');
  }

  /// Try to parse TOTP configuration from clipboard
  static Future<TOTPConfig?> parseFromClipboard() async {
    final clipboardText = await getFromClipboard();
    if (clipboardText == null) return null;

    return parseTOTPUri(clipboardText);
  }
}

/// Exception thrown during TOTP setup
class TOTPSetupException implements Exception {
  final String message;

  const TOTPSetupException(this.message);

  @override
  String toString() => 'TOTPSetupException: $message';
}
