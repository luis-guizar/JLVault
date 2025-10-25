import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/pairing_invitation.dart';
import '../services/device_pairing_service.dart';

/// Widget for generating QR codes for device pairing
class QrPairingGeneratorWidget extends StatefulWidget {
  final DevicePairingService pairingService;
  final VoidCallback? onPairingComplete;
  final Function(String)? onError;

  const QrPairingGeneratorWidget({
    super.key,
    required this.pairingService,
    this.onPairingComplete,
    this.onError,
  });

  @override
  State<QrPairingGeneratorWidget> createState() =>
      _QrPairingGeneratorWidgetState();
}

class _QrPairingGeneratorWidgetState extends State<QrPairingGeneratorWidget> {
  PairingInvitation? _invitation;
  PairingStatus _status = PairingStatus.idle;
  String? _error;

  StreamSubscription? _statusSubscription;
  StreamSubscription? _resultSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _statusSubscription = widget.pairingService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    });

    _resultSubscription = widget.pairingService.resultStream.listen((result) {
      if (mounted) {
        if (result.success) {
          widget.onPairingComplete?.call();
        } else {
          setState(() {
            _error = result.error;
          });
          widget.onError?.call(result.error ?? 'Unknown error');
        }
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _resultSubscription?.cancel();
    super.dispose();
  }

  Future<void> _generateQrCode() async {
    try {
      setState(() {
        _error = null;
      });

      final invitation = await widget.pairingService
          .generatePairingInvitation();

      if (mounted) {
        setState(() {
          _invitation = invitation;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
        widget.onError?.call(e.toString());
      }
    }
  }

  Future<void> _cancelPairing() async {
    await widget.pairingService.cancelPairing();
    if (mounted) {
      setState(() {
        _invitation = null;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share QR Code to Pair Device',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_invitation == null) ...[
              const Icon(Icons.qr_code_2, size: 100, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Generate a QR code to allow another device to pair with this one.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _status == PairingStatus.generating
                    ? null
                    : _generateQrCode,
                icon: _status == PairingStatus.generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.qr_code),
                label: Text(
                  _status == PairingStatus.generating
                      ? 'Generating...'
                      : 'Generate QR Code',
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: _invitation!.toQrString(),
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              _buildStatusIndicator(),

              const SizedBox(height: 16),

              if (_invitation!.isValid) ...[
                Text(
                  'Expires in ${_formatDuration(_invitation!.timeRemaining)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _invitation!.toQrString()),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pairing data copied to clipboard'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _cancelPairing,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    IconData icon;
    String text;
    Color color;

    switch (_status) {
      case PairingStatus.waitingForScan:
        icon = Icons.qr_code_scanner;
        text = 'Waiting for scan...';
        color = Colors.blue;
        break;
      case PairingStatus.connecting:
        icon = Icons.link;
        text = 'Connecting...';
        color = Colors.orange;
        break;
      case PairingStatus.exchangingKeys:
        icon = Icons.key;
        text = 'Exchanging keys...';
        color = Colors.orange;
        break;
      case PairingStatus.verifying:
        icon = Icons.verified;
        text = 'Verifying...';
        color = Colors.orange;
        break;
      case PairingStatus.completed:
        icon = Icons.check_circle;
        text = 'Pairing completed!';
        color = Colors.green;
        break;
      case PairingStatus.failed:
        icon = Icons.error;
        text = 'Pairing failed';
        color = Colors.red;
        break;
      case PairingStatus.expired:
        icon = Icons.timer_off;
        text = 'QR code expired';
        color = Colors.red;
        break;
      default:
        icon = Icons.qr_code_scanner;
        text = 'Ready to scan';
        color = Colors.grey;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

/// Widget for scanning QR codes for device pairing
class QrPairingScannerWidget extends StatefulWidget {
  final DevicePairingService pairingService;
  final VoidCallback? onPairingComplete;
  final Function(String)? onError;

  const QrPairingScannerWidget({
    super.key,
    required this.pairingService,
    this.onPairingComplete,
    this.onError,
  });

  @override
  State<QrPairingScannerWidget> createState() => _QrPairingScannerWidgetState();
}

class _QrPairingScannerWidgetState extends State<QrPairingScannerWidget> {
  MobileScannerController? _controller;
  PairingStatus _status = PairingStatus.idle;
  bool _isProcessing = false;

  StreamSubscription? _statusSubscription;
  StreamSubscription? _resultSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _initializeScanner();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _resultSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _setupListeners() {
    _statusSubscription = widget.pairingService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    });

    _resultSubscription = widget.pairingService.resultStream.listen((result) {
      if (mounted) {
        if (result.success) {
          widget.onPairingComplete?.call();
        } else {
          setState(() {
            _isProcessing = false;
          });
          widget.onError?.call(result.error ?? 'Unknown error');
        }
      }
    });
  }

  void _initializeScanner() {
    _controller = MobileScannerController();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null) {
        setState(() {
          _isProcessing = true;
        });

        try {
          await widget.pairingService.acceptPairingInvitation(code);
        } catch (e) {
          widget.onError?.call(e.toString());
          setState(() {
            _isProcessing = false;
          });
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan QR Code to Pair',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _controller != null
                    ? MobileScanner(
                        controller: _controller!,
                        onDetect: _onDetect,
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),

            const SizedBox(height: 16),

            _buildStatusIndicator(),

            const SizedBox(height: 16),

            if (_isProcessing) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Processing pairing request...'),
            ] else ...[
              Text(
                'Point your camera at the QR code displayed on the other device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    IconData icon;
    String text;
    Color color;

    switch (_status) {
      case PairingStatus.scanning:
        icon = Icons.qr_code_scanner;
        text = 'Scanning...';
        color = Colors.blue;
        break;
      case PairingStatus.connecting:
        icon = Icons.link;
        text = 'Connecting...';
        color = Colors.orange;
        break;
      case PairingStatus.exchangingKeys:
        icon = Icons.key;
        text = 'Exchanging keys...';
        color = Colors.orange;
        break;
      case PairingStatus.verifying:
        icon = Icons.verified;
        text = 'Verifying...';
        color = Colors.orange;
        break;
      case PairingStatus.completed:
        icon = Icons.check_circle;
        text = 'Pairing completed!';
        color = Colors.green;
        break;
      case PairingStatus.failed:
        icon = Icons.error;
        text = 'Pairing failed';
        color = Colors.red;
        break;
      default:
        icon = Icons.qr_code_scanner;
        text = 'Ready to scan';
        color = Colors.grey;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
