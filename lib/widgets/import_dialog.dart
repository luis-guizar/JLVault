import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/account.dart';
import '../models/vault_metadata.dart';
import '../services/import_service.dart';
import '../services/vault_manager.dart';
import '../data/db_helper.dart';
import '../utils/vault_icons.dart';

/// Dialog for importing passwords with vault selection
class ImportDialog extends StatefulWidget {
  final VaultManager vaultManager;

  const ImportDialog({super.key, required this.vaultManager});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  List<VaultMetadata> _vaults = [];
  VaultMetadata? _selectedVault;
  String? _selectedFilePath;
  String? _selectedFileName;
  ImportFormat _selectedFormat = ImportFormat.csv;
  bool _isLoading = false;
  bool _hasHeader = true;

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    try {
      final vaults = await widget.vaultManager.getVaults();
      final activeVault = await widget.vaultManager.getActiveVault();

      setState(() {
        _vaults = vaults;
        _selectedVault = activeVault;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading vaults: $e')));
      }
    }
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;

          // Auto-detect format based on extension
          if (file.extension?.toLowerCase() == 'json') {
            _selectedFormat = ImportFormat.json;
          } else {
            _selectedFormat = ImportFormat.csv;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
      }
    }
  }

  Future<void> _performImport() async {
    if (_selectedFilePath == null || _selectedVault == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Account> importedAccounts;

      switch (_selectedFormat) {
        case ImportFormat.csv:
          importedAccounts = await ImportService.importFromCsv(
            _selectedFilePath!,
            _selectedVault!.id,
            hasHeader: _hasHeader,
          );
          break;
        case ImportFormat.json:
          importedAccounts = await ImportService.importFromJson(
            _selectedFilePath!,
            _selectedVault!.id,
          );
          break;
        case ImportFormat.bitwarden:
          importedAccounts = await ImportService.importFromBitwarden(
            _selectedFilePath!,
            _selectedVault!.id,
          );
          break;
        case ImportFormat.lastpass:
          importedAccounts = await ImportService.importFromLastPass(
            _selectedFilePath!,
            _selectedVault!.id,
          );
          break;
      }

      if (importedAccounts.isEmpty) {
        throw ImportException('No valid accounts found in the file');
      }

      // Check for duplicates
      final existingAccounts = await DBHelper.getAllForVault(
        _selectedVault!.id,
      );
      final duplicates = ImportService.detectDuplicates(
        importedAccounts,
        existingAccounts,
      );

      if (duplicates.isNotEmpty) {
        final shouldContinue = await _showDuplicateDialog(duplicates);
        if (!shouldContinue) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Import accounts
      int importedCount = 0;
      for (final account in importedAccounts) {
        await DBHelper.insert(account);
        importedCount++;
      }

      // Update vault statistics
      await widget.vaultManager.updateVaultStatistics(
        _selectedVault!.id,
        passwordCount: existingAccounts.length + importedCount,
      );

      if (mounted) {
        Navigator.of(context).pop(importedCount);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<bool> _showDuplicateDialog(List<ImportDuplicate> duplicates) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Duplicate Accounts Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Found ${duplicates.length} duplicate accounts:'),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: duplicates.length,
                    itemBuilder: (context, index) {
                      final duplicate = duplicates[index];
                      return ListTile(
                        dense: true,
                        title: Text(duplicate.imported.name),
                        subtitle: Text(duplicate.imported.username),
                        leading: const Icon(
                          Icons.warning,
                          color: Colors.orange,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Continuing will import all accounts, including duplicates.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Passwords'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vault selection
            const Text(
              'Target Vault',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<VaultMetadata>(
              value: _selectedVault,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _vaults.map((vault) {
                return DropdownMenuItem(
                  value: vault,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: vault.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: vault.color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          VaultIcons.getIcon(vault.iconName),
                          color: vault.color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(vault.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isLoading
                  ? null
                  : (vault) {
                      setState(() {
                        _selectedVault = vault;
                      });
                    },
            ),

            const SizedBox(height: 24),

            // File selection
            const Text(
              'Import File',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedFileName ?? 'No file selected',
                          style: TextStyle(
                            color: _selectedFileName != null
                                ? null
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _selectFile,
                        child: const Text('Browse'),
                      ),
                    ],
                  ),
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Format: ${_selectedFormat.displayName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Format-specific options
            if (_selectedFormat == ImportFormat.csv) ...[
              CheckboxListTile(
                title: const Text('File has header row'),
                subtitle: const Text('First row contains column names'),
                value: _hasHeader,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _hasHeader = value ?? true;
                        });
                      },
                contentPadding: EdgeInsets.zero,
              ),
            ],

            // Format selection
            const SizedBox(height: 16),
            const Text(
              'Import Format',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...ImportFormat.values.map((format) {
              return RadioListTile<ImportFormat>(
                title: Text(format.displayName),
                subtitle: Text(format.description),
                value: format,
                groupValue: _selectedFormat,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedFormat = value!;
                        });
                      },
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              (_selectedFilePath != null &&
                  _selectedVault != null &&
                  !_isLoading)
              ? _performImport
              : null,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
        ),
      ],
    );
  }
}

/// Available import formats
enum ImportFormat {
  csv('Generic CSV', 'Name, Username, Password format'),
  json('Generic JSON', 'JSON array of account objects'),
  bitwarden('Bitwarden JSON', 'Bitwarden vault export'),
  lastpass('LastPass CSV', 'LastPass vault export');

  const ImportFormat(this.displayName, this.description);

  final String displayName;
  final String description;
}
