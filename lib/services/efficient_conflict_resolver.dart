import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/vault_metadata.dart';

/// Efficient conflict resolution service with minimal data transfer
class EfficientConflictResolver {
  static EfficientConflictResolver? _instance;
  static EfficientConflictResolver get instance =>
      _instance ??= EfficientConflictResolver._();

  EfficientConflictResolver._();

  /// Resolve conflicts between local and remote data efficiently
  Future<ConflictResolutionResult> resolveConflicts({
    required List<Account> localAccounts,
    required List<Account> remoteAccounts,
    required VaultMetadata localVaultMetadata,
    required VaultMetadata remoteVaultMetadata,
    ConflictResolutionStrategy strategy =
        ConflictResolutionStrategy.lastWriterWins,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = ConflictResolutionResult();

      // Resolve vault metadata conflicts
      final vaultConflict = _resolveVaultConflict(
        localVaultMetadata,
        remoteVaultMetadata,
        strategy,
      );

      if (vaultConflict != null) {
        result.vaultConflicts.add(vaultConflict);
      }

      // Create lookup maps for efficient comparison
      final localAccountMap = {for (final acc in localAccounts) acc.id: acc};
      final remoteAccountMap = {for (final acc in remoteAccounts) acc.id: acc};

      // Find account conflicts
      final allAccountIds = {
        ...localAccountMap.keys,
        ...remoteAccountMap.keys,
      }.where((id) => id != null).cast<int>().toSet();

      for (final accountId in allAccountIds) {
        final localAccount = localAccountMap[accountId];
        final remoteAccount = remoteAccountMap[accountId];

        final conflict = _resolveAccountConflict(
          localAccount,
          remoteAccount,
          strategy,
        );

        if (conflict != null) {
          result.accountConflicts.add(conflict);
        }
      }

      if (kDebugMode) {
        print(
          'Conflict resolution completed in ${stopwatch.elapsedMilliseconds}ms',
        );
        print('Vault conflicts: ${result.vaultConflicts.length}');
        print('Account conflicts: ${result.accountConflicts.length}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('Error resolving conflicts: $e');
      }
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Resolve vault metadata conflict
  VaultConflict? _resolveVaultConflict(
    VaultMetadata local,
    VaultMetadata remote,
    ConflictResolutionStrategy strategy,
  ) {
    // Check if there's actually a conflict
    if (!_hasVaultConflict(local, remote)) {
      return null;
    }

    VaultMetadata resolved;
    ConflictResolution resolution;

    switch (strategy) {
      case ConflictResolutionStrategy.lastWriterWins:
        if (local.lastAccessedAt.isAfter(remote.lastAccessedAt)) {
          resolved = local;
          resolution = ConflictResolution.useLocal;
        } else {
          resolved = remote;
          resolution = ConflictResolution.useRemote;
        }
        break;

      case ConflictResolutionStrategy.localWins:
        resolved = local;
        resolution = ConflictResolution.useLocal;
        break;

      case ConflictResolutionStrategy.remoteWins:
        resolved = remote;
        resolution = ConflictResolution.useRemote;
        break;

      case ConflictResolutionStrategy.merge:
        resolved = _mergeVaultMetadata(local, remote);
        resolution = ConflictResolution.merged;
        break;

      case ConflictResolutionStrategy.userChoice:
        resolved = local; // Default to local, user will decide
        resolution = ConflictResolution.userChoice;
        break;
    }

    return VaultConflict(
      localVault: local,
      remoteVault: remote,
      resolvedVault: resolved,
      resolution: resolution,
      conflictFields: _getVaultConflictFields(local, remote),
    );
  }

  /// Resolve account conflict
  AccountConflict? _resolveAccountConflict(
    Account? local,
    Account? remote,
    ConflictResolutionStrategy strategy,
  ) {
    // Handle creation/deletion conflicts
    if (local == null && remote != null) {
      return AccountConflict(
        localAccount: null,
        remoteAccount: remote,
        resolvedAccount: remote,
        resolution: ConflictResolution.useRemote,
        conflictType: AccountConflictType.remoteCreated,
        conflictFields: [],
      );
    }

    if (local != null && remote == null) {
      return AccountConflict(
        localAccount: local,
        remoteAccount: null,
        resolvedAccount: local,
        resolution: ConflictResolution.useLocal,
        conflictType: AccountConflictType.localCreated,
        conflictFields: [],
      );
    }

    if (local == null || remote == null) {
      return null;
    }

    // Check if there's actually a conflict
    if (!_hasAccountConflict(local, remote)) {
      return null;
    }

    Account resolved;
    ConflictResolution resolution;

    switch (strategy) {
      case ConflictResolutionStrategy.lastWriterWins:
        final localModified =
            local.modifiedAt ?? local.createdAt ?? DateTime(1970);
        final remoteModified =
            remote.modifiedAt ?? remote.createdAt ?? DateTime(1970);

        if (localModified.isAfter(remoteModified)) {
          resolved = local;
          resolution = ConflictResolution.useLocal;
        } else {
          resolved = remote;
          resolution = ConflictResolution.useRemote;
        }
        break;

      case ConflictResolutionStrategy.localWins:
        resolved = local;
        resolution = ConflictResolution.useLocal;
        break;

      case ConflictResolutionStrategy.remoteWins:
        resolved = remote;
        resolution = ConflictResolution.useRemote;
        break;

      case ConflictResolutionStrategy.merge:
        resolved = _mergeAccounts(local, remote);
        resolution = ConflictResolution.merged;
        break;

      case ConflictResolutionStrategy.userChoice:
        resolved = local; // Default to local, user will decide
        resolution = ConflictResolution.userChoice;
        break;
    }

    return AccountConflict(
      localAccount: local,
      remoteAccount: remote,
      resolvedAccount: resolved,
      resolution: resolution,
      conflictType: AccountConflictType.modified,
      conflictFields: _getAccountConflictFields(local, remote),
    );
  }

  /// Check if vault metadata has conflicts
  bool _hasVaultConflict(VaultMetadata local, VaultMetadata remote) {
    return local.name != remote.name ||
        local.iconName != remote.iconName ||
        local.color != remote.color ||
        local.passwordCount != remote.passwordCount ||
        local.securityScore != remote.securityScore;
  }

  /// Check if account has conflicts
  bool _hasAccountConflict(Account local, Account remote) {
    return local.name != remote.name ||
        local.username != remote.username ||
        local.password != remote.password ||
        local.url != remote.url ||
        local.notes != remote.notes ||
        _totpConfigsDiffer(local.totpConfig, remote.totpConfig);
  }

  /// Check if TOTP configurations differ
  bool _totpConfigsDiffer(dynamic local, dynamic remote) {
    if (local == null && remote == null) return false;
    if (local == null || remote == null) return true;

    // Compare TOTP configurations
    return local.toString() != remote.toString();
  }

  /// Get conflicting fields for vault metadata
  List<String> _getVaultConflictFields(
    VaultMetadata local,
    VaultMetadata remote,
  ) {
    final conflicts = <String>[];

    if (local.name != remote.name) conflicts.add('name');
    if (local.iconName != remote.iconName) conflicts.add('iconName');
    if (local.color != remote.color) conflicts.add('color');
    if (local.passwordCount != remote.passwordCount)
      conflicts.add('passwordCount');
    if (local.securityScore != remote.securityScore)
      conflicts.add('securityScore');

    return conflicts;
  }

  /// Get conflicting fields for account
  List<String> _getAccountConflictFields(Account local, Account remote) {
    final conflicts = <String>[];

    if (local.name != remote.name) conflicts.add('name');
    if (local.username != remote.username) conflicts.add('username');
    if (local.password != remote.password) conflicts.add('password');
    if (local.url != remote.url) conflicts.add('url');
    if (local.notes != remote.notes) conflicts.add('notes');
    if (_totpConfigsDiffer(local.totpConfig, remote.totpConfig))
      conflicts.add('totpConfig');

    return conflicts;
  }

  /// Merge vault metadata intelligently
  VaultMetadata _mergeVaultMetadata(VaultMetadata local, VaultMetadata remote) {
    return VaultMetadata(
      id: local.id,
      name: local.lastAccessedAt.isAfter(remote.lastAccessedAt)
          ? local.name
          : remote.name,
      iconName: local.lastAccessedAt.isAfter(remote.lastAccessedAt)
          ? local.iconName
          : remote.iconName,
      color: local.lastAccessedAt.isAfter(remote.lastAccessedAt)
          ? local.color
          : remote.color,
      createdAt: local.createdAt.isBefore(remote.createdAt)
          ? local.createdAt
          : remote.createdAt,
      lastAccessedAt: local.lastAccessedAt.isAfter(remote.lastAccessedAt)
          ? local.lastAccessedAt
          : remote.lastAccessedAt,
      passwordCount: local.passwordCount > remote.passwordCount
          ? local.passwordCount
          : remote.passwordCount,
      securityScore:
          (local.securityScore + remote.securityScore) /
          2, // Average security scores
    );
  }

  /// Merge accounts intelligently
  Account _mergeAccounts(Account local, Account remote) {
    final localModified = local.modifiedAt ?? local.createdAt ?? DateTime(1970);
    final remoteModified =
        remote.modifiedAt ?? remote.createdAt ?? DateTime(1970);
    final useLocal = localModified.isAfter(remoteModified);

    return Account(
      id: local.id,
      name: useLocal ? local.name : remote.name,
      username: useLocal ? local.username : remote.username,
      password: useLocal ? local.password : remote.password,
      url: useLocal ? local.url : remote.url,
      notes: useLocal ? local.notes : remote.notes,
      vaultId: local.vaultId,
      createdAt:
          local.createdAt?.isBefore(remote.createdAt ?? DateTime.now()) == true
          ? local.createdAt
          : remote.createdAt,
      modifiedAt: useLocal ? local.modifiedAt : remote.modifiedAt,
      lastUsedAt: _getLatestDate(local.lastUsedAt, remote.lastUsedAt),
      totpConfig: useLocal ? local.totpConfig : remote.totpConfig,
    );
  }

  /// Get the latest of two dates
  DateTime? _getLatestDate(DateTime? date1, DateTime? date2) {
    if (date1 == null) return date2;
    if (date2 == null) return date1;
    return date1.isAfter(date2) ? date1 : date2;
  }

  /// Create minimal conflict resolution payload
  ConflictResolutionPayload createResolutionPayload(
    ConflictResolutionResult result,
  ) {
    return ConflictResolutionPayload(
      vaultResolutions: result.vaultConflicts
          .map(
            (c) => VaultResolution(
              vaultId: c.localVault?.id ?? c.remoteVault!.id,
              resolution: c.resolution,
              resolvedData: c.resolution != ConflictResolution.userChoice
                  ? c.resolvedVault.toMap()
                  : null,
            ),
          )
          .toList(),
      accountResolutions: result.accountConflicts
          .map(
            (c) => AccountResolution(
              accountId: c.localAccount?.id ?? c.remoteAccount!.id!,
              resolution: c.resolution,
              resolvedData: c.resolution != ConflictResolution.userChoice
                  ? c.resolvedAccount.toMap()
                  : null,
            ),
          )
          .toList(),
    );
  }

  /// Get conflict resolution statistics
  Map<String, dynamic> getConflictStats(ConflictResolutionResult result) {
    return {
      'totalConflicts':
          result.vaultConflicts.length + result.accountConflicts.length,
      'vaultConflicts': result.vaultConflicts.length,
      'accountConflicts': result.accountConflicts.length,
      'autoResolved':
          result.vaultConflicts
              .where((c) => c.resolution != ConflictResolution.userChoice)
              .length +
          result.accountConflicts
              .where((c) => c.resolution != ConflictResolution.userChoice)
              .length,
      'requiresUserInput':
          result.vaultConflicts
              .where((c) => c.resolution == ConflictResolution.userChoice)
              .length +
          result.accountConflicts
              .where((c) => c.resolution == ConflictResolution.userChoice)
              .length,
    };
  }
}

/// Result of conflict resolution
class ConflictResolutionResult {
  final List<VaultConflict> vaultConflicts = [];
  final List<AccountConflict> accountConflicts = [];

  bool get hasConflicts =>
      vaultConflicts.isNotEmpty || accountConflicts.isNotEmpty;
  bool get requiresUserInput =>
      vaultConflicts.any(
        (c) => c.resolution == ConflictResolution.userChoice,
      ) ||
      accountConflicts.any(
        (c) => c.resolution == ConflictResolution.userChoice,
      );
}

/// Vault conflict information
class VaultConflict {
  final VaultMetadata? localVault;
  final VaultMetadata? remoteVault;
  final VaultMetadata resolvedVault;
  final ConflictResolution resolution;
  final List<String> conflictFields;

  const VaultConflict({
    required this.localVault,
    required this.remoteVault,
    required this.resolvedVault,
    required this.resolution,
    required this.conflictFields,
  });
}

/// Account conflict information
class AccountConflict {
  final Account? localAccount;
  final Account? remoteAccount;
  final Account resolvedAccount;
  final ConflictResolution resolution;
  final AccountConflictType conflictType;
  final List<String> conflictFields;

  const AccountConflict({
    required this.localAccount,
    required this.remoteAccount,
    required this.resolvedAccount,
    required this.resolution,
    required this.conflictType,
    required this.conflictFields,
  });
}

/// Minimal conflict resolution payload
class ConflictResolutionPayload {
  final List<VaultResolution> vaultResolutions;
  final List<AccountResolution> accountResolutions;

  const ConflictResolutionPayload({
    required this.vaultResolutions,
    required this.accountResolutions,
  });
}

/// Vault resolution
class VaultResolution {
  final String vaultId;
  final ConflictResolution resolution;
  final Map<String, dynamic>? resolvedData;

  const VaultResolution({
    required this.vaultId,
    required this.resolution,
    this.resolvedData,
  });
}

/// Account resolution
class AccountResolution {
  final int accountId;
  final ConflictResolution resolution;
  final Map<String, dynamic>? resolvedData;

  const AccountResolution({
    required this.accountId,
    required this.resolution,
    this.resolvedData,
  });
}

/// Conflict resolution strategies
enum ConflictResolutionStrategy {
  lastWriterWins,
  localWins,
  remoteWins,
  merge,
  userChoice,
}

/// Conflict resolution types
enum ConflictResolution { useLocal, useRemote, merged, userChoice }

/// Account conflict types
enum AccountConflictType {
  modified,
  localCreated,
  remoteCreated,
  localDeleted,
  remoteDeleted,
}
