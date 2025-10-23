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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            username TEXT,
            password TEXT
          )
        ''');
      },
    );
  }

  static Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<int> insert(Account acc) async {
    final dbClient = await db;
    return dbClient.insert(_table, acc.toMap());
  }

  static Future<List<Account>> getAll() async {
    final dbClient = await db;
    final res = await dbClient.query(_table, orderBy: 'name');
    return res.map((e) => Account.fromMap(e)).toList();
  }

  static Future<int> update(Account acc) async {
    final dbClient = await db;
    return dbClient.update(
      _table,
      acc.toMap(),
      where: 'id = ?',
      whereArgs: [acc.id],
    );
  }

  static Future<int> delete(int id) async {
    final dbClient = await db;
    return dbClient.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
