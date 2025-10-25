import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/vault_metadata.dart';
import '../models/premium_feature.dart';

import '../data/db_helper.dart';
import '../services/vault_manager.dart';
import '../services/vault_encryption_service.dart';
import '../services/crypto_isolate_service.dart';
import '../services/platform_crypto_service.dart';
import '../services/crypto_test_service.dart';
import '../services/theme_service.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';

import '../utils/vault_icons.dart';
import '../widgets/account_title.dart';
import '../widgets/vault_switcher.dart';
import '../widgets/feature_gate_wrapper.dart';
import '../widgets/upgrade_prompt_dialog.dart';
import '../widgets/translated_text.dart';
import '../widgets/language_switcher.dart';

import 'add_edit_screen.dart';
import 'vault_management_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  final VaultManager vaultManager;
  final VaultEncryptionService encryptionService;
  final ThemeService themeService;

  const HomeScreen({
    super.key,
    this.onLogout,
    required this.vaultManager,
    required this.encryptionService,
    required this.themeService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Account> _accounts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  VaultMetadata? _currentVault;
  late final _featureGate = FeatureGateFactory.create(
    LicenseManagerFactory.getInstance(),
  );

  @override
  void initState() {
    super.initState();
    _loadCurrentVault();
  }

  Future<void> _loadCurrentVault() async {
    try {
      final vault = await widget.vaultManager.getActiveVault();
      setState(() {
        _currentVault = vault;
      });
      await _loadAccounts();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading vault: $e')));
      }
    }
  }

  Future<void> _loadAccounts() async {
    if (_currentVault == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final encryptedAccounts = await DBHelper.getAllForVault(
        _currentVault!.id,
      );

      // Get master password from encryption service
      final masterPassword = VaultEncryptionService.currentMasterPassword;
      if (masterPassword == null) {
        throw Exception('Master password not available');
      }

      List<Account> decryptedAccounts;

      // Try platform crypto first, fallback to isolate service
      final platformAvailable = await PlatformCryptoService.isAvailable();
      if (kDebugMode) {
        print('Platform crypto available: $platformAvailable');
        print('Decrypting ${encryptedAccounts.length} accounts...');
      }

      final stopwatch = Stopwatch()..start();

      if (platformAvailable) {
        decryptedAccounts = await PlatformCryptoService.decryptAccounts(
          encryptedAccounts,
          _currentVault!.id,
          masterPassword,
        );
        if (kDebugMode) {
          print(
            'Platform crypto decryption took: ${stopwatch.elapsedMilliseconds}ms',
          );
        }
      } else {
        // Fallback to isolate service
        decryptedAccounts =
            await CryptoIsolateService.decryptAccountsInIsolates(
              encryptedAccounts,
              _currentVault!.id,
              masterPassword,
            );
        if (kDebugMode) {
          print(
            'Isolate service decryption took: ${stopwatch.elapsedMilliseconds}ms',
          );
        }
      }

      if (mounted) {
        setState(() {
          _accounts = decryptedAccounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading accounts: $e')));
      }
    }
  }

  Future<void> _deleteAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('deleteAccount'),
        content: Text('${'confirmDelete'.tr} "${account.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const TranslatedText('cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const TranslatedText(
              'delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && account.id != null) {
      await DBHelper.delete(account.id!);
      if (mounted) {
        _loadAccounts();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${account.name} ${'itemDeleted'.tr}')),
        );
      }
    }
  }

  void _navigateToAddEdit([Account? account]) async {
    // Check password limit for new accounts (not when editing)
    if (account == null) {
      final hasUnlimited = _featureGate.canAccess(
        PremiumFeature.unlimitedPasswords,
      );
      if (!hasUnlimited && _accounts.length >= 50) {
        _showPasswordLimitDialog();
        return;
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditScreen(
          account: account,
          vaultManager: widget.vaultManager,
          encryptionService: widget.encryptionService,
        ),
      ),
    );
    if (result == true && mounted) {
      _loadAccounts();
    }
  }

  void _showPasswordLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(
        feature: PremiumFeature.unlimitedPasswords,
        featureGate: _featureGate,
        onUpgradeSuccess: () {
          // Refresh the UI after upgrade
          setState(() {});
        },
      ),
    );
  }

  void _showVaultSwitcher() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => VaultSwitcher(
        vaultManager: widget.vaultManager,
        currentVault: _currentVault,
        onVaultChanged: (vault) {
          setState(() {
            _currentVault = vault;
          });
          if (mounted) {
            _loadAccounts();
          }
        },
      ),
    );
  }

  void _navigateToVaultManagement() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VaultManagementScreen(vaultManager: widget.vaultManager),
      ),
    );
    if (result != null) {
      _loadCurrentVault();
    }
  }

  List<Account> get _filteredAccounts {
    if (_searchQuery.isEmpty) return _accounts;
    return _accounts.where((account) {
      final name = account.name.toLowerCase();
      final username = account.username.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  Future<void> _testPlatformCrypto() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Testing crypto performance...'),
          ],
        ),
      ),
    );

    try {
      final results = await CryptoTestService.performanceTest(accountCount: 5);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Crypto Performance Test'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Platform Crypto Available: ${results['platform_crypto']?['available'] ?? false}',
                  ),
                  const SizedBox(height: 8),
                  if (results['platform_crypto']?['success'] == true) ...[
                    Text(
                      'Platform Crypto Time: ${results['platform_crypto']['encrypt_decrypt_time_ms']}ms',
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (results['isolate_service']?['success'] == true) ...[
                    Text(
                      'Isolate Service Time: ${results['isolate_service']['encrypt_decrypt_time_ms']}ms',
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (results['performance_improvement_percent'] != null) ...[
                    Text(
                      'Performance Improvement: ${results['performance_improvement_percent']}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (results['platform_crypto']?['error'] != null) ...[
                    Text(
                      'Platform Error: ${results['platform_crypto']['error']}',
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (results['isolate_service']?['error'] != null) ...[
                    Text(
                      'Isolate Error: ${results['isolate_service']['error']}',
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test failed: $e')));
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.lock_open : Icons.search_off,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          TranslatedText(
            _searchQuery.isEmpty ? 'noAccountsFound' : 'noAccountsFound',
            style: const TextStyle(fontSize: 20, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          if (_searchQuery.isEmpty)
            TranslatedText(
              'addAccount',
              style: const TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return _filteredAccounts.isEmpty
        ? _buildEmptyState()
        : _buildAccountsList();
  }

  Widget _buildAccountsList() {
    return RefreshIndicator(
      onRefresh: _loadAccounts,
      child: ListView.builder(
        itemCount: _filteredAccounts.length,
        itemBuilder: (context, index) {
          final account = _filteredAccounts[index];
          return AccountTile(
            account: account,
            onDelete: () => _deleteAccount(account),
            onEdit: () => _navigateToAddEdit(account),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_currentVault != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _currentVault!.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _currentVault!.color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  VaultIcons.getIcon(_currentVault!.iconName),
                  color: _currentVault!.color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _showVaultSwitcher,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentVault!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                ),
              ),
            ] else
              const Expanded(child: Text('JL Vault')),
          ],
        ),
        elevation: 0,
        actions: [
          // Use Flexible to prevent overflow and allow responsive sizing
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Password limit indicator with constraints
                Flexible(
                  child: StreamBuilder<Map<PremiumFeature, bool>>(
                    stream: _featureGate.accessStream,
                    initialData: _featureGate.currentAccess,
                    builder: (context, snapshot) {
                      return PasswordLimitIndicator(
                        featureGate: _featureGate,
                        currentCount: _accounts.length,
                        showUpgradeButton: true,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Vault management - still useful in app bar for quick access
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  onPressed: _navigateToVaultManagement,
                  tooltip: 'vaultManagement'.tr,
                ),
                // Lock app - important security action
                IconButton(
                  icon: const Icon(Icons.lock_outline),
                  onPressed: () {
                    widget.onLogout?.call();
                  },
                  tooltip: 'lockApp'.tr,
                ),
                // Overflow menu for less common actions with proper constraints
                PopupMenuButton<String>(
                  constraints: BoxConstraints(
                    minWidth: 200,
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'language':
                        // Language switching is handled by the LanguageSwitcher widget
                        break;
                      case 'test_crypto':
                        _testPlatformCrypto();
                        break;
                      case 'about':
                        showAboutDialog(
                          context: context,
                          applicationName: 'appTitle'.tr,
                          applicationVersion: '1.0.0',
                          applicationIcon: const Icon(Icons.lock, size: 48),
                          children: [TranslatedText('appDescription')],
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'language',
                      child: LanguageSwitcher(
                        showLabel: false,
                        isCompact: false,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'test_crypto',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Test Crypto Performance',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'about',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'about'.tr,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'search'.tr,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      floatingActionButton: StreamBuilder<Map<PremiumFeature, bool>>(
        stream: _featureGate.accessStream,
        initialData: _featureGate.currentAccess,
        builder: (context, snapshot) {
          final hasUnlimited =
              snapshot.data?[PremiumFeature.unlimitedPasswords] ?? false;
          final canAddMore = hasUnlimited || _accounts.length < 50;

          return FloatingActionButton.extended(
            onPressed: canAddMore
                ? () => _navigateToAddEdit()
                : _showPasswordLimitDialog,
            icon: const Icon(Icons.add),
            label: Text(canAddMore ? 'addAccount'.tr : 'passwordLimit'.tr),
            backgroundColor: canAddMore ? null : Colors.orange,
          );
        },
      ),
    );
  }
}
