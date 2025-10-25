import 'package:flutter/material.dart';
import '../models/vault_metadata.dart';
import '../services/vault_manager.dart';
import '../services/auth_service.dart';
import '../utils/vault_icons.dart';

/// Widget for switching between vaults with authentication
class VaultSwitcher extends StatefulWidget {
  final VaultManager vaultManager;
  final VaultMetadata? currentVault;
  final Function(VaultMetadata) onVaultChanged;

  const VaultSwitcher({
    super.key,
    required this.vaultManager,
    required this.currentVault,
    required this.onVaultChanged,
  });

  @override
  State<VaultSwitcher> createState() => _VaultSwitcherState();
}

class _VaultSwitcherState extends State<VaultSwitcher> {
  List<VaultMetadata> _vaults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    try {
      final vaults = await widget.vaultManager.getVaults();
      if (mounted) {
        setState(() {
          _vaults = vaults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _switchVault(VaultMetadata vault) async {
    if (vault.id == widget.currentVault?.id) {
      Navigator.of(context).pop();
      return;
    }

    // Show authentication dialog
    final authenticated = await _showAuthenticationDialog(vault);
    if (!authenticated) return;

    try {
      await widget.vaultManager.switchToVault(vault.id);
      widget.onVaultChanged(vault);

      if (mounted) {
        Navigator.of(context).pop();
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

  Future<bool> _showAuthenticationDialog(VaultMetadata vault) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => VaultAuthenticationDialog(vault: vault),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Switch Vault',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Vault list
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _vaults.length,
                itemBuilder: (context, index) {
                  final vault = _vaults[index];
                  final isActive = vault.id == widget.currentVault?.id;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: vault.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: vault.color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        VaultIcons.getIcon(vault.iconName),
                        color: vault.color,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            vault.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: vault.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 12,
                                color: vault.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${vault.passwordCount} passwords • ${vault.securityScore.toInt()}% secure',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _switchVault(vault),
                    selected: isActive,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog for authenticating vault access
class VaultAuthenticationDialog extends StatefulWidget {
  final VaultMetadata vault;

  const VaultAuthenticationDialog({super.key, required this.vault});

  @override
  State<VaultAuthenticationDialog> createState() =>
      _VaultAuthenticationDialogState();
}

class _VaultAuthenticationDialogState extends State<VaultAuthenticationDialog> {
  bool _isAuthenticating = false;

  Future<void> _authenticate() async {
    if (mounted) {
      setState(() {
        _isAuthenticating = true;
      });
    }

    try {
      final authenticated = await AuthService.authenticate(
        reason: 'Authenticate to access "${widget.vault.name}" vault',
      );

      if (mounted) {
        Navigator.of(context).pop(authenticated);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Authentication failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.vault.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.vault.color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              VaultIcons.getIcon(widget.vault.iconName),
              color: widget.vault.color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Access ${widget.vault.name}',
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.security, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Authentication required to access this vault',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Use your device authentication to unlock "${widget.vault.name}"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isAuthenticating
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isAuthenticating ? null : _authenticate,
          child: _isAuthenticating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Authenticate'),
        ),
      ],
    );
  }
}
