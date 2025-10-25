import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import '../models/account.dart';
import '../data/db_helper.dart';

/// High-performance search service with FTS support and caching
class SearchService {
  static SearchService? _instance;
  static SearchService get instance => _instance ??= SearchService._();

  SearchService._();

  // Search cache for improved performance
  final Map<String, List<Account>> _searchCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Debounce timer for search queries
  Timer? _debounceTimer;

  // Cache configuration
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const int _maxCacheSize = 100;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  /// Initialize FTS (Full-Text Search) tables
  Future<void> initializeFTS() async {
    try {
      final db = await DBHelper.db;

      // Create FTS virtual table for password search
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS accounts_fts USING fts5(
          id,
          name,
          username,
          vault_id,
          content='accounts',
          content_rowid='id'
        )
      ''');

      // Create triggers to keep FTS table in sync
      await _createFTSTriggers(db);

      // Populate FTS table with existing data
      await _populateFTSTable(db);

      if (kDebugMode) {
        print('FTS search initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing FTS: $e');
      }
      // FTS is optional - app should work without it
    }
  }

  /// Create triggers to keep FTS table synchronized
  Future<void> _createFTSTriggers(Database db) async {
    // Insert trigger
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS accounts_fts_insert AFTER INSERT ON accounts
      BEGIN
        INSERT INTO accounts_fts(id, name, username, vault_id)
        VALUES (new.id, new.name, new.username, new.vault_id);
      END
    ''');

    // Update trigger
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS accounts_fts_update AFTER UPDATE ON accounts
      BEGIN
        UPDATE accounts_fts SET
          name = new.name,
          username = new.username,
          vault_id = new.vault_id
        WHERE id = new.id;
      END
    ''');

    // Delete trigger
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS accounts_fts_delete AFTER DELETE ON accounts
      BEGIN
        DELETE FROM accounts_fts WHERE id = old.id;
      END
    ''');
  }

  /// Populate FTS table with existing data
  Future<void> _populateFTSTable(Database db) async {
    await db.execute('''
      INSERT OR REPLACE INTO accounts_fts(id, name, username, vault_id)
      SELECT id, name, username, vault_id FROM accounts
    ''');
  }

  /// Perform high-performance search with debouncing and caching
  Future<List<Account>> search(
    String query, {
    String? vaultId,
    int limit = 50,
    bool useCache = true,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final normalizedQuery = _normalizeQuery(query);
    final cacheKey = _getCacheKey(normalizedQuery, vaultId, limit);

    // Return cached results if available and not expired
    if (useCache && _isCacheValid(cacheKey)) {
      return _searchCache[cacheKey]!;
    }

    try {
      final stopwatch = Stopwatch()..start();

      // Try FTS search first (fastest)
      List<Account> results = await _performFTSSearch(
        normalizedQuery,
        vaultId: vaultId,
        limit: limit,
      );

      // Fallback to regular search if FTS fails or returns no results
      if (results.isEmpty) {
        results = await _performRegularSearch(
          normalizedQuery,
          vaultId: vaultId,
          limit: limit,
        );
      }

      // Cache the results
      if (useCache) {
        _cacheResults(cacheKey, results);
      }

      if (kDebugMode) {
        print(
          'Search completed in ${stopwatch.elapsedMilliseconds}ms for query: "$query"',
        );
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        print('Search error: $e');
      }
      return [];
    }
  }

  /// Perform FTS search for optimal performance
  Future<List<Account>> _performFTSSearch(
    String query, {
    String? vaultId,
    int limit = 50,
  }) async {
    try {
      final db = await DBHelper.db;

      // Build FTS query
      final ftsQuery = _buildFTSQuery(query);
      String sql = '''
        SELECT a.* FROM accounts a
        JOIN accounts_fts fts ON a.id = fts.id
        WHERE accounts_fts MATCH ?
      ''';

      List<dynamic> args = [ftsQuery];

      // Add vault filter if specified
      if (vaultId != null) {
        sql += ' AND a.vault_id = ?';
        args.add(vaultId);
      }

      sql += ' ORDER BY bm25(accounts_fts) LIMIT ?';
      args.add(limit);

      final result = await db.rawQuery(sql, args);
      return result.map((map) => Account.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('FTS search error: $e');
      }
      return [];
    }
  }

  /// Perform regular search as fallback
  Future<List<Account>> _performRegularSearch(
    String query, {
    String? vaultId,
    int limit = 50,
  }) async {
    final db = await DBHelper.db;

    String sql = '''
      SELECT * FROM accounts
      WHERE (name LIKE ? OR username LIKE ?)
    ''';

    List<dynamic> args = ['%$query%', '%$query%'];

    // Add vault filter if specified
    if (vaultId != null) {
      sql += ' AND vault_id = ?';
      args.add(vaultId);
    }

    sql += ' ORDER BY name LIMIT ?';
    args.add(limit);

    final result = await db.rawQuery(sql, args);
    return result.map((map) => Account.fromMap(map)).toList();
  }

  /// Build FTS query with proper escaping and operators
  String _buildFTSQuery(String query) {
    // Split query into terms and escape special characters
    final terms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .map((term) => '"${term.replaceAll('"', '""')}"')
        .toList();

    // Join terms with AND operator for better matching
    return terms.join(' AND ');
  }

  /// Normalize query for consistent caching and searching
  String _normalizeQuery(String query) {
    return query.trim().toLowerCase();
  }

  /// Generate cache key for search results
  String _getCacheKey(String query, String? vaultId, int limit) {
    return '${query}_${vaultId ?? 'all'}_$limit';
  }

  /// Check if cached results are still valid
  bool _isCacheValid(String cacheKey) {
    if (!_searchCache.containsKey(cacheKey)) return false;

    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Cache search results with size management
  void _cacheResults(String cacheKey, List<Account> results) {
    // Remove expired entries
    _cleanExpiredCache();

    // Remove oldest entries if cache is full
    if (_searchCache.length >= _maxCacheSize) {
      _removeOldestCacheEntry();
    }

    _searchCache[cacheKey] = results;
    _cacheTimestamps[cacheKey] = DateTime.now();
  }

  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) >= _cacheExpiry) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _searchCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Remove oldest cache entry to make room for new ones
  void _removeOldestCacheEntry() {
    if (_cacheTimestamps.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    _cacheTimestamps.forEach((key, timestamp) {
      if (oldestTime == null || timestamp.isBefore(oldestTime!)) {
        oldestKey = key;
        oldestTime = timestamp;
      }
    });

    if (oldestKey != null) {
      _searchCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  /// Debounced search for UI components
  Future<List<Account>> debouncedSearch(
    String query, {
    String? vaultId,
    int limit = 50,
    Duration? debounceDelay,
  }) async {
    final completer = Completer<List<Account>>();

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set new timer
    _debounceTimer = Timer(debounceDelay ?? _debounceDelay, () async {
      try {
        final results = await search(query, vaultId: vaultId, limit: limit);
        if (!completer.isCompleted) {
          completer.complete(results);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  /// Clear search cache
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get search performance statistics
  Map<String, dynamic> getStats() {
    return {
      'cacheSize': _searchCache.length,
      'maxCacheSize': _maxCacheSize,
      'cacheExpiry': _cacheExpiry.inMinutes,
      'debounceDelay': _debounceDelay.inMilliseconds,
    };
  }

  /// Rebuild FTS index (useful for maintenance)
  Future<void> rebuildFTSIndex() async {
    try {
      final db = await DBHelper.db;

      // Rebuild the FTS index
      await db.execute(
        'INSERT INTO accounts_fts(accounts_fts) VALUES("rebuild")',
      );

      if (kDebugMode) {
        print('FTS index rebuilt successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error rebuilding FTS index: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    clearCache();
  }
}
