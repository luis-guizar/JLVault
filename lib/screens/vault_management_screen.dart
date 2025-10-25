import 'package:flutter/material.dart';
import '../models/vault_metadata.dart';
import '../models/premium_feature.dart';
import '../services/vault_manager.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';
import '../widgets/vault_card.dart';
import '../widgets/feature_gate_wrapper.dart';
import '../widgets/upgrade_prompt_dialog.dart';

/// Screen for managing vaults with biometric authentication for sensitive operations
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
  String? _error;
  late final _featureGate = FeatureGateFactory.create(
    LicenseManagerFactory.getInstance(),
  );

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final vaults = await widget.vaultManager.getVaults();
      final activeVault = await widget.vaultManager.getActiveVault();

      setState(() {
        _vaults = vaults;
        _activeVault = activeVault;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vaults'),
        actions: [
          StreamBuilder<Map<PremiumFeature, bool>>(
            stream: _featureGate.accessStream,
            initialData: _featureGate.currentAccess,
            builder: (context, snapshot) {
              final hasMultipleVaults =
                  snapshot.data?[PremiumFeature.multipleVaults] ?? false;
              final canCreateMore = hasMultipleVaults || _vaults.length < 1;

              return IconButton(
                icon: const Icon(Icons.add),
                onPressed: canCreateMore
                    ? _showCreateVaultDialog
                    : _showMultipleVaultsUpgrade,
                tooltip: canCreateMore
                    ? 'Create New Vault'
                    : 'Upgrade for Multiple Vaults',
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading vaults',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadVaults, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_vaults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_outlined, size: 64),
            SizedBox(height: 16),
            Text('No vaults found', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text(
              'Create your first vault to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVaults,
      child: StreamBuilder<Map<PremiumFeature, bool>>(
        stream: _featureGate.accessStream,
        initialData: _featureGate.currentAccess,
        builder: (context, snapshot) {
          final hasMultipleVaults =
              snapshot.data?[PremiumFeature.multipleVaults] ?? false;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount:
                _vaults.length +
                (hasMultipleVaults || _vaults.length < 2 ? 0 : 1),
            itemBuilder: (context, index) {
              // Show upgrade card if user has multiple vaults but no premium access
              if (index >= _vaults.length) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: FeatureGateWrapper(
                    feature: PremiumFeature.multipleVaults,
                    featureGate: _featureGate,
                    customMessage:
                        'You have multiple vaults but need Premium to access them all.',
                    child: const SizedBox.shrink(),
                  ),
                );
              }

              final vault = _vaults[index];
              final isActive = _activeVault?.id == vault.id;
              final isPremiumVault = index > 0 && !hasMultipleVaults;

              return VaultCard(
                vault: vault,
                isActive: isActive,
                onTap: isPremiumVault
                    ? _showMultipleVaultsUpgrade
                    : () => _switchToVault(vault),
                onEdit: isPremiumVault
                    ? null
                    : () => _showEditVaultDialog(vault),
                onDelete: _vaults.length > 1 && !isPremiumVault
                    ? () => _deleteVault(vault)
                    : null,
                isPremiumLocked: isPremiumVault,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _switchToVault(VaultMetadata vault) async {
    if (_activeVault?.id == vault.id) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await widget.vaultManager.switchToVault(vault.id);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await _loadVaults(); // Refresh the list

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to vault "${vault.name}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch vault: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteVault(VaultMetadata vault) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vault'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the vault "${vault.name}"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All passwords in this vault will be permanently deleted.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                  Icon(Icons.fingerprint, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Biometric authentication will be required to complete this action.',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Authenticating and deleting vault...'),
            ],
          ),
        ),
      );

      // The vault manager will handle biometric authentication
      await widget.vaultManager.deleteVault(vault.id);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        await _loadVaults(); // Refresh the list

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vault "${vault.name}" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        String errorMessage = e.toString();
        if (errorMessage.contains('VaultException:')) {
          errorMessage = errorMessage.replaceFirst('VaultException: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showMultipleVaultsUpgrade() {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: PremiumFeature.multipleVaults,
        featureGate: _featureGate,
        onUpgradeSuccess: () {
          // Refresh the UI after upgrade
          setState(() {});
        },
      ),
    );
  }

  Future<void> _showCreateVaultDialog() async {
    // Check if user can create multiple vaults
    final hasMultipleVaults = _featureGate.canAccess(
      PremiumFeature.multipleVaults,
    );
    if (!hasMultipleVaults && _vaults.length >= 1) {
      _showMultipleVaultsUpgrade();
      return;
    }

    final result = await showDialog<VaultMetadata>(
      context: context,
      builder: (context) => const CreateVaultDialog(),
    );

    if (result != null) {
      try {
        await widget.vaultManager.createVault(
          name: result.name,
          iconName: result.iconName,
          color: result.color,
        );

        await _loadVaults();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vault "${result.name}" created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create vault: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditVaultDialog(VaultMetadata vault) async {
    final result = await showDialog<VaultMetadata>(
      context: context,
      builder: (context) => EditVaultDialog(vault: vault),
    );

    if (result != null) {
      try {
        await widget.vaultManager.updateVault(result);
        await _loadVaults();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vault "${result.name}" updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update vault: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Dialog for creating a new vault
class CreateVaultDialog extends StatefulWidget {
  const CreateVaultDialog({super.key});

  @override
  State<CreateVaultDialog> createState() => _CreateVaultDialogState();
}

class _CreateVaultDialogState extends State<CreateVaultDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _selectedIcon = 'lock';
  Color _selectedColor = Colors.blue;

  final List<String> _availableIcons = [
    'lock',
    'work',
    'home',
    'family_restroom',
    'school',
    'shopping_cart',
    'credit_card',
    'cloud',
    'security',
    'folder',
  ];

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Vault'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Vault Name',
                    hintText: 'Enter vault name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a vault name';
                    }
                    if (value.trim().length < 2) {
                      return 'Vault name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildIconSelector(),
                const SizedBox(height: 16),
                _buildColorSelector(),
                // Add extra space to ensure content is accessible above keyboard
                SizedBox(
                  height: MediaQuery.of(context).viewInsets.bottom > 0 ? 50 : 0,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _handleCreate, child: const Text('Create')),
      ],
    );
  }

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableIcons.map((iconName) {
            final isSelected = _selectedIcon == iconName;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = iconName),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? _selectedColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? _selectedColor : Colors.grey,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconData(iconName),
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'lock':
        return Icons.lock;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'school':
        return Icons.school;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'credit_card':
        return Icons.credit_card;
      case 'cloud':
        return Icons.cloud;
      case 'security':
        return Icons.security;
      case 'folder':
        return Icons.folder;
      default:
        return Icons.lock;
    }
  }

  void _handleCreate() {
    if (_formKey.currentState!.validate()) {
      final vault = VaultMetadata.create(
        name: _nameController.text.trim(),
        iconName: _selectedIcon,
        color: _selectedColor,
      );
      Navigator.of(context).pop(vault);
    }
  }
}

/// Dialog for editing an existing vault
class EditVaultDialog extends StatefulWidget {
  final VaultMetadata vault;

  const EditVaultDialog({super.key, required this.vault});

  @override
  State<EditVaultDialog> createState() => _EditVaultDialogState();
}

class _EditVaultDialogState extends State<EditVaultDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late Color _selectedColor;

  final List<String> _availableIcons = [
    'lock',
    'work',
    'home',
    'family_restroom',
    'school',
    'shopping_cart',
    'credit_card',
    'cloud',
    'security',
    'folder',
  ];

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Vault'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Vault Name',
                    hintText: 'Enter vault name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a vault name';
                    }
                    if (value.trim().length < 2) {
                      return 'Vault name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildIconSelector(),
                const SizedBox(height: 16),
                _buildColorSelector(),
                // Add extra space to ensure content is accessible above keyboard
                SizedBox(
                  height: MediaQuery.of(context).viewInsets.bottom > 0 ? 50 : 0,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _handleUpdate, child: const Text('Update')),
      ],
    );
  }

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Icon', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableIcons.map((iconName) {
            final isSelected = _selectedIcon == iconName;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = iconName),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? _selectedColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? _selectedColor : Colors.grey,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconData(iconName),
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'lock':
        return Icons.lock;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'family_restroom':
        return Icons.family_restroom;
      case 'school':
        return Icons.school;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'credit_card':
        return Icons.credit_card;
      case 'cloud':
        return Icons.cloud;
      case 'security':
        return Icons.security;
      case 'folder':
        return Icons.folder;
      default:
        return Icons.lock;
    }
  }

  void _handleUpdate() {
    if (_formKey.currentState!.validate()) {
      final updatedVault = widget.vault.copyWith(
        name: _nameController.text.trim(),
        iconName: _selectedIcon,
        color: _selectedColor,
      );
      Navigator.of(context).pop(updatedVault);
    }
  }
}
