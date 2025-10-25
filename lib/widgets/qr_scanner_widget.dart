import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/totp_config.dart';
import '../services/totp_setup_service.dart';

/// Widget for scanning QR codes to set up TOTP
class QRScannerWidget extends StatefulWidget {
  final Function(TOTPConfig) onTOTPConfigScanned;
  final VoidCallback? onCancel;

  const QRScannerWidget({
    super.key,
    required this.onTOTPConfigScanned,
    this.onCancel,
  });

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(controller: controller, onDetect: _onDetect),
                // Custom overlay
                _buildScannerOverlay(context),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'Position the QR code within the frame to scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      _showManualEntryDialog(context);
                    },
                    child: const Text('Enter code manually'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (!_isProcessing && barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        _processScanResult(barcode.rawValue!);
      }
    }
  }

  void _processScanResult(String code) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final totpConfig = TOTPSetupService.parseTOTPUri(code);

      if (totpConfig == null) {
        setState(() {
          _errorMessage = 'Invalid QR code. Please scan a valid TOTP QR code.';
          _isProcessing = false;
        });
        return;
      }

      // Validate the configuration
      if (!TOTPSetupService.validateConfiguration(totpConfig)) {
        setState(() {
          _errorMessage = 'Invalid TOTP configuration. Please try again.';
          _isProcessing = false;
        });
        return;
      }

      // Success - call the callback
      widget.onTOTPConfigScanned(totpConfig);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing QR code: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  void _showManualEntryDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ManualTOTPEntryScreen(
          onTOTPConfigCreated: widget.onTOTPConfigScanned,
        ),
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: Theme.of(context).primaryColor,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 250,
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// Screen for manual TOTP entry
class ManualTOTPEntryScreen extends StatefulWidget {
  final Function(TOTPConfig) onTOTPConfigCreated;

  const ManualTOTPEntryScreen({super.key, required this.onTOTPConfigCreated});

  @override
  State<ManualTOTPEntryScreen> createState() => _ManualTOTPEntryScreenState();
}

class _ManualTOTPEntryScreenState extends State<ManualTOTPEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretController = TextEditingController();
  final _issuerController = TextEditingController();
  final _accountController = TextEditingController();

  TOTPAlgorithm _selectedAlgorithm = TOTPAlgorithm.sha1;
  int _selectedDigits = 6;
  int _selectedPeriod = 30;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkClipboard();
  }

  void _checkClipboard() async {
    final hasUri = await TOTPSetupService.clipboardContainsTOTPUri();
    if (hasUri && mounted) {
      _showClipboardDialog();
    }
  }

  void _showClipboardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TOTP URI Found'),
        content: const Text(
          'A TOTP configuration was found in your clipboard. Would you like to use it?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final config = await TOTPSetupService.parseFromClipboard();
              if (config != null) {
                _fillFromConfig(config);
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _fillFromConfig(TOTPConfig config) {
    setState(() {
      _secretController.text = config.secret;
      _issuerController.text = config.issuer;
      _accountController.text = config.accountName;
      _selectedAlgorithm = config.algorithm;
      _selectedDigits = config.digits;
      _selectedPeriod = config.period;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual TOTP Setup'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveConfiguration,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _secretController,
              decoration: const InputDecoration(
                labelText: 'Secret Key *',
                hintText: 'Enter the secret key',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Secret key is required';
                }
                if (!TOTPSetupService.validateSecret(value)) {
                  return 'Invalid secret key format';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _issuerController,
              decoration: const InputDecoration(
                labelText: 'Issuer *',
                hintText: 'e.g., Google, GitHub',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Issuer is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountController,
              decoration: const InputDecoration(
                labelText: 'Account Name *',
                hintText: 'e.g., your email or username',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Account name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Advanced Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<TOTPAlgorithm>(
              value: _selectedAlgorithm,
              decoration: const InputDecoration(
                labelText: 'Algorithm',
                border: OutlineInputBorder(),
              ),
              items: TOTPSetupService.getSupportedAlgorithms()
                  .map(
                    (algorithm) => DropdownMenuItem(
                      value: algorithm,
                      child: Text(algorithm.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedAlgorithm = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedDigits,
              decoration: const InputDecoration(
                labelText: 'Digits',
                border: OutlineInputBorder(),
              ),
              items: TOTPSetupService.getSupportedDigits()
                  .map(
                    (digits) => DropdownMenuItem(
                      value: digits,
                      child: Text(digits.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDigits = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'Period (seconds)',
                border: OutlineInputBorder(),
              ),
              items: TOTPSetupService.getSupportedPeriods()
                  .map(
                    (period) => DropdownMenuItem(
                      value: period,
                      child: Text('$period seconds'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPeriod = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _saveConfiguration,
                child: const Text('Save Configuration'),
              ),
          ],
        ),
      ),
    );
  }

  void _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final config = TOTPSetupService.createManualConfig(
        secret: _secretController.text,
        issuer: _issuerController.text,
        accountName: _accountController.text,
        digits: _selectedDigits,
        period: _selectedPeriod,
        algorithm: _selectedAlgorithm,
      );

      // Validate the configuration
      if (!TOTPSetupService.validateConfiguration(config)) {
        throw Exception('Invalid TOTP configuration');
      }

      widget.onTOTPConfigCreated(config);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _secretController.dispose();
    _issuerController.dispose();
    _accountController.dispose();
    super.dispose();
  }
}

/// Custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path();
    path.addRect(rect);
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
        Radius.circular(borderRadius),
      ),
    );
    path.fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mBorderLength = borderLength > cutOutSize / 2 + borderWidth * 2
        ? borderWidthSize / 2
        : borderLength;
    final mCutOutSize = cutOutSize < width ? cutOutSize : width - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - mCutOutSize / 2 + borderOffset,
      rect.top + height / 2 - mCutOutSize / 2 + borderOffset,
      mCutOutSize - borderOffset * 2,
      mCutOutSize - borderOffset * 2,
    );

    // Draw background
    canvas.saveLayer(rect, backgroundPaint);
    canvas.drawRect(rect, backgroundPaint);

    // Draw the cut out area
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      boxPaint,
    );
    canvas.restore();

    // Draw border
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      borderPaint,
    );

    // Draw corner lines
    final lineLength = mBorderLength;
    final lineWidth = borderWidth;
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    // Top left corner
    canvas.drawLine(
      Offset(cutOutRect.left - lineWidth / 2, cutOutRect.top + lineLength),
      Offset(cutOutRect.left - lineWidth / 2, cutOutRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutOutRect.left, cutOutRect.top - lineWidth / 2),
      Offset(cutOutRect.left + lineLength, cutOutRect.top - lineWidth / 2),
      cornerPaint,
    );

    // Top right corner
    canvas.drawLine(
      Offset(cutOutRect.right + lineWidth / 2, cutOutRect.top + lineLength),
      Offset(cutOutRect.right + lineWidth / 2, cutOutRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutOutRect.right, cutOutRect.top - lineWidth / 2),
      Offset(cutOutRect.right - lineLength, cutOutRect.top - lineWidth / 2),
      cornerPaint,
    );

    // Bottom left corner
    canvas.drawLine(
      Offset(cutOutRect.left - lineWidth / 2, cutOutRect.bottom - lineLength),
      Offset(cutOutRect.left - lineWidth / 2, cutOutRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutOutRect.left, cutOutRect.bottom + lineWidth / 2),
      Offset(cutOutRect.left + lineLength, cutOutRect.bottom + lineWidth / 2),
      cornerPaint,
    );

    // Bottom right corner
    canvas.drawLine(
      Offset(cutOutRect.right + lineWidth / 2, cutOutRect.bottom - lineLength),
      Offset(cutOutRect.right + lineWidth / 2, cutOutRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cutOutRect.right, cutOutRect.bottom + lineWidth / 2),
      Offset(cutOutRect.right - lineLength, cutOutRect.bottom + lineWidth / 2),
      cornerPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
