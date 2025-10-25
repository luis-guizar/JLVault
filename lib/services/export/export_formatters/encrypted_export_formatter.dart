import 'dart:convert';
import 'dart:typed_data';
import '../../../models/export_result.dart';
import '../../vault_crypto_manager.dart';
import 'export_formatter.dart';

/// Formatter for encrypted Simple Vault export format
class EncryptedExportFormatter implements ExportFormatter {
  EncryptedExportFormatter();

  @override
  String get mimeType => 'application/octet-stream';

  @override
  String get fileExtension => '.svault';

  @override
  String get description => 'Simple Vault encrypted backup';

  @override
  bool get supportsEncryption => true;

  @override
  bool get supportsCustomFields => true;

  @override
  bool get supportsTOTP => true;

  @override
  Future<Uint8List> format(
    List<ExportedAccount> accounts,
    ExportOptions options,
  ) async {
    if (options.password == null || options.password!.isEmpty) {
      throw ArgumentError('Password is required for encrypted export');
    }

    // Create the export data structure
    final exportData = {
      'version': '1.0.0',
      'format': 'simple_vault_encrypted',
      'metadata': {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportedBy': 'Simple Vault',
        'accountCount': accounts.length,
        'vaultCount': accounts.map((a) => a.vaultId).toSet().length,
        'includePasswords': options.includePasswords,
        'includeTOTP': options.includeTOTP,
        'includeCustomFields': options.includeCustomFields,
        'includeMetadata': options.includeMetadata,
      },
      'vaults': _groupAccountsByVault(accounts),
      'accounts': accounts
          .map((account) => _formatAccount(account, options))
          .toList(),
    };

    // Convert to JSON
    final jsonData = const JsonEncoder().convert(exportData);

    // Encrypt the data using a temporary vault ID for export
    final encryptedData = await VaultCryptoManager.encryptForVault(
      jsonData,
      'export_temp',
      options.password!,
    );

    // Create the final export structure
    final exportStructure = {
      'header': {
        'version': '1.0.0',
        'format': 'simple_vault_encrypted',
        'encryption': 'AES-256-GCM',
        'keyDerivation': 'PBKDF2',
        'iterations': 100000,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'data': encryptedData, // Already base64 encoded by VaultCryptoManager
    };

    final finalJson = const JsonEncoder().convert(exportStructure);
    return Uint8List.fromList(utf8.encode(finalJson));
  }

  /// Groups accounts by vault for better organization
  Map<String, Map<String, dynamic>> _groupAccountsByVault(
    List<ExportedAccount> accounts,
  ) {
    final vaults = <String, Map<String, dynamic>>{};

    for (final account in accounts) {
      if (!vaults.containsKey(account.vaultId)) {
        vaults[account.vaultId] = {
          'id': account.vaultId,
          'name': account.vaultName,
          'accountCount': 0,
        };
      }
      vaults[account.vaultId]!['accountCount'] =
          (vaults[account.vaultId]!['accountCount'] as int) + 1;
    }

    return vaults;
  }

  /// Formats a single account for encrypted export
  Map<String, dynamic> _formatAccount(
    ExportedAccount account,
    ExportOptions options,
  ) {
    final accountData = <String, dynamic>{
      'id': account.id,
      'title': account.title,
      'username': account.username,
      'url': account.url,
      'notes': account.notes,
      'tags': account.tags,
      'category': account.category,
      'vaultId': account.vaultId,
      'vaultName': account.vaultName,
    };

    // Always include password in encrypted export
    accountData['password'] = account.password;

    // Include TOTP if requested and available
    if (options.includeTOTP && account.totpData != null) {
      accountData['totp'] = {
        'secret': account.totpData!.secret,
        'issuer': account.totpData!.issuer,
        'accountName': account.totpData!.accountName,
        'digits': account.totpData!.digits,
        'period': account.totpData!.period,
        'algorithm': account.totpData!.algorithm,
      };
    }

    // Include custom fields if requested and available
    if (options.includeCustomFields && account.customFields.isNotEmpty) {
      accountData['customFields'] = account.customFields
          .map(
            (field) => {
              'name': field.name,
              'value': field.value,
              'type': field.type,
            },
          )
          .toList();
    }

    // Include metadata if requested
    if (options.includeMetadata) {
      accountData['metadata'] = {
        'createdAt': account.createdAt?.toIso8601String(),
        'modifiedAt': account.modifiedAt?.toIso8601String(),
        ...?account.metadata,
      };
    }

    return accountData;
  }

  /// Decrypts and validates an encrypted export file
  static Future<Map<String, dynamic>?> decryptExport(
    Uint8List encryptedData,
    String password,
    VaultCryptoManager cryptoManager,
  ) async {
    try {
      // Parse the export structure
      final jsonString = utf8.decode(encryptedData);
      final exportStructure = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate header
      final header = exportStructure['header'] as Map<String, dynamic>?;
      if (header == null || header['format'] != 'simple_vault_encrypted') {
        return null;
      }

      // Decrypt the data
      final encryptedDataString = exportStructure['data'] as String;
      final decryptedJson = await VaultCryptoManager.decryptForVault(
        encryptedDataString,
        'export_temp',
        password,
      );
      return jsonDecode(decryptedJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}
