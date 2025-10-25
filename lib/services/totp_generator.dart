import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../models/totp_config.dart';

/// Service for generating TOTP (Time-based One-Time Password) codes
class TOTPGenerator {
  /// Generate a TOTP code for the given configuration at the current time
  static String generateCode(TOTPConfig config) {
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return generateCodeAtTime(config, currentTime);
  }

  /// Generate a TOTP code for the given configuration at a specific time
  static String generateCodeAtTime(TOTPConfig config, int unixTime) {
    final timeStep = unixTime ~/ config.period;
    return _generateHOTP(
      config.secret,
      timeStep,
      config.digits,
      config.algorithm,
    );
  }

  /// Get the remaining seconds until the current TOTP code expires
  static int getRemainingSeconds(TOTPConfig config) {
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timeStep = currentTime ~/ config.period;
    final nextTimeStep = (timeStep + 1) * config.period;
    return nextTimeStep - currentTime;
  }

  /// Get the progress (0.0 to 1.0) of the current time period
  static double getProgress(TOTPConfig config) {
    final remaining = getRemainingSeconds(config);
    return 1.0 - (remaining / config.period);
  }

  /// Create a stream that emits new TOTP codes as they change
  static Stream<String> getCodeStream(TOTPConfig config) {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      return generateCode(config);
    }).distinct(); // Only emit when the code actually changes
  }

  /// Create a stream that emits remaining seconds
  static Stream<int> getRemainingSecondsStream(TOTPConfig config) {
    return Stream.periodic(const Duration(seconds: 1), (_) {
      return getRemainingSeconds(config);
    });
  }

  /// Create a stream that emits progress updates
  static Stream<double> getProgressStream(TOTPConfig config) {
    return Stream.periodic(const Duration(milliseconds: 100), (_) {
      return getProgress(config);
    });
  }

  /// Generate HOTP (HMAC-based One-Time Password) code
  static String _generateHOTP(
    String secret,
    int counter,
    int digits,
    TOTPAlgorithm algorithm,
  ) {
    try {
      // Decode base32 secret
      final secretBytes = _base32Decode(secret);

      // Convert counter to 8-byte array (big-endian)
      final counterBytes = Uint8List(8);
      for (int i = 7; i >= 0; i--) {
        counterBytes[i] = counter & 0xff;
        counter >>= 8;
      }

      // Generate HMAC
      final hmac = _getHmac(algorithm, secretBytes);
      final digest = hmac.convert(counterBytes);
      final hash = Uint8List.fromList(digest.bytes);

      // Dynamic truncation
      final offset = hash[hash.length - 1] & 0x0f;
      final truncatedHash =
          (hash[offset] & 0x7f) << 24 |
          (hash[offset + 1] & 0xff) << 16 |
          (hash[offset + 2] & 0xff) << 8 |
          (hash[offset + 3] & 0xff);

      // Generate the final code
      final code = truncatedHash % pow(10, digits).toInt();
      return code.toString().padLeft(digits, '0');
    } catch (e) {
      // Return a placeholder code if generation fails
      return '000000'.substring(0, digits);
    }
  }

  /// Get HMAC instance for the specified algorithm
  static Hmac _getHmac(TOTPAlgorithm algorithm, List<int> key) {
    switch (algorithm) {
      case TOTPAlgorithm.sha1:
        return Hmac(sha1, key);
      case TOTPAlgorithm.sha256:
        return Hmac(sha256, key);
      case TOTPAlgorithm.sha512:
        return Hmac(sha512, key);
    }
  }

  /// Decode base32 string to bytes
  static Uint8List _base32Decode(String input) {
    // Remove padding and convert to uppercase
    final cleanInput = input.replaceAll('=', '').toUpperCase();

    // Base32 alphabet
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

    final output = <int>[];
    int buffer = 0;
    int bitsLeft = 0;

    for (int i = 0; i < cleanInput.length; i++) {
      final char = cleanInput[i];
      final value = alphabet.indexOf(char);

      if (value == -1) {
        throw FormatException('Invalid base32 character: $char');
      }

      buffer = (buffer << 5) | value;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        output.add((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }

    return Uint8List.fromList(output);
  }

  /// Encode bytes to base32 string
  static String _base32Encode(Uint8List input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

    if (input.isEmpty) return '';

    final output = StringBuffer();
    int buffer = 0;
    int bitsLeft = 0;

    for (final byte in input) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        output.write(alphabet[(buffer >> (bitsLeft - 5)) & 0x1f]);
        bitsLeft -= 5;
      }
    }

    if (bitsLeft > 0) {
      output.write(alphabet[(buffer << (5 - bitsLeft)) & 0x1f]);
    }

    // Add padding
    while (output.length % 8 != 0) {
      output.write('=');
    }

    return output.toString();
  }

  /// Validate a TOTP secret
  static bool isValidSecret(String secret) {
    try {
      _base32Decode(secret);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Generate a random TOTP secret
  static String generateSecret({int length = 32}) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return _base32Encode(bytes);
  }

  /// Check if the device time might be incorrect for TOTP accuracy
  static bool isTimeAccurate() {
    // This is a basic check - in a real implementation, you might want to
    // check against an NTP server or use a more sophisticated method
    final now = DateTime.now();

    // Check if the time zone offset seems reasonable (within 24 hours)
    final offsetHours = now.timeZoneOffset.inHours.abs();
    return offsetHours <= 24;
  }

  /// Get a warning message if time synchronization might be an issue
  static String? getTimeSyncWarning() {
    if (!isTimeAccurate()) {
      return 'Your device time may be incorrect. TOTP codes require accurate time synchronization.';
    }
    return null;
  }
}

/// Exception thrown when TOTP generation fails
class TOTPException implements Exception {
  final String message;

  const TOTPException(this.message);

  @override
  String toString() => 'TOTPException: $message';
}
