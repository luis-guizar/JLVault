import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import '../services/totp_generator.dart';
import '../widgets/totp_code_widget.dart';

class AccountTile extends StatelessWidget {
  final Account account;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const AccountTile({
    super.key,
    required this.account,
    required this.onDelete,
    required this.onEdit,
  });

  Future<void> _copyPassword(BuildContext context) async {
    try {
      // The password is already decrypted when loaded in the home screen
      await Clipboard.setData(ClipboardData(text: account.password));

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password copied')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error copying password: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.1),
              child: Icon(
                Icons.account_circle,
                color: Theme.of(context).primaryColor,
              ),
            ),
            title: Row(
              children: [
                Expanded(child: Text(account.name)),
                if (account.totpConfig != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.security,
                          size: 12,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'TOTP',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Text(account.username),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'copy_password':
                    _copyPassword(context);
                    break;
                  case 'edit':
                    onEdit();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'copy_password',
                  child: Row(
                    children: [
                      Icon(Icons.copy),
                      SizedBox(width: 8),
                      Text('Copy Password'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (account.totpConfig != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: CompactTOTPCodeWidget(
                config: account.totpConfig!,
                onTap: () => _copyTOTPCode(context),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _copyTOTPCode(BuildContext context) async {
    if (account.totpConfig == null) return;

    // Generate and copy the actual TOTP code
    try {
      final code = TOTPGenerator.generateCode(account.totpConfig!);
      await Clipboard.setData(ClipboardData(text: code));

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('TOTP code copied')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error copying TOTP code: $e')));
      }
    }
  }
}
