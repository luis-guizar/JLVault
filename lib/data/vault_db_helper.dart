import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/vault_metadata.dart';

/// Database helper for vault metadata operations
class VaultDbHelper {
  static Database? _db;
  static const String _vaultTable = 'vault_metadata';
  static const String _settingsTable = 'vault_settings';

  /// Initialize the vault database
  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vaults.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create vault metadata table
        await db.execute('''
          CREATE TABLE $_vaultTable(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            icon_name TEXT NOT NULL,
            color INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            last_accessed_at INTEGER NOT NULL,
            password_count INTEGER NOT NULL DEFAULT 0,
            security_score REAL NOT NULL DEFAULT 100.0,
            is_default INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // Create settings table for storing active vault and other settings
        await db.execute('''
          CREATE TABLE $_settingsTable(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        // Create indexes for better performance
        await db.execute('CREATE INDEX idx_vault_name ON $_vaultTable(name)');
        await db.execute(
          'CREATE INDEX idx_vault_last_accessed ON $_vaultTable(last_accessed_at)',
        );
      },
    );
  }

  /// Get database instance
  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Insert a new vault
  static Future<void> insertVault(VaultMetadata vault) async {
    final dbClient = await db;
    await dbClient.insert(
      _vaultTable,
      vault.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all vaults ordered by last accessed time
  static Future<List<VaultMetadata>> getAllVaults() async {
    final dbClient = await db;
    final result = await dbClient.query(
      _vaultTable,
      orderBy: 'last_accessed_at DESC',
    );

    return result.map((map) => VaultMetadata.fromMap(map)).toList();
  }

  /// Get vault by ID
  static Future<VaultMetadata?> getVaultById(String vaultId) async {
    final dbClient = await db;
    final result = await dbClient.query(
      _vaultTable,
      where: 'id = ?',
      whereArgs: [vaultId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return VaultMetadata.fromMap(result.first);
  }

  /// Update vault metadata
  static Future<void> updateVault(VaultMetadata vault) async {
    final dbClient = await db;
    await dbClient.update(
      _vaultTable,
      vault.toMap(),
      where: 'id = ?',
      whereArgs: [vault.id],
    );
  }

  /// Delete vault and all associated data
  static Future<void> deleteVault(String vaultId) async {
    final dbClient = await db;

    // Start transaction to ensure data consistency
    await dbClient.transaction((txn) async {
      // Delete vault metadata
      await txn.delete(_vaultTable, where: 'id = ?', whereArgs: [vaultId]);

      // Delete all accounts in this vault
      await txn.delete(
        'accounts', // Reference to accounts table from db_helper.dart
        where: 'vault_id = ?',
        whereArgs: [vaultId],
      );
    });
  }

  /// Get the active vault ID
  static Future<String?> getActiveVaultId() async {
    final dbClient = await db;
    final result = await dbClient.query(
      _settingsTable,
      where: 'key = ?',
      whereArgs: ['active_vault_id'],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  /// Set the active vault ID
  static Future<void> setActiveVaultId(String vaultId) async {
    final dbClient = await db;
    await dbClient.insert(_settingsTable, {
      'key': 'active_vault_id',
      'value': vaultId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get vault count
  static Future<int> getVaultCount() async {
    final dbClient = await db;
    final result = await dbClient.rawQuery(
      'SELECT COUNT(*) as count FROM $_vaultTable',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Check if vault name exists
  static Future<bool> vaultNameExists(
    String name, {
    String? excludeVaultId,
  }) async {
    final dbClient = await db;

    String whereClause = 'LOWER(name) = LOWER(?)';
    List<dynamic> whereArgs = [name];

    if (excludeVaultId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeVaultId);
    }

    final result = await dbClient.query(
      _vaultTable,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Update vault statistics
  static Future<void> updateVaultStatistics(
    String vaultId, {
    int? passwordCount,
    double? securityScore,
  }) async {
    final vault = await getVaultById(vaultId);
    if (vault == null) return;

    final updatedVault = vault.copyWith(
      passwordCount: passwordCount ?? vault.passwordCount,
      securityScore: securityScore ?? vault.securityScore,
    );

    await updateVault(updatedVault);
  }

  /// Close database connection
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
