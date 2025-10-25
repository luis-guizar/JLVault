import 'package:flutter/material.dart';
import '../services/vault_manager.dart';

import '../utils/vault_icons.dart';
import 'translated_text.dart';

/// Dialog for creating a new vault with customization options
class VaultCreationDialog extends StatefulWidget {
  final VaultManager vaultManager;

  const VaultCreationDialog({super.key, required this.vaultManager});

  @override
  State<VaultCreationDialog> createState() => _VaultCreationDialogState();
}

class _VaultCreationDialogState extends State<VaultCreationDialog> {
  final _nameController = TextEditingController();
  String _selectedIcon = VaultIcons.available.first;
  Color _selectedColor = VaultColors.available.first;
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createVault() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a vault name';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final vault = await widget.vaultManager.createVault(
        name: _nameController.text.trim(),
        iconName: _selectedIcon,
        color: _selectedColor,
      );

      if (mounted) {
        Navigator.of(context).pop(vault);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('VaultException: ', '');
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const TranslatedText('createNewVault'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vault name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'vaultName'.tr,
                hintText: 'e.g., Work, Personal, Family',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !_isCreating,
            ),

            const SizedBox(height: 24),

            // Icon selection
            TranslatedText(
              'chooseIcon',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VaultIcons.available.map((iconName) {
                final isSelected = iconName == _selectedIcon;
                return GestureDetector(
                  onTap: _isCreating
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
                          ? _selectedColor.withValues(alpha: 0.2)
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
            TranslatedText(
              'chooseColor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: VaultColors.available.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: _isCreating
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
                                color: color.withValues(alpha: 0.5),
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
          onPressed: _isCreating
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const TranslatedText('cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createVault,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const TranslatedText('create'),
        ),
      ],
    );
  }
}
