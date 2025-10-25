import 'package:flutter/material.dart';
import '../services/vault_manager.dart';
import '../widgets/import_dialog.dart';

/// Screen for importing passwords from various sources
class ImportScreen extends StatefulWidget {
  final VaultManager vaultManager;

  const ImportScreen({super.key, required this.vaultManager});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  Future<void> _showImportDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => ImportDialog(vaultManager: widget.vaultManager),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $result passwords'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Passwords'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Import from Other Password Managers',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Import your existing passwords from CSV or JSON files',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),

            const SizedBox(height: 32),

            // Supported formats
            Text(
              'Supported Formats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            _FormatCard(
              icon: Icons.table_chart,
              title: 'CSV Files',
              description:
                  'Generic CSV format with Name, Username, Password columns',
              color: Colors.green,
            ),

            const SizedBox(height: 12),

            _FormatCard(
              icon: Icons.code,
              title: 'JSON Files',
              description: 'JSON array format with account objects',
              color: Colors.blue,
            ),

            const SizedBox(height: 12),

            _FormatCard(
              icon: Icons.security,
              title: 'Bitwarden Export',
              description: 'Bitwarden vault export in JSON format',
              color: Colors.indigo,
            ),

            const SizedBox(height: 12),

            _FormatCard(
              icon: Icons.vpn_key,
              title: 'LastPass Export',
              description: 'LastPass vault export in CSV format',
              color: Colors.red,
            ),

            const Spacer(),

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showImportDialog,
                icon: const Icon(Icons.file_upload),
                label: const Text('Start Import'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Help text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You can choose which vault to import into during the import process.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for displaying supported import formats
class _FormatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FormatCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
