import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/export_result.dart';
import '../../models/vault_metadata.dart';
import '../../services/export/export_service.dart';
import '../../services/enhanced_auth_service.dart';

/// Dialog for configuring and initiating export operations
class ExportDialog extends StatefulWidget {
  final List<VaultMetadata> availableVaults;
  final ExportService exportService;
  final Function(ExportResult) onExportComplete;

  const ExportDialog({
    super.key,
    required this.availableVaults,
    required this.exportService,
    required this.onExportComplete,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  ExportFormat _selectedFormat = ExportFormat.json;
  final Set<String> _selectedVaultIds = {};
  bool _includePasswords = true;
  bool _includeTOTP = true;
  bool _includeCustomFields = true;
  bool _includeMetadata = false;
  bool _compressOutput = false;
  bool _isExporting = false;
  bool _hasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    // Select all vaults by default
    _selectedVaultIds.addAll(widget.availableVaults.map((v) => v.id));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Passwords'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormatSelection(),
                const SizedBox(height: 16),
                _buildVaultSelection(),
                const SizedBox(height: 16),
                _buildOptionsSelection(),
                if (_selectedFormat == ExportFormat.simpleVaultEncrypted) ...[
                  const SizedBox(height: 16),
                  _buildPasswordFields(),
                ],
                const SizedBox(height: 16),
                _buildAuthenticationSection(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_hasAuthenticated)
          ElevatedButton(
            onPressed: _selectedVaultIds.isNotEmpty ? _authenticate : null,
            child: const Text('Authenticate'),
          )
        else
          ElevatedButton(
            onPressed: _isExporting ? null : _handleExport,
            child: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Export'),
          ),
      ],
    );
  }

  Widget _buildFormatSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Export Format', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...ExportFormat.values.map(
          (format) => RadioListTile<ExportFormat>(
            title: Text(_getFormatDisplayName(format)),
            subtitle: Text(widget.exportService.getFormatDescription(format)),
            value: format,
            groupValue: _selectedFormat,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedFormat = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVaultSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Vaults', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              CheckboxListTile(
                title: const Text('Select All'),
                value:
                    _selectedVaultIds.length == widget.availableVaults.length,
                tristate: true,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedVaultIds.addAll(
                        widget.availableVaults.map((v) => v.id),
                      );
                    } else {
                      _selectedVaultIds.clear();
                    }
                  });
                },
              ),
              const Divider(height: 1),
              ...widget.availableVaults.map(
                (vault) => CheckboxListTile(
                  title: Text(vault.name),
                  subtitle: Text('${vault.passwordCount} passwords'),
                  value: _selectedVaultIds.contains(vault.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedVaultIds.add(vault.id);
                      } else {
                        _selectedVaultIds.remove(vault.id);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Export Options', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text('Include Passwords'),
          subtitle: const Text('Export actual password values'),
          value: _includePasswords,
          onChanged: (value) {
            setState(() {
              _includePasswords = value ?? true;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Include TOTP Secrets'),
          subtitle: const Text('Export two-factor authentication codes'),
          value: _includeTOTP,
          onChanged: (value) {
            setState(() {
              _includeTOTP = value ?? true;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Include Custom Fields'),
          subtitle: const Text('Export additional custom data'),
          value: _includeCustomFields,
          onChanged: (value) {
            setState(() {
              _includeCustomFields = value ?? true;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Include Metadata'),
          subtitle: const Text('Export creation/modification dates'),
          value: _includeMetadata,
          onChanged: (value) {
            setState(() {
              _includeMetadata = value ?? false;
            });
          },
        ),
        CheckboxListTile(
          title: const Text('Compress Output'),
          subtitle: const Text('Create compressed .gz file'),
          value: _compressOutput,
          onChanged: (value) {
            setState(() {
              _compressOutput = value ?? false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encryption Password',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            hintText: 'Enter encryption password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Password is required for encrypted export';
            }
            if (value.length < 8) {
              return 'Password must be at least 8 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            hintText: 'Confirm encryption password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  String _getFormatDisplayName(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.bitwarden:
        return 'Bitwarden';
      case ExportFormat.lastpass:
        return 'LastPass';
      case ExportFormat.simpleVaultEncrypted:
        return 'Simple Vault (Encrypted)';
      case ExportFormat.onepassword:
        return '1Password';
    }
  }

  Future<void> _authenticate() async {
    try {
      final result =
          await EnhancedAuthService.authenticateForSensitiveOperation(
            operation: 'data_export',
            customReason: 'Authenticate to export password data',
          );

      setState(() {
        _hasAuthenticated = result.isSuccess;
      });

      if (!result.isSuccess && mounted) {
        String message = 'Authentication required to export data';
        if (result.errorMessage != null) {
          message = result.errorMessage!;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Authentication failed: $e')));
      }
    }
  }

  Future<void> _handleExport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVaultIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one vault')),
      );
      return;
    }

    // Require authentication for sensitive export operations
    if (!_hasAuthenticated) {
      await _authenticate();
      if (!_hasAuthenticated) return;
    }

    // Pick export location
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Export File',
      fileName: _generateFileName(),
      type: FileType.custom,
      allowedExtensions: [
        widget.exportService.getFileExtension(_selectedFormat).substring(1),
      ],
    );

    if (result == null) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final options = ExportOptions(
        vaultIds: _selectedVaultIds.toList(),
        format: _selectedFormat,
        includePasswords: _includePasswords,
        includeTOTP: _includeTOTP,
        includeCustomFields: _includeCustomFields,
        includeMetadata: _includeMetadata,
        password: _selectedFormat == ExportFormat.simpleVaultEncrypted
            ? _passwordController.text
            : null,
        compressOutput: _compressOutput,
      );

      final exportResult = await widget.exportService.export(result, options);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onExportComplete(exportResult);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildAuthenticationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (!_hasAuthenticated)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Biometric authentication required for data export',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Authentication successful',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _generateFileName() {
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    final extension = widget.exportService.getFileExtension(_selectedFormat);
    final formatName = _selectedFormat.name.toLowerCase();

    return 'simple_vault_export_${formatName}_$timestamp$extension';
  }
}
