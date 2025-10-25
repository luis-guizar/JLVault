import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/breach_checking_service.dart';
import '../models/premium_feature.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';

class HIBPImportScreen extends StatefulWidget {
  const HIBPImportScreen({super.key});

  @override
  State<HIBPImportScreen> createState() => _HIBPImportScreenState();
}

class _HIBPImportScreenState extends State<HIBPImportScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _datasetInfo;
  bool _hasFeature = false;

  @override
  void initState() {
    super.initState();
    _checkFeatureAccess();
    _loadDatasetInfo();
  }

  Future<void> _checkFeatureAccess() async {
    final licenseManager = LicenseManagerFactory.getInstance();
    final featureGate = FeatureGateFactory.create(licenseManager);
    final hasFeature = featureGate.canAccess(PremiumFeature.breachChecking);
    setState(() {
      _hasFeature = hasFeature;
    });
  }

  Future<void> _loadDatasetInfo() async {
    final info = await BreachCheckingService.getDatasetInfo();
    setState(() {
      _datasetInfo = info;
    });
  }

  Future<void> _importDataset() async {
    if (!_hasFeature) {
      _showPremiumRequired();
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
        dialogTitle: 'Select HIBP SHA-1 Hash File',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
        });

        final filePath = result.files.single.path!;
        await BreachCheckingService.importHIBPDataset(filePath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('HIBP dataset imported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadDatasetInfo();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import dataset: ${e.toString()}'),
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

  Future<void> _removeDataset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Dataset'),
        content: const Text(
          'Are you sure you want to remove the HIBP dataset? '
          'This will disable breach checking until you import it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BreachCheckingService.removeDataset();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('HIBP dataset removed'),
              backgroundColor: Colors.orange,
            ),
          );
          await _loadDatasetInfo();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove dataset: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showPremiumRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            const Text('Premium Feature'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Breach checking with HIBP dataset is a premium feature that provides:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            const Text('• Offline breach checking for complete privacy'),
            const Text('• Real-time alerts for compromised passwords'),
            const Text('• Detailed breach information and recommendations'),
            const Text('• Automatic monitoring of all your passwords'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Upgrade to premium to unlock advanced security features',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to premium upgrade screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Get HIBP Dataset'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To enable offline breach checking, you need to download the '
                'HaveIBeenPwned SHA-1 hash list:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. Visit: https://haveibeenpwned.com/Passwords'),
              SizedBox(height: 8),
              Text('2. Download the "SHA-1 ordered by hash" file'),
              SizedBox(height: 8),
              Text('3. Extract the .txt file from the 7z archive'),
              SizedBox(height: 8),
              Text('4. Use the "Import Dataset" button to select the file'),
              SizedBox(height: 16),
              Text(
                'Note: The file is large (~12GB) and may take time to process.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Breach Checking Dataset'),
            if (FeatureGateFactory.isDevelopmentMode)
              const Text(
                'DEV MODE - Feature Unlocked',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showInstructions,
            tooltip: 'Instructions',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing dataset...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take several minutes for large files',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureStatus(),
                  const SizedBox(height: 24),
                  _buildDatasetStatus(),
                  const SizedBox(height: 24),
                  _buildActions(),
                  const SizedBox(height: 24),
                  _buildInstructions(),
                ],
              ),
            ),
    );
  }

  Widget _buildFeatureStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasFeature ? Icons.check_circle : Icons.lock,
                  color: _hasFeature ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Breach Checking Feature',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _hasFeature
                  ? 'You have access to breach checking functionality'
                  : 'Premium subscription required for breach checking',
              style: TextStyle(
                color: _hasFeature ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasetStatus() {
    if (_datasetInfo == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Loading dataset information...'),
        ),
      );
    }

    final isAvailable = _datasetInfo!['available'] as bool;
    final hashCount = _datasetInfo!['hashCount'] as int;
    final size = _datasetInfo!['size'] as int;
    final lastModified = _datasetInfo!['lastModified'] as DateTime?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.error,
                  color: isAvailable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Dataset Status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isAvailable) ...[
              _buildInfoRow('Status', 'Available', Colors.green),
              _buildInfoRow('Hash Count', hashCount.toString(), Colors.black),
              _buildInfoRow('File Size', _formatFileSize(size), Colors.black),
              if (lastModified != null)
                _buildInfoRow(
                  'Last Updated',
                  _formatDate(lastModified),
                  Colors.black,
                ),
            ] else ...[
              _buildInfoRow('Status', 'Not Available', Colors.red),
              const SizedBox(height: 8),
              const Text(
                'Import the HIBP dataset to enable breach checking',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final isAvailable = _datasetInfo?['available'] as bool? ?? false;

    if (!_hasFeature) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.lock, color: Colors.amber.shade700, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Premium Feature Required',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upgrade to premium to import HIBP dataset',
                  style: TextStyle(color: Colors.amber.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showPremiumRequired,
            icon: const Icon(Icons.upgrade),
            label: const Text('Upgrade to Premium'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _importDataset,
          icon: const Icon(Icons.file_upload),
          label: Text(isAvailable ? 'Update Dataset' : 'Import Dataset'),
        ),
        if (isAvailable) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _removeDataset,
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text(
              'Remove Dataset',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About Breach Checking',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This feature allows you to check if your passwords have been '
              'compromised in known data breaches. The checking is done completely '
              'offline using the HaveIBeenPwned database.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Benefits:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text('• Complete privacy - no passwords sent online'),
            const Text('• Fast offline checking'),
            const Text('• Up-to-date breach information'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showInstructions,
              icon: const Icon(Icons.help),
              label: const Text('View Import Instructions'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
