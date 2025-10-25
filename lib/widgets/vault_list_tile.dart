import 'package:flutter/material.dart';
import '../models/vault_metadata.dart';
import '../utils/vault_icons.dart';

import 'translated_text.dart';

/// A list tile widget for displaying vault information
class VaultListTile extends StatelessWidget {
  final VaultMetadata vault;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const VaultListTile({
    super.key,
    required this.vault,
    this.isActive = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isActive ? 4 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: vault.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: vault.color.withOpacity(0.3), width: 1),
          ),
          child: Icon(
            VaultIcons.getIcon(vault.iconName),
            color: vault.color,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                vault.name,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.password, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${vault.passwordCount} passwords',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.security,
                      size: 16,
                      color: _getSecurityColor(vault.securityScore),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${vault.securityScore.toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getSecurityColor(vault.securityScore),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Last accessed: ${_formatLastAccessed(vault.lastAccessedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit?.call();
                break;
              case 'delete':
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  TranslatedText('edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  TranslatedText('delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getSecurityColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatLastAccessed(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'justNow'.tr;
    }
  }
}
