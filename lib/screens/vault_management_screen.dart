import 'package:flutter/material.dart';
import '../models/vault_metadata.dart';
import '../services/vault_manager.dart';
import '../widgets/vault_creation_dialog.dart';
import '../widgets/vault_list_tile.dart';
import '../widgets/vault_deletion_dialog.dart';

/// Screen for managing vaults (create, edit, delete, switch)
class VaultManagementScreen extends StatefulWidget {
  final VaultManager vaultManager;

  const VaultManagementScreen({super.key, required this.vaultManager});

  @override
  State<VaultManagementScreen> createState() => _VaultManagementScreenState();
}

class _VaultManagementScreenState extends State<VaultManagementScreen> {
  List<VaultMetadata> _vaults = [];
  VaultMetadata? _activeVault;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final vaults = await widget.vaultManager.getVaults();
      final activeVault = await widget.vaultManager.getActiveVault();

      setState(() {
        _vaults = vaults;
        _activeVault = activeVault;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading vaults: $e')));
      }
    }
  }

  Future<void> _createVault() async {
    final result = await showDialog<VaultMetadata>(
      context: context,
      builder: (context) =>
          VaultCreationDialog(vaultManager: widget.vaultManager),
    );

    if (result != null) {
      await _loadVaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault "${result.name}" created successfully'),
          ),
        );
      }
    }
  }

  Future<void> _switchVault(VaultMetadata vault) async {
    if (vault.id == _activeVault?.id) return;

    try {
      await widget.vaultManager.switchToVault(vault.id);
      await _loadVaults();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to "${vault.name}" vault')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error switching vault: $e')));
      }
    }
  }

  Future<void> _editVault(VaultMetadata vault) async {
    final result = await showDialog<VaultMetadata>(
      context: context,
      builder: (context) =>
          VaultEditDialog(vault: vault, vaultManager: widget.vaultManager),
    );

    if (result != null) {
      await _loadVaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault "${result.name}" updated successfully'),
          ),
        );
      }
    }
  }

  Future<void> _deleteVault(VaultMetadata vault) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          VaultDeletionDialog(vault: vault, vaultManager: widget.vaultManager),
    );

    if (confirmed == true) {
      await _loadVaults();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vault "${vault.name}" deleted successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Vaults'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with vault count
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_vaults.length} ${_vaults.length == 1 ? 'Vault' : 'Vaults'}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Organize your passwords into separate vaults',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Vault list
                Expanded(
                  child: _vaults.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No vaults found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create your first vault to get started',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _vaults.length,
                          itemBuilder: (context, index) {
                            final vault = _vaults[index];
                            final isActive = vault.id == _activeVault?.id;

                            return VaultListTile(
                              vault: vault,
                              isActive: isActive,
                              onTap: () => _switchVault(vault),
                              onEdit: () => _editVault(vault),
                              onDelete: _vaults.length > 1
                                  ? () => _deleteVault(vault)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createVault,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog for editing vault metadata
class VaultEditDialog extends StatefulWidget {
  final VaultMetadata vault;
  final VaultManager vaultManager;

  const VaultEditDialog({
    super.key,
    required this.vault,
    required this.vaultManager,
  });

  @override
  State<VaultEditDialog> createState() => _VaultEditDialogState();
}

class _VaultEditDialogState extends State<VaultEditDialog> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late Color _selectedColor;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.vault.name);
    _selectedIcon = widget.vault.iconName;
    _selectedColor = widget.vault.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateVault() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a vault name';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
      _errorMessage = null;
    });

    try {
      final updatedVault = widget.vault.copyWith(
        name: _nameController.text.trim(),
        iconName: _selectedIcon,
        color: _selectedColor,
      );

      await widget.vaultManager.updateVault(updatedVault);

      if (mounted) {
        Navigator.of(context).pop(updatedVault);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('VaultException: ', '');
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Vault'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vault name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Vault Name',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !_isUpdating,
            ),

            const SizedBox(height: 24),

            // Icon selection
            const Text(
              'Choose Icon',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VaultIcons.available.map((iconName) {
                final isSelected = iconName == _selectedIcon;
                return GestureDetector(
                  onTap: _isUpdating
                      ? null
                      : () {
                          setState(() {
                            _selectedIcon = iconName;
                          });
                        },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withOpacity(0.2)
                          : null,
                      border: Border.all(
                        color: isSelected ? _selectedColor : Colors.grey,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      VaultIcons.getIcon(iconName),
                      color: isSelected ? _selectedColor : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Color selection
            const Text(
              'Choose Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VaultColors.available.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: _isUpdating
                      ? null
                      : () {
                          setState(() {
                            _selectedColor = color;
                          });
                        },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUpdating
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateVault,
          child: _isUpdating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
