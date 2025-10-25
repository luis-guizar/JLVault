import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/totp_config.dart';

import '../widgets/totp_code_widget.dart';
import '../widgets/time_sync_warning_widget.dart';
import '../screens/totp_setup_screen.dart';
import '../services/vault_manager.dart';
import '../services/vault_encryption_service.dart';
import '../data/db_helper.dart';
import '../services/time_sync_service.dart';

/// Screen for managing TOTP codes for all accounts
class TOTPManagementScreen extends StatefulWidget {
  final VaultManager? vaultManager;
  final VaultEncryptionService? encryptionService;
  final List<Account>? accounts;
  final Function(Account)? onAccountUpdated;

  const TOTPManagementScreen({
    super.key,
    this.vaultManager,
    this.encryptionService,
    this.accounts,
    this.onAccountUpdated,
  });

  @override
  State<TOTPManagementScreen> createState() => _TOTPManagementScreenState();
}

class _TOTPManagementScreenState extends State<TOTPManagementScreen> {
  List<Account> _allAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.accounts != null) {
      _allAccounts = widget.accounts!;
      _isLoading = false;
    } else {
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    try {
      // Load accounts from the current vault
      // This is a simplified version - in a real app you'd get the current vault ID
      final accounts = await _getAllAccountsFromCurrentVault();
      setState(() {
        _allAccounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading accounts: $e')));
      }
    }
  }

  Future<List<Account>> _getAllAccountsFromCurrentVault() async {
    if (widget.vaultManager == null || widget.encryptionService == null) {
      return [];
    }

    try {
      final vault = await widget.vaultManager!.getActiveVault();
      if (vault == null) return [];

      final encryptedAccounts = await DBHelper.getAllForVault(vault.id);
      final decryptedAccounts = await VaultEncryptionService.decryptAccounts(
        encryptedAccounts,
      );
      return decryptedAccounts;
    } catch (e) {
      return [];
    }
  }

  List<Account> get _accountsWithTOTP =>
      _allAccounts.where((account) => account.totpConfig != null).toList();

  List<Account> get _accountsWithoutTOTP =>
      _allAccounts.where((account) => account.totpConfig == null).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TOTP Authenticator'),
        actions: [
          IconButton(
            onPressed: _showTimeSyncInfo,
            icon: const Icon(Icons.info_outline),
            tooltip: 'Time sync info',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTOTPToAccount,
        tooltip: 'Add TOTP to account',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const TimeSyncWarningWidget(),
        Expanded(
          child: _accountsWithTOTP.isEmpty && _accountsWithoutTOTP.isEmpty
              ? _buildEmptyState()
              : _buildAccountsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No accounts found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Create some accounts first to add TOTP authentication',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_accountsWithTOTP.isNotEmpty) ...[
          const Text(
            'Accounts with TOTP',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._accountsWithTOTP.map((account) => _buildTOTPAccountCard(account)),
          const SizedBox(height: 24),
        ],
        if (_accountsWithoutTOTP.isNotEmpty) ...[
          const Text(
            'Accounts without TOTP',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._accountsWithoutTOTP.map(
            (account) => _buildRegularAccountCard(account),
          ),
        ],
      ],
    );
  }

  Widget _buildTOTPAccountCard(Account account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(account.name),
            subtitle: Text(account.username),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleTOTPAccountAction(value, account),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit TOTP'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text(
                      'Remove TOTP',
                      style: TextStyle(color: Colors.red),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TOTPCodeWidget(
              config: account.totpConfig!,
              onCopy: () => _onTOTPCopied(account),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegularAccountCard(Account account) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.account_circle),
        title: Text(account.name),
        subtitle: Text(account.username),
        trailing: TextButton.icon(
          onPressed: () => _setupTOTPForAccount(account),
          icon: const Icon(Icons.security),
          label: const Text('Add TOTP'),
        ),
      ),
    );
  }

  void _handleTOTPAccountAction(String action, Account account) {
    switch (action) {
      case 'edit':
        _editTOTPForAccount(account);
        break;
      case 'remove':
        _removeTOTPFromAccount(account);
        break;
    }
  }

  void _addTOTPToAccount() {
    // Check if there are no accounts at all
    if (_allAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No accounts found. Create some accounts first to add TOTP authentication.',
          ),
        ),
      );
      return;
    }

    // Check if all existing accounts already have TOTP
    if (_accountsWithoutTOTP.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All accounts already have TOTP configured'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Account'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _accountsWithoutTOTP.length,
            itemBuilder: (context, index) {
              final account = _accountsWithoutTOTP[index];
              return ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text(account.name),
                subtitle: Text(account.username),
                onTap: () {
                  Navigator.of(context).pop();
                  _setupTOTPForAccount(account);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _setupTOTPForAccount(Account account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TOTPSetupScreen(
          onTOTPConfigured: (config) => _updateAccountTOTP(account, config),
        ),
      ),
    );
  }

  void _editTOTPForAccount(Account account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TOTPSetupScreen(
          existingConfig: account.totpConfig,
          onTOTPConfigured: (config) => _updateAccountTOTP(account, config),
        ),
      ),
    );
  }

  void _removeTOTPFromAccount(Account account) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove TOTP'),
        content: Text(
          'Are you sure you want to remove TOTP authentication from "${account.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateAccountTOTP(account, null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _updateAccountTOTP(Account account, TOTPConfig? config) {
    final updatedAccount = account.copyWith(totpConfig: config);

    // Update the local list
    final index = _allAccounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _allAccounts[index] = updatedAccount;
    }

    // Call the callback if provided
    widget.onAccountUpdated?.call(updatedAccount);

    if (mounted) {
      setState(() {
        // Trigger rebuild to update the lists
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            config == null
                ? 'TOTP removed from ${account.name}'
                : 'TOTP configured for ${account.name}',
          ),
        ),
      );
    }
  }

  void _onTOTPCopied(Account account) {
    // Optional: Track TOTP usage analytics
  }

  void _showTimeSyncInfo() {
    final info = TimeSyncService.getTimeSyncInfo();
    final recommendations = TimeSyncService.getFixRecommendations(info.status);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time Synchronization'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TOTP codes are time-based and require accurate device time.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Status: ${_getStatusDisplayName(info.status)}'),
              Text('Local Time: ${_formatDateTime(info.localTime)}'),
              Text('UTC Time: ${_formatDateTime(info.utcTime)}'),

              if (info.warningMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Warning:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  info.warningMessage!,
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ],

              if (recommendations.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Recommendations:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...recommendations.map(
                  (rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(rec)),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Text('• Codes change every 30 seconds'),
              const Text('• Device time must be synchronized'),
              const Text('• Codes expire and cannot be reused'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await TimeSyncService.checkTimeSync();
            },
            child: const Text('Check Again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplayName(TimeSyncStatus status) {
    switch (status) {
      case TimeSyncStatus.synchronized:
        return 'Synchronized';
      case TimeSyncStatus.unknown:
        return 'Unknown';
      case TimeSyncStatus.offsetTooLarge:
        return 'Time Zone Issue';
      case TimeSyncStatus.timeUnrealistic:
        return 'Incorrect Time';
      case TimeSyncStatus.utcMismatch:
        return 'Sync Issue';
      case TimeSyncStatus.networkUnavailable:
        return 'Network Unavailable';
      case TimeSyncStatus.checkFailed:
        return 'Check Failed';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
