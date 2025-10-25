import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account.dart';

class DBHelper {
  static Database? _db;
  static const String _table = 'accounts';

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'passwords.db');

    return openDatabase(
      path,
      version: 4, // Increment version for search optimization
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            username TEXT,
            password TEXT,
            url TEXT,
            notes TEXT,
            vault_id TEXT NOT NULL DEFAULT 'default',
            created_at INTEGER,
            modified_at INTEGER,
            last_used_at INTEGER,
            totp_config TEXT
          )
        ''');

        // Create indexes for better search performance
        await db.execute(
          'CREATE INDEX idx_accounts_vault_id ON $_table(vault_id)',
        );
        await db.execute('CREATE INDEX idx_accounts_name ON $_table(name)');
        await db.execute(
          'CREATE INDEX idx_accounts_username ON $_table(username)',
        );
        await db.execute(
          'CREATE INDEX idx_accounts_last_used ON $_table(last_used_at)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add new columns for existing installations
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN vault_id TEXT NOT NULL DEFAULT "default"',
          );
          await db.execute('ALTER TABLE $_table ADD COLUMN created_at INTEGER');
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN modified_at INTEGER',
          );
          await db.execute(
            'CREATE INDEX idx_accounts_vault_id ON $_table(vault_id)',
          );
        }
        if (oldVersion < 3) {
          // Add TOTP configuration column
          await db.execute('ALTER TABLE $_table ADD COLUMN totp_config TEXT');
        }
        if (oldVersion < 4) {
          // Add search optimization columns
          await db.execute('ALTER TABLE $_table ADD COLUMN url TEXT');
          await db.execute('ALTER TABLE $_table ADD COLUMN notes TEXT');
          await db.execute(
            'ALTER TABLE $_table ADD COLUMN last_used_at INTEGER',
          );

          // Add search performance indexes
          await db.execute('CREATE INDEX idx_accounts_name ON $_table(name)');
          await db.execute(
            'CREATE INDEX idx_accounts_username ON $_table(username)',
          );
          await db.execute(
            'CREATE INDEX idx_accounts_last_used ON $_table(last_used_at)',
          );
        }
      },
    );
  }

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<int> insert(Account acc) async {
    final dbClient = await db;
    final accountWithTimestamps = acc.copyWith(
      createdAt: acc.createdAt ?? DateTime.now(),
      modifiedAt: acc.modifiedAt ?? DateTime.now(),
    );
    return dbClient.insert(_table, accountWithTimestamps.toMap());
  }

  static Future<List<Account>> getAll() async {
    final dbClient = await db;
    final res = await dbClient.query(_table, orderBy: 'name');
    return res.map((e) => Account.fromMap(e)).toList();
  }

  /// Get all accounts for a specific vault
  static Future<List<Account>> getAllForVault(String vaultId) async {
    final dbClient = await db;
    final res = await dbClient.query(
      _table,
      where: 'vault_id = ?',
      whereArgs: [vaultId],
      orderBy: 'name',
    );
    return res.map((e) => Account.fromMap(e)).toList();
  }

  /// Get account count for a specific vault
  static Future<int> getAccountCountForVault(String vaultId) async {
    final dbClient = await db;
    final result = await dbClient.rawQuery(
      'SELECT COUNT(*) as count FROM $_table WHERE vault_id = ?',
      [vaultId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<int> update(Account acc) async {
    final dbClient = await db;
    final accountWithModified = acc.copyWith(modifiedAt: DateTime.now());
    return dbClient.update(
      _table,
      accountWithModified.toMap(),
      where: 'id = ?',
      whereArgs: [acc.id],
    );
  }

  static Future<int> delete(int id) async {
    final dbClient = await db;
    return dbClient.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all accounts for a specific vault
  static Future<int> deleteAllForVault(String vaultId) async {
    final dbClient = await db;
    return dbClient.delete(_table, where: 'vault_id = ?', whereArgs: [vaultId]);
  }

  /// Move accounts from one vault to another
  static Future<void> moveAccountsToVault(
    List<int> accountIds,
    String targetVaultId,
  ) async {
    final dbClient = await db;
    final batch = dbClient.batch();

    for (final accountId in accountIds) {
      batch.update(
        _table,
        {
          'vault_id': targetVaultId,
          'modified_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [accountId],
      );
    }

    await batch.commit();
  }
}
