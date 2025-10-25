import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../models/pairing_invitation.dart';
import '../models/sync_device.dart';
import 'device_manager.dart';

/// Service for handling device pairing via QR codes
class DevicePairingService {
  final DeviceManager _deviceManager;
  final Map<String, Timer> _invitationTimers = {};
  final Map<String, PairingInvitation> _activeInvitations = {};

  final StreamController<PairingStatus> _statusController =
      StreamController<PairingStatus>.broadcast();
  final StreamController<PairingResult> _resultController =
      StreamController<PairingResult>.broadcast();

  PairingStatus _currentStatus = PairingStatus.idle;
  HttpServer? _pairingServer;
  int _pairingPort = 0;

  DevicePairingService(this._deviceManager);

  /// Stream of pairing status changes
  Stream<PairingStatus> get statusStream => _statusController.stream;

  /// Stream of pairing results
  Stream<PairingResult> get resultStream => _resultController.stream;

  /// Current pairing status
  PairingStatus get currentStatus => _currentStatus;

  /// Generate a pairing invitation QR code
  Future<PairingInvitation> generatePairingInvitation({
    Duration validity = const Duration(minutes: 10),
  }) async {
    _updateStatus(PairingStatus.generating);

    try {
      // Start pairing server
      await _startPairingServer();

      final deviceName = await _deviceManager.getDeviceName();
      final publicKey = await _generatePublicKey();

      final invitation = PairingInvitation.create(
        deviceId: _deviceManager.deviceId,
        deviceName: deviceName,
        address: await _getLocalIpAddress(),
        port: _pairingPort,
        publicKey: publicKey,
        capabilities: DeviceCapabilities.getLocalCapabilities(),
        validity: validity,
      );

      _activeInvitations[invitation.challenge] = invitation;

      // Set expiration timer
      _invitationTimers[invitation.challenge] = Timer(validity, () {
        _expireInvitation(invitation.challenge);
      });

      _updateStatus(PairingStatus.waitingForScan);
      return invitation;
    } catch (e) {
      _updateStatus(PairingStatus.failed);
      _notifyResult(
        PairingResult.failure(
          error: 'Failed to generate invitation: ${e.toString()}',
          status: PairingStatus.failed,
        ),
      );
      rethrow;
    }
  }

  /// Accept a pairing invitation from QR code
  Future<PairingResult> acceptPairingInvitation(String qrData) async {
    _updateStatus(PairingStatus.scanning);

    try {
      final invitation = PairingInvitation.fromQrString(qrData);

      if (invitation.isExpired) {
        final result = PairingResult.failure(
          error: 'Invitation has expired',
          status: PairingStatus.expired,
        );
        _notifyResult(result);
        return result;
      }

      _updateStatus(PairingStatus.connecting);

      // Connect to the inviting device
      final socket = await Socket.connect(
        invitation.address,
        invitation.port,
        timeout: const Duration(seconds: 10),
      );

      _updateStatus(PairingStatus.exchangingKeys);

      // Send pairing response
      final response = PairingResponse.create(
        deviceId: _deviceManager.deviceId,
        deviceName: await _deviceManager.getDeviceName(),
        publicKey: await _generatePublicKey(),
        challenge: invitation.challenge,
        capabilities: DeviceCapabilities.getLocalCapabilities(),
      );

      final responseData = jsonEncode(response.toJson());
      socket.write('PAIR_RESPONSE\n');
      socket.write('Content-Length: ${responseData.length}\n\n');
      socket.write(responseData);

      // Wait for confirmation
      final responseBytes = await socket.first;
      final responseString = String.fromCharCodes(responseBytes);

      await socket.close();

      if (responseString.contains('PAIR_SUCCESS')) {
        _updateStatus(PairingStatus.verifying);

        // Create paired device
        final pairedDevice = SyncDevice(
          id: invitation.deviceId,
          name: invitation.deviceName,
          type: 'simple_vault',
          address: invitation.address,
          port: invitation.port,
          capabilities: invitation.capabilities,
          discoveredAt: DateTime.now(),
          status: DeviceStatus.paired,
          publicKey: invitation.publicKey,
        );

        await _deviceManager.pairDevice(pairedDevice);

        final result = PairingResult.success(
          deviceId: invitation.deviceId,
          deviceName: invitation.deviceName,
          publicKey: invitation.publicKey,
        );

        _updateStatus(PairingStatus.completed);
        _notifyResult(result);
        return result;
      } else {
        final result = PairingResult.failure(
          error: 'Pairing rejected by remote device',
          status: PairingStatus.failed,
        );
        _notifyResult(result);
        return result;
      }
    } catch (e) {
      final result = PairingResult.failure(
        error: 'Failed to accept invitation: ${e.toString()}',
        status: PairingStatus.failed,
      );
      _updateStatus(PairingStatus.failed);
      _notifyResult(result);
      return result;
    }
  }

  /// Cancel current pairing operation
  Future<void> cancelPairing() async {
    _updateStatus(PairingStatus.cancelled);
    await _stopPairingServer();
    _clearActiveInvitations();
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _stopPairingServer();
    _clearActiveInvitations();
    await _statusController.close();
    await _resultController.close();
  }

  Future<void> _startPairingServer() async {
    if (_pairingServer != null) {
      await _stopPairingServer();
    }

    _pairingServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _pairingPort = _pairingServer!.port;

    _pairingServer!.listen((HttpRequest request) {
      _handlePairingRequest(request);
    });
  }

  Future<void> _stopPairingServer() async {
    await _pairingServer?.close();
    _pairingServer = null;
    _pairingPort = 0;
  }

  void _handlePairingRequest(HttpRequest request) async {
    try {
      if (request.method == 'POST' && request.uri.path == '/pair') {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);
        final response = PairingResponse.fromJson(data);

        // Find matching invitation
        PairingInvitation? matchingInvitation;
        for (final invitation in _activeInvitations.values) {
          if (response.verifyChallengeResponse(invitation.challenge)) {
            matchingInvitation = invitation;
            break;
          }
        }

        if (matchingInvitation != null && matchingInvitation.isValid) {
          _updateStatus(PairingStatus.verifying);

          // Create paired device
          final pairedDevice = SyncDevice(
            id: response.deviceId,
            name: response.deviceName,
            type: 'simple_vault',
            address: request.connectionInfo?.remoteAddress.address ?? '',
            port: 0, // Will be updated during sync
            capabilities: response.capabilities,
            discoveredAt: DateTime.now(),
            status: DeviceStatus.paired,
            publicKey: response.publicKey,
          );

          await _deviceManager.pairDevice(pairedDevice);

          // Send success response
          request.response.statusCode = 200;
          request.response.write('PAIR_SUCCESS');
          await request.response.close();

          // Clean up invitation
          _activeInvitations.remove(matchingInvitation.challenge);
          _invitationTimers[matchingInvitation.challenge]?.cancel();
          _invitationTimers.remove(matchingInvitation.challenge);

          _updateStatus(PairingStatus.completed);
          _notifyResult(
            PairingResult.success(
              deviceId: response.deviceId,
              deviceName: response.deviceName,
              publicKey: response.publicKey,
            ),
          );
        } else {
          request.response.statusCode = 400;
          request.response.write('PAIR_FAILED: Invalid or expired invitation');
          await request.response.close();
        }
      } else {
        request.response.statusCode = 404;
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('PAIR_ERROR: ${e.toString()}');
      await request.response.close();
    }
  }

  void _expireInvitation(String challenge) {
    _activeInvitations.remove(challenge);
    _invitationTimers.remove(challenge);

    if (_activeInvitations.isEmpty) {
      _updateStatus(PairingStatus.expired);
      _notifyResult(
        PairingResult.failure(
          error: 'Invitation expired',
          status: PairingStatus.expired,
        ),
      );
    }
  }

  void _clearActiveInvitations() {
    for (final timer in _invitationTimers.values) {
      timer.cancel();
    }
    _invitationTimers.clear();
    _activeInvitations.clear();
  }

  void _updateStatus(PairingStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void _notifyResult(PairingResult result) {
    if (!_resultController.isClosed) {
      _resultController.add(result);
    }
  }

  Future<String> _generatePublicKey() async {
    // In a real implementation, this would generate an actual cryptographic key pair
    // For now, we'll use a simple hash-based approach
    final deviceId = _deviceManager.deviceId;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final combined = '$deviceId$timestamp';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback &&
              !address.isLinkLocal) {
            return address.address;
          }
        }
      }
      return '127.0.0.1';
    } catch (e) {
      return '127.0.0.1';
    }
  }
}
