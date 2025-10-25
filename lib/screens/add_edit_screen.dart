import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/totp_config.dart';
import '../data/db_helper.dart';
import '../services/encryption_service.dart';
import '../services/password_generator_service.dart';
import '../services/vault_manager.dart';
import '../services/vault_encryption_service.dart';
import '../services/crypto_isolate_service.dart';
import '../services/platform_crypto_service.dart';
import '../widgets/password_generator_dialog.dart';
import '../widgets/password_strength_indicator.dart';
import '../screens/totp_setup_screen.dart';
import '../widgets/totp_code_widget.dart';

class AddEditScreen extends StatefulWidget {
  final Account? account;
  final VaultManager vaultManager;
  final VaultEncryptionService encryptionService;

  const AddEditScreen({
    super.key,
    this.account,
    required this.vaultManager,
    required this.encryptionService,
  });

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _passwordStrength = 'Débil';
  String? _currentVaultId;
  TOTPConfig? _totpConfig;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    _initializeVault();
    if (_isEditing) {
      _loadAccountData();
    }
    _passwordController.addListener(_updatePasswordStrength);
  }

  Future<void> _initializeVault() async {
    try {
      if (_isEditing) {
        // Use the vault ID from the existing account
        _currentVaultId = widget.account!.vaultId;
      } else {
        // Get the active vault for new accounts
        final activeVault = await widget.vaultManager.getActiveVault();
        _currentVaultId = activeVault?.id ?? 'default';
      }
    } catch (e) {
      // Fallback to default vault
      _currentVaultId = 'default';
    }
  }

  void _updatePasswordStrength() {
    final newStrength = _checkPasswordStrength(_passwordController.text);
    if (_passwordStrength != newStrength) {
      setState(() {
        _passwordStrength = newStrength;
      });
    }
  }

  Future<void> _loadAccountData() async {
    final account = widget.account!;
    _nameController.text = account.name;

    try {
      // Get master password for isolate operation
      final masterPassword = VaultEncryptionService.currentMasterPassword;
      if (masterPassword != null) {
        Account decryptedAccount;

        // Try platform crypto first, fallback to isolate service
        if (await PlatformCryptoService.isAvailable()) {
          decryptedAccount = await PlatformCryptoService.decryptAccount(
            account,
            account.vaultId,
            masterPassword,
          );
        } else {
          // Fallback to isolate service
          decryptedAccount = await CryptoIsolateService.decryptAccountInIsolate(
            account,
            account.vaultId,
            masterPassword,
          );
        }
        _usernameController.text = decryptedAccount.username;
        _passwordController.text = decryptedAccount.password;
        _totpConfig = decryptedAccount.totpConfig;
      } else {
        // Fallback to direct decryption
        final decryptedAccount = await VaultEncryptionService.decryptAccount(
          account,
        );
        _usernameController.text = decryptedAccount.username;
        _passwordController.text = decryptedAccount.password;
        _totpConfig = decryptedAccount.totpConfig;
      }
    } catch (e) {
      // Fallback to legacy encryption for backward compatibility
      try {
        final decryptedPassword = await EncryptionService.decryptText(
          account.password,
        );
        final decryptedUsername = await EncryptionService.decryptText(
          account.username,
        );
        _usernameController.text = decryptedUsername;
        _passwordController.text = decryptedPassword;
      } catch (legacyError) {
        // If both fail, show the encrypted data (shouldn't happen in normal use)
        _usernameController.text = account.username;
        _passwordController.text = account.password;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Could not decrypt account data'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentVaultId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error: No vault selected')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create account with plain text data
      final account = Account(
        id: widget.account?.id,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        vaultId: _currentVaultId!,
        createdAt: widget.account?.createdAt,
        modifiedAt: DateTime.now(),
        totpConfig: _totpConfig,
      );

      // Get master password for isolate operation
      final masterPassword = VaultEncryptionService.currentMasterPassword;

      // Encrypt the account data using platform crypto for better performance
      Account encryptedAccount;

      if (masterPassword != null) {
        // Try platform crypto first, fallback to isolate service
        if (await PlatformCryptoService.isAvailable()) {
          encryptedAccount = await PlatformCryptoService.encryptAccount(
            account,
            _currentVaultId!,
            masterPassword,
          );
        } else {
          // Fallback to isolate service
          encryptedAccount = await CryptoIsolateService.encryptAccountInIsolate(
            account,
            _currentVaultId!,
            masterPassword,
          );
        }
      } else {
        encryptedAccount = await VaultEncryptionService.encryptAccount(account);
      }

      if (_isEditing) {
        await DBHelper.update(encryptedAccount);
      } else {
        await DBHelper.insert(encryptedAccount);
      }

      // Update vault statistics
      if (!_isEditing) {
        final currentCount = await DBHelper.getAccountCountForVault(
          _currentVaultId!,
        );
        await widget.vaultManager.updateVaultStatistics(
          _currentVaultId!,
          passwordCount: currentCount,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Cuenta Actualizada Correctamente'
                  : 'Cuenta Agregada Correctamente',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPasswordGenerator() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          PasswordGeneratorDialog(initialPassword: _passwordController.text),
    );

    if (result != null) {
      _passwordController.text = result;
      setState(() {});
    }
  }

  void _generateQuickPassword() {
    // Quick generation with default options for the refresh button
    const options = PasswordGenerationOptions(length: 16);
    final password = PasswordGeneratorService.generatePassword(options);
    _passwordController.text = password;
    setState(() {});
  }

  // This function will return 0 for weak, 1 for modarate and 2 for strong

  String _checkPasswordStrength(String password) {
    int score = 0;
    final String lowerPassword = password
        .toLowerCase(); // For case-insensitive checks

    // --- 1. Length Bonus ---
    int length = password.length;
    if (length >= 16) {
      score += 4; // Very strong length
    } else if (length >= 12) {
      score += 2; // Strong length
    } else if (length >= 8) {
      score += 1; // Minimum acceptable length
    }

    // --- 2. Character Variety Bonus ---
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[^A-Za-z0-9]'));

    // Award points only if the character type is present
    score += [hasUpper, hasLower, hasDigit, hasSpecial].where((e) => e).length;

    // --- 3. Penalties (Using lowerPassword for case-insensitivity) ---

    // Single check for "password"
    if (lowerPassword.contains("password")) {
      score -= 2;
    }

    // Check for common sequential/repetitive patterns
    if (lowerPassword.contains("abc") ||
        lowerPassword.contains('123') ||
        lowerPassword.contains("qwer") || // Added common keyboard sequence
        lowerPassword.contains(
          RegExp(r'(.)\1\1'),
        ) // Added penalty for 3+ repetitions (e.g., aaa, 111)
        ) {
      score -= 1;
    }

    // --- 4. Return Strength Rating ---
    if (score >= 6) {
      return "Fuerte";
    } else if (score >= 3) {
      return "Moderada";
    } else {
      return 'Débil';
    }
  }

  Widget _buildTOTPSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.security),
                const SizedBox(width: 8),
                const Text(
                  'TOTP Authenticator',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_totpConfig != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Configured',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add two-factor authentication for extra security',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (_totpConfig != null) ...[
              CompactTOTPCodeWidget(config: _totpConfig!),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _editTOTP,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit TOTP'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _removeTOTP,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _setupTOTP,
                  icon: const Icon(Icons.add),
                  label: const Text('Setup TOTP'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _setupTOTP() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TOTPSetupScreen(
          onTOTPConfigured: (config) {
            setState(() {
              _totpConfig = config;
            });
          },
        ),
      ),
    );
  }

  void _editTOTP() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TOTPSetupScreen(
          existingConfig: _totpConfig,
          onTOTPConfigured: (config) {
            setState(() {
              _totpConfig = config;
            });
          },
        ),
      ),
    );
  }

  void _removeTOTP() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove TOTP'),
        content: const Text(
          'Are you sure you want to remove TOTP authentication from this account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _totpConfig = null;
              });
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

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Account' : 'Add Account'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la cuenta',
                        hintText: 'e.g., Google, Facebook, Bank',
                        prefixIcon: const Icon(Icons.label_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Por favor ingresa un nombre de cuenta';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username/Email',
                        hintText: 'username@example.com',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a username or email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(
                            () {},
                          ), // Trigger rebuild for strength indicator
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  tooltip: 'Mostrar/Ocultar contraseña',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _generateQuickPassword,
                                  tooltip: 'Generar rápido',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.tune),
                                  onPressed: _showPasswordGenerator,
                                  tooltip: 'Generador avanzado',
                                ),
                              ],
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, ingresa una contraseña';
                            }
                            return null;
                          },
                        ),
                        if (_passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          PasswordStrengthIndicator(
                            password: _passwordController.text,
                            showDetails: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTOTPSection(),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _saveAccount,
                      icon: const Icon(Icons.save),
                      label: Text(_isEditing ? 'Actualizar' : 'Guardar'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!_isEditing)
                      OutlinedButton.icon(
                        onPressed: () {
                          _formKey.currentState?.reset();
                          _nameController.clear();
                          _usernameController.clear();
                          _passwordController.clear();
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Form'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
