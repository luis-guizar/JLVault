import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Represents a pairing invitation that can be encoded in a QR code
class PairingInvitation {
  final String deviceId;
  final String deviceName;
  final String address;
  final int port;
  final String publicKey;
  final String challenge;
  final DateTime expiresAt;
  final Map<String, String> capabilities;

  PairingInvitation({
    required this.deviceId,
    required this.deviceName,
    required this.address,
    required this.port,
    required this.publicKey,
    required this.challenge,
    required this.expiresAt,
    required this.capabilities,
  });

  /// Create a pairing invitation for QR code generation
  factory PairingInvitation.create({
    required String deviceId,
    required String deviceName,
    required String address,
    required int port,
    required String publicKey,
    required Map<String, String> capabilities,
    Duration validity = const Duration(minutes: 10),
  }) {
    final challenge = _generateChallenge();
    final expiresAt = DateTime.now().add(validity);

    return PairingInvitation(
      deviceId: deviceId,
      deviceName: deviceName,
      address: address,
      port: port,
      publicKey: publicKey,
      challenge: challenge,
      expiresAt: expiresAt,
      capabilities: capabilities,
    );
  }

  /// Convert to JSON for QR code encoding
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'address': address,
      'port': port,
      'publicKey': publicKey,
      'challenge': challenge,
      'expiresAt': expiresAt.toIso8601String(),
      'capabilities': capabilities,
      'version': '1.0',
    };
  }

  /// Create from JSON (from QR code scanning)
  factory PairingInvitation.fromJson(Map<String, dynamic> json) {
    return PairingInvitation(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      address: json['address'],
      port: json['port'],
      publicKey: json['publicKey'],
      challenge: json['challenge'],
      expiresAt: DateTime.parse(json['expiresAt']),
      capabilities: Map<String, String>.from(json['capabilities'] ?? {}),
    );
  }

  /// Convert to QR code string
  String toQrString() {
    return jsonEncode(toJson());
  }

  /// Create from QR code string
  factory PairingInvitation.fromQrString(String qrString) {
    final json = jsonDecode(qrString);
    return PairingInvitation.fromJson(json);
  }

  /// Check if the invitation is still valid
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Check if the invitation has expired
  bool get isExpired => !isValid;

  /// Get time remaining until expiration
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  static String _generateChallenge() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final combined = '$timestamp$random';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  @override
  String toString() {
    return 'PairingInvitation(deviceId: $deviceId, deviceName: $deviceName, '
        'address: $address:$port, expires: $expiresAt)';
  }
}

/// Response to a pairing invitation
class PairingResponse {
  final String deviceId;
  final String deviceName;
  final String publicKey;
  final String challengeResponse;
  final Map<String, String> capabilities;
  final DateTime timestamp;

  PairingResponse({
    required this.deviceId,
    required this.deviceName,
    required this.publicKey,
    required this.challengeResponse,
    required this.capabilities,
    required this.timestamp,
  });

  /// Create a response to a pairing invitation
  factory PairingResponse.create({
    required String deviceId,
    required String deviceName,
    required String publicKey,
    required String challenge,
    required Map<String, String> capabilities,
  }) {
    final challengeResponse = _generateChallengeResponse(challenge, publicKey);

    return PairingResponse(
      deviceId: deviceId,
      deviceName: deviceName,
      publicKey: publicKey,
      challengeResponse: challengeResponse,
      capabilities: capabilities,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'publicKey': publicKey,
      'challengeResponse': challengeResponse,
      'capabilities': capabilities,
      'timestamp': timestamp.toIso8601String(),
      'version': '1.0',
    };
  }

  factory PairingResponse.fromJson(Map<String, dynamic> json) {
    return PairingResponse(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      publicKey: json['publicKey'],
      challengeResponse: json['challengeResponse'],
      capabilities: Map<String, String>.from(json['capabilities'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  /// Verify the challenge response
  bool verifyChallengeResponse(String originalChallenge) {
    final expectedResponse = _generateChallengeResponse(
      originalChallenge,
      publicKey,
    );
    return challengeResponse == expectedResponse;
  }

  static String _generateChallengeResponse(String challenge, String publicKey) {
    final combined = '$challenge$publicKey';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  @override
  String toString() {
    return 'PairingResponse(deviceId: $deviceId, deviceName: $deviceName, timestamp: $timestamp)';
  }
}

/// Status of a pairing operation
enum PairingStatus {
  idle,
  generating,
  waitingForScan,
  scanning,
  connecting,
  exchangingKeys,
  verifying,
  completed,
  failed,
  expired,
  cancelled,
}

/// Result of a pairing operation
class PairingResult {
  final bool success;
  final String? deviceId;
  final String? deviceName;
  final String? publicKey;
  final String? error;
  final PairingStatus status;

  const PairingResult({
    required this.success,
    this.deviceId,
    this.deviceName,
    this.publicKey,
    this.error,
    required this.status,
  });

  factory PairingResult.success({
    required String deviceId,
    required String deviceName,
    required String publicKey,
  }) {
    return PairingResult(
      success: true,
      deviceId: deviceId,
      deviceName: deviceName,
      publicKey: publicKey,
      status: PairingStatus.completed,
    );
  }

  factory PairingResult.failure({
    required String error,
    required PairingStatus status,
  }) {
    return PairingResult(success: false, error: error, status: status);
  }

  @override
  String toString() {
    return 'PairingResult(success: $success, status: $status, error: $error)';
  }
}
