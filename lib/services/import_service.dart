import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import '../models/account.dart';

/// Service for importing password data from various formats
class ImportService {
  /// Imports accounts from a CSV file to a specific vault
  static Future<List<Account>> importFromCsv(
    String filePath,
    String targetVaultId, {
    bool hasHeader = true,
    String delimiter = ',',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('File not found: $filePath');
    }

    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(
      content,
      fieldDelimiter: delimiter,
    );

    if (rows.isEmpty) {
      throw ImportException('CSV file is empty');
    }

    final accounts = <Account>[];
    final startIndex = hasHeader ? 1 : 0;

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 3) {
        continue; // Skip incomplete rows
      }

      final account = Account(
        name: row[0]?.toString() ?? 'Imported Account $i',
        username: row[1]?.toString() ?? '',
        password: row[2]?.toString() ?? '',
        vaultId: targetVaultId,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      accounts.add(account);
    }

    return accounts;
  }

  /// Imports accounts from a JSON file to a specific vault
  static Future<List<Account>> importFromJson(
    String filePath,
    String targetVaultId,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('File not found: $filePath');
    }

    final content = await file.readAsString();
    final jsonData = jsonDecode(content);

    if (jsonData is! List) {
      throw ImportException('JSON file must contain an array of accounts');
    }

    final accounts = <Account>[];

    for (final item in jsonData) {
      if (item is! Map<String, dynamic>) {
        continue; // Skip invalid items
      }

      final account = Account(
        name:
            item['name']?.toString() ??
            item['title']?.toString() ??
            'Imported Account',
        username:
            item['username']?.toString() ?? item['login']?.toString() ?? '',
        password: item['password']?.toString() ?? '',
        vaultId: targetVaultId,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      accounts.add(account);
    }

    return accounts;
  }

  /// Imports accounts from Bitwarden JSON export to a specific vault
  static Future<List<Account>> importFromBitwarden(
    String filePath,
    String targetVaultId,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('File not found: $filePath');
    }

    final content = await file.readAsString();
    final jsonData = jsonDecode(content);

    if (jsonData is! Map<String, dynamic> || !jsonData.containsKey('items')) {
      throw ImportException('Invalid Bitwarden export format');
    }

    final items = jsonData['items'] as List;
    final accounts = <Account>[];

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;

      // Only import login items
      if (item['type'] != 1) continue;

      final login = item['login'] as Map<String, dynamic>?;
      if (login == null) continue;

      final account = Account(
        name: item['name']?.toString() ?? 'Imported Account',
        username: login['username']?.toString() ?? '',
        password: login['password']?.toString() ?? '',
        vaultId: targetVaultId,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      accounts.add(account);
    }

    return accounts;
  }

  /// Imports accounts from LastPass CSV export to a specific vault
  static Future<List<Account>> importFromLastPass(
    String filePath,
    String targetVaultId,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ImportException('File not found: $filePath');
    }

    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);

    if (rows.isEmpty) {
      throw ImportException('CSV file is empty');
    }

    // LastPass CSV format: url,username,password,extra,name,grouping,fav
    final accounts = <Account>[];

    for (int i = 1; i < rows.length; i++) {
      // Skip header
      final row = rows[i];
      if (row.length < 5) continue;

      final account = Account(
        name: row[4]?.toString() ?? 'Imported Account $i',
        username: row[1]?.toString() ?? '',
        password: row[2]?.toString() ?? '',
        vaultId: targetVaultId,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );

      accounts.add(account);
    }

    return accounts;
  }

  /// Detects duplicate accounts based on name and username
  static List<ImportDuplicate> detectDuplicates(
    List<Account> importedAccounts,
    List<Account> existingAccounts,
  ) {
    final duplicates = <ImportDuplicate>[];

    for (final imported in importedAccounts) {
      for (final existing in existingAccounts) {
        if (_accountsMatch(imported, existing)) {
          duplicates.add(
            ImportDuplicate(imported: imported, existing: existing),
          );
          break;
        }
      }
    }

    return duplicates;
  }

  /// Checks if two accounts are considered duplicates
  static bool _accountsMatch(Account a, Account b) {
    return a.name.toLowerCase().trim() == b.name.toLowerCase().trim() &&
        a.username.toLowerCase().trim() == b.username.toLowerCase().trim();
  }

  /// Gets supported import file extensions
  static List<String> getSupportedExtensions() {
    return ['.csv', '.json'];
  }

  /// Gets import format description
  static String getFormatDescription(String extension) {
    switch (extension.toLowerCase()) {
      case '.csv':
        return 'CSV files (Generic, LastPass)';
      case '.json':
        return 'JSON files (Generic, Bitwarden)';
      default:
        return 'Unknown format';
    }
  }
}

/// Represents a duplicate account found during import
class ImportDuplicate {
  final Account imported;
  final Account existing;

  ImportDuplicate({required this.imported, required this.existing});
}

/// Exception thrown during import operations
class ImportException implements Exception {
  final String message;

  const ImportException(this.message);

  @override
  String toString() => 'ImportException: $message';
}
