import 'package:flutter/material.dart';
import '../models/vault_metadata.dart';
import '../services/vault_manager.dart';
import '../services/enhanced_auth_service.dart';

/// Dialog for confirming vault deletion with security measures
class VaultDeletionDialog extends StatefulWidget {
  final VaultMetadata vault;
  final VaultManager vaultManager;

  const VaultDeletionDialog({
    super.key,
    required this.vault,
    required this.vaultManager,
  });

  @override
  State<VaultDeletionDialog> createState() => _VaultDeletionDialogState();
}

class _VaultDeletionDialogState extends State<VaultDeletionDialog> {
  final _confirmationController = TextEditingController();
  bool _isDeleting = false;
  bool _isConfirmationValid = false;
  bool _hasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _confirmationController.addListener(_validateConfirmation);
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  void _validateConfirmation() {
    setState(() {
      _isConfirmationValid =
          _confirmationController.text.trim().toLowerCase() ==
          widget.vault.name.toLowerCase();
    });
  }

  Future<void> _authenticate() async {
    try {
      final result =
          await EnhancedAuthService.authenticateForSensitiveOperation(
            operation: 'vault_deletion',
            customReason: 'Authenticate to delete "${widget.vault.name}" vault',
          );

      setState(() {
        _hasAuthenticated = result.isSuccess;
      });

      if (!result.isSuccess && mounted) {
        String message = 'Authentication required to delete vault';
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

  Future<void> _deleteVault() async {
    if (!_hasAuthenticated) {
      await _authenticate();
      if (!_hasAuthenticated) return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await widget.vaultManager.deleteVault(widget.vault.id);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting vault: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Delete Vault', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vault info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.vault.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.vault.color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    VaultIcons.getIcon(widget.vault.iconName),
                    color: widget.vault.color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.vault.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.vault.passwordCount} passwords',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Warning text
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'This action cannot be undone',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deleting this vault will permanently remove all ${widget.vault.passwordCount} passwords and associated data. This action cannot be reversed.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Confirmation input
            Text(
              'Type "${widget.vault.name}" to confirm deletion:',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmationController,
              decoration: InputDecoration(
                hintText: widget.vault.name,
                border: const OutlineInputBorder(),
                suffixIcon: _isConfirmationValid
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
              ),
              enabled: !_isDeleting,
            ),

            const SizedBox(height: 16),

            // Authentication status
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
                        'Authentication required before deletion',
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Cancel'),
        ),
        if (!_hasAuthenticated)
          ElevatedButton(
            onPressed: _isConfirmationValid ? _authenticate : null,
            child: const Text('Authenticate'),
          )
        else
          ElevatedButton(
            onPressed: (_isConfirmationValid && !_isDeleting)
                ? _deleteVault
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Delete Vault'),
          ),
      ],
    );
  }
}
