import '../../models/import_result.dart';
import '../../models/account.dart';

/// Service for detecting and handling duplicate accounts during import
class DuplicateDetector {
  /// Detects duplicates between imported accounts and existing accounts
  static List<ImportDuplicate> detectDuplicates(
    List<ImportedAccount> importedAccounts,
    List<Account> existingAccounts,
  ) {
    final duplicates = <ImportDuplicate>[];

    for (final imported in importedAccounts) {
      final duplicate = _findBestMatch(imported, existingAccounts);
      if (duplicate != null) {
        duplicates.add(duplicate);
      }
    }

    return duplicates;
  }

  /// Finds the best matching existing account for an imported account
  static ImportDuplicate? _findBestMatch(
    ImportedAccount imported,
    List<Account> existingAccounts,
  ) {
    ImportDuplicate? bestMatch;
    double highestConfidence = 0.0;

    for (final existing in existingAccounts) {
      final match = _checkForMatch(imported, existing);
      if (match != null && match.confidence > highestConfidence) {
        bestMatch = match;
        highestConfidence = match.confidence;
      }
    }

    // Only return matches with confidence above threshold
    return bestMatch != null && bestMatch.confidence >= 0.6 ? bestMatch : null;
  }

  /// Checks if imported account matches existing account
  static ImportDuplicate? _checkForMatch(
    ImportedAccount imported,
    Account existing,
  ) {
    // Exact match (title, username, password)
    if (_normalizeString(imported.title) == _normalizeString(existing.name) &&
        _normalizeString(imported.username) ==
            _normalizeString(existing.username) &&
        imported.password == existing.password) {
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.exact,
        confidence: 1.0,
      );
    }

    // Title and username match (high confidence)
    if (_normalizeString(imported.title) == _normalizeString(existing.name) &&
        _normalizeString(imported.username) ==
            _normalizeString(existing.username)) {
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.titleAndUsername,
        confidence: 0.9,
      );
    }

    // Username and URL match
    if (_normalizeString(imported.username) ==
            _normalizeString(existing.username) &&
        imported.url != null &&
        imported.url!.isNotEmpty) {
      final urlMatch = _checkUrlMatch(imported.url!, existing.name);
      if (urlMatch > 0.7) {
        return ImportDuplicate(
          imported: imported,
          existingAccountId: existing.id.toString(),
          matchType: DuplicateMatchType.usernameAndUrl,
          confidence: 0.8 * urlMatch,
        );
      }
    }

    // Title only match (medium confidence)
    if (_normalizeString(imported.title) == _normalizeString(existing.name) &&
        imported.title.trim().isNotEmpty) {
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.titleOnly,
        confidence: 0.7,
      );
    }

    // Fuzzy matching for similar titles and usernames
    final titleSimilarity = _calculateStringSimilarity(
      imported.title,
      existing.name,
    );
    final usernameSimilarity = _calculateStringSimilarity(
      imported.username,
      existing.username,
    );

    if (titleSimilarity > 0.8 && usernameSimilarity > 0.8) {
      final combinedConfidence = (titleSimilarity + usernameSimilarity) / 2;
      return ImportDuplicate(
        imported: imported,
        existingAccountId: existing.id.toString(),
        matchType: DuplicateMatchType.fuzzy,
        confidence:
            combinedConfidence * 0.8, // Reduce confidence for fuzzy matches
      );
    }

    return null;
  }

  /// Normalizes string for comparison
  static String _normalizeString(String input) {
    return input.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Checks URL match between imported URL and existing account name
  static double _checkUrlMatch(String importedUrl, String existingName) {
    try {
      final uri = Uri.parse(importedUrl);
      final domain = uri.host.toLowerCase();
      final normalizedName = _normalizeString(existingName);

      // Direct domain match
      if (normalizedName.contains(domain)) {
        return 1.0;
      }

      // Remove www. and check again
      final cleanDomain = domain.startsWith('www.')
          ? domain.substring(4)
          : domain;
      if (normalizedName.contains(cleanDomain)) {
        return 0.9;
      }

      // Check if domain parts are in the name
      final domainParts = cleanDomain.split('.');
      if (domainParts.isNotEmpty) {
        final mainDomain = domainParts[0];
        if (normalizedName.contains(mainDomain)) {
          return 0.8;
        }
      }

      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Calculates string similarity using Levenshtein distance
  static double _calculateStringSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final normalizedA = _normalizeString(a);
    final normalizedB = _normalizeString(b);

    if (normalizedA == normalizedB) return 1.0;

    final distance = _levenshteinDistance(normalizedA, normalizedB);
    final maxLength = normalizedA.length > normalizedB.length
        ? normalizedA.length
        : normalizedB.length;

    return 1.0 - (distance / maxLength);
  }

  /// Calculates Levenshtein distance between two strings
  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    // Initialize first row and column
    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    // Fill the matrix
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[a.length][b.length];
  }

  /// Groups duplicates by existing account for easier handling
  static Map<String, List<ImportDuplicate>> groupDuplicatesByExisting(
    List<ImportDuplicate> duplicates,
  ) {
    final grouped = <String, List<ImportDuplicate>>{};

    for (final duplicate in duplicates) {
      final existingId = duplicate.existingAccountId;
      if (!grouped.containsKey(existingId)) {
        grouped[existingId] = [];
      }
      grouped[existingId]!.add(duplicate);
    }

    return grouped;
  }

  /// Filters out imported accounts that are duplicates
  static List<ImportedAccount> filterDuplicates(
    List<ImportedAccount> importedAccounts,
    List<ImportDuplicate> duplicates,
  ) {
    final duplicateImported = duplicates.map((d) => d.imported).toSet();
    return importedAccounts
        .where((account) => !duplicateImported.contains(account))
        .toList();
  }

  /// Creates merge suggestions for duplicate resolution
  static List<MergeSuggestion> createMergeSuggestions(
    List<ImportDuplicate> duplicates,
    List<Account> existingAccounts,
  ) {
    final suggestions = <MergeSuggestion>[];

    for (final duplicate in duplicates) {
      final existing = existingAccounts.firstWhere(
        (account) => account.id.toString() == duplicate.existingAccountId,
        orElse: () => throw StateError('Existing account not found'),
      );

      suggestions.add(
        MergeSuggestion(
          duplicate: duplicate,
          existingAccount: existing,
          recommendedAction: _getRecommendedAction(duplicate),
          conflicts: _identifyConflicts(duplicate.imported, existing),
        ),
      );
    }

    return suggestions;
  }

  /// Gets recommended action for duplicate resolution
  static MergeAction _getRecommendedAction(ImportDuplicate duplicate) {
    switch (duplicate.matchType) {
      case DuplicateMatchType.exact:
        return MergeAction.skip; // Exact match, no need to import
      case DuplicateMatchType.titleAndUsername:
        return MergeAction.updatePassword; // Likely password change
      case DuplicateMatchType.titleOnly:
      case DuplicateMatchType.usernameAndUrl:
        return MergeAction.merge; // Merge additional data
      case DuplicateMatchType.fuzzy:
        return MergeAction.askUser; // Let user decide
    }
  }

  /// Identifies conflicts between imported and existing accounts
  static List<MergeConflict> _identifyConflicts(
    ImportedAccount imported,
    Account existing,
  ) {
    final conflicts = <MergeConflict>[];

    // Password conflict
    if (imported.password != existing.password) {
      conflicts.add(
        MergeConflict(
          field: 'password',
          importedValue: imported.password,
          existingValue: existing.password,
          conflictType: MergeConflictType.different,
        ),
      );
    }

    // Title conflict
    if (_normalizeString(imported.title) != _normalizeString(existing.name)) {
      conflicts.add(
        MergeConflict(
          field: 'title',
          importedValue: imported.title,
          existingValue: existing.name,
          conflictType: MergeConflictType.different,
        ),
      );
    }

    // Username conflict
    if (_normalizeString(imported.username) !=
        _normalizeString(existing.username)) {
      conflicts.add(
        MergeConflict(
          field: 'username',
          importedValue: imported.username,
          existingValue: existing.username,
          conflictType: MergeConflictType.different,
        ),
      );
    }

    // URL conflict (if existing account had URL stored in notes or elsewhere)
    if (imported.url != null && imported.url!.isNotEmpty) {
      conflicts.add(
        MergeConflict(
          field: 'url',
          importedValue: imported.url!,
          existingValue: '', // Existing accounts don't have URL field
          conflictType: MergeConflictType.newData,
        ),
      );
    }

    // Notes conflict
    if (imported.notes != null && imported.notes!.isNotEmpty) {
      conflicts.add(
        MergeConflict(
          field: 'notes',
          importedValue: imported.notes!,
          existingValue: '', // Existing accounts don't have notes field
          conflictType: MergeConflictType.newData,
        ),
      );
    }

    // TOTP conflict
    if (imported.totpData != null && existing.totpConfig == null) {
      conflicts.add(
        MergeConflict(
          field: 'totp',
          importedValue: 'TOTP Configuration',
          existingValue: 'None',
          conflictType: MergeConflictType.newData,
        ),
      );
    }

    return conflicts;
  }
}

/// Represents a merge suggestion for duplicate resolution
class MergeSuggestion {
  final ImportDuplicate duplicate;
  final Account existingAccount;
  final MergeAction recommendedAction;
  final List<MergeConflict> conflicts;

  MergeSuggestion({
    required this.duplicate,
    required this.existingAccount,
    required this.recommendedAction,
    required this.conflicts,
  });
}

/// Possible actions for resolving duplicates
enum MergeAction {
  skip, // Skip importing (exact duplicate)
  replace, // Replace existing with imported
  merge, // Merge data from both
  updatePassword, // Update only password
  askUser, // Let user decide
}

/// Represents a conflict between imported and existing data
class MergeConflict {
  final String field;
  final String importedValue;
  final String existingValue;
  final MergeConflictType conflictType;

  MergeConflict({
    required this.field,
    required this.importedValue,
    required this.existingValue,
    required this.conflictType,
  });
}

/// Types of merge conflicts
enum MergeConflictType {
  different, // Values are different
  newData, // Imported has data, existing doesn't
  missing, // Existing has data, imported doesn't
}
