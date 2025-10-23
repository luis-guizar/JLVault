import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account.dart';
import '../services/encryption_service.dart';

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
    final decrypted = await EncryptionService.decryptText(account.password);
    await Clipboard.setData(ClipboardData(text: decrypted));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password copied')));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(account.name),
      subtitle: Text(account.username),
      trailing: Wrap(
        children: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () => _copyPassword(context),
          ),
          IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
        ],
      ),
    );
  }
}
