import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/vault_metadata.dart';
import '../data/db_helper.dart';
import '../services/vault_manager.dart';
import '../services/vault_encryption_service.dart';
import '../services/crypto_isolate_service.dart';
import '../services/theme_service.dart';
import '../widgets/account_title.dart';
import '../widgets/vault_switcher.dart';
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

      // Decrypt accounts in isolates for better performance
      final decryptedAccounts =
          await CryptoIsolateService.decryptAccountsInIsolates(
            encryptedAccounts,
            _currentVault!.id,
            masterPassword,
          );

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
        title: const Text('Eliminar cuenta'),
        content: Text(
          '¿Estás seguro que deseas eliminar la cuenta "${account.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${account.name} eliminada')));
      }
    }
  }

  void _navigateToAddEdit([Account? account]) async {
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
          // Vault management - still useful in app bar for quick access
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _navigateToVaultManagement,
            tooltip: 'Gestionar bóvedas',
          ),
          // Lock app - important security action
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              widget.onLogout?.call();
            },
            tooltip: 'Bloquear aplicación',
          ),
          // Overflow menu for less common actions
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'about':
                  showAboutDialog(
                    context: context,
                    applicationName: 'Simple Vault',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.lock, size: 48),
                    children: [
                      const Text(
                        'Un gestor de contraseñas seguro y offline que almacena tus credenciales localmente con cifrado.',
                      ),
                    ],
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('Acerca de'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar...',
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
          : _filteredAccounts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchQuery.isEmpty ? Icons.lock_open : Icons.search_off,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Sin cuentas aún'
                        : 'No se encontraron cuentas',
                    style: const TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  if (_searchQuery.isEmpty)
                    const Text(
                      'Toca + para agregar la primera cuenta',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            )
          : RefreshIndicator(
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
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar Cuenta'),
      ),
    );
  }
}
