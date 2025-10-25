import 'package:flutter/material.dart';
import '../models/totp_config.dart';
import '../services/totp_setup_service.dart';
import '../widgets/qr_scanner_widget.dart';

/// Screen for setting up TOTP authentication
class TOTPSetupScreen extends StatefulWidget {
  final Function(TOTPConfig) onTOTPConfigured;
  final TOTPConfig? existingConfig;

  const TOTPSetupScreen({
    super.key,
    required this.onTOTPConfigured,
    this.existingConfig,
  });

  @override
  State<TOTPSetupScreen> createState() => _TOTPSetupScreenState();
}

class _TOTPSetupScreenState extends State<TOTPSetupScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingConfig != null ? 'Edit TOTP' : 'Setup TOTP'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildSetupOptions(),
    );
  }

  Widget _buildSetupOptions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.existingConfig != null) ...[
            _buildExistingConfigCard(),
            const SizedBox(height: 24),
          ],
          const Text(
            'How would you like to set up TOTP?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildSetupOptionCard(
            icon: Icons.qr_code_scanner,
            title: 'Scan QR Code',
            subtitle: 'Use your camera to scan a QR code',
            onTap: _scanQRCode,
          ),
          const SizedBox(height: 16),
          _buildSetupOptionCard(
            icon: Icons.keyboard,
            title: 'Manual Entry',
            subtitle: 'Enter the secret key manually',
            onTap: _manualEntry,
          ),
          const SizedBox(height: 16),
          _buildSetupOptionCard(
            icon: Icons.content_paste,
            title: 'From Clipboard',
            subtitle: 'Use TOTP URI from clipboard',
            onTap: _fromClipboard,
          ),
          const Spacer(),
          if (widget.existingConfig != null)
            OutlinedButton(
              onPressed: _removeTOTP,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Remove TOTP'),
            ),
        ],
      ),
    );
  }

  Widget _buildExistingConfigCard() {
    final config = widget.existingConfig!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current TOTP Configuration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Issuer: ${config.issuer}'),
            Text('Account: ${config.accountName}'),
            Text('Algorithm: ${config.algorithm.name}'),
            Text('Digits: ${config.digits}'),
            Text('Period: ${config.period} seconds'),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  void _scanQRCode() async {
    // Check camera permission
    final hasPermission = await TOTPSetupService.hasCameraPermission();
    if (!hasPermission) {
      final granted = await TOTPSetupService.requestCameraPermission();
      if (!granted) {
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerWidget(
          onTOTPConfigScanned: _handleTOTPConfig,
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _manualEntry() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ManualTOTPEntryScreen(onTOTPConfigCreated: _handleTOTPConfig),
      ),
    );
  }

  void _fromClipboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final config = await TOTPSetupService.parseFromClipboard();

      if (config == null) {
        _showErrorDialog('No valid TOTP configuration found in clipboard');
        return;
      }

      if (!TOTPSetupService.validateConfiguration(config)) {
        _showErrorDialog('Invalid TOTP configuration in clipboard');
        return;
      }

      _handleTOTPConfig(config);
    } catch (e) {
      _showErrorDialog('Error reading from clipboard: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleTOTPConfig(TOTPConfig config) {
    // Show preview dialog before saving
    showDialog(
      context: context,
      builder: (context) => _buildPreviewDialog(config),
    );
  }

  Widget _buildPreviewDialog(TOTPConfig config) {
    return AlertDialog(
      title: const Text('TOTP Configuration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Issuer: ${config.issuer}'),
          Text('Account: ${config.accountName}'),
          Text('Algorithm: ${config.algorithm.name}'),
          Text('Digits: ${config.digits}'),
          Text('Period: ${config.period} seconds'),
          const SizedBox(height: 16),
          const Text(
            'Test Code:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              TOTPSetupService.generateTestCode(config),
              style: const TextStyle(
                fontSize: 18,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onTOTPConfigured(config);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _removeTOTP() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove TOTP'),
        content: const Text(
          'Are you sure you want to remove TOTP authentication for this account? '
          'You will no longer be able to generate codes for this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Pass null to indicate removal
              widget.onTOTPConfigured(
                widget.existingConfig!.copyWith(secret: ''),
              );
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'Camera permission is required to scan QR codes. '
          'Please grant camera permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
