import 'dart:async';
import 'dart:convert';
import '../models/sync_protocol.dart';

/// Service for resolving sync conflicts between devices
class SyncConflictResolver {
  final Map<String, ConflictResolutionStrategy> _strategies = {};
  final StreamController<ConflictResolutionEvent> _eventController =
      StreamController<ConflictResolutionEvent>.broadcast();

  SyncConflictResolver() {
    _initializeDefaultStrategies();
  }

  /// Stream of conflict resolution events
  Stream<ConflictResolutionEvent> get eventStream => _eventController.stream;

  /// Resolve a list of sync conflicts
  Future<ConflictResolutionResult> resolveConflicts({
    required List<SyncConflict> conflicts,
    required String vaultId,
    ConflictResolutionStrategy? defaultStrategy,
  }) async {
    final resolvedEntries = <String, ResolvedConflict>{};
    final unresolvedConflicts = <SyncConflict>[];
    final strategy = defaultStrategy ?? _strategies['lastWriterWins']!;

    for (final conflict in conflicts) {
      try {
        final resolution = await _resolveConflict(conflict, strategy);

        if (resolution.requiresUserInput) {
          unresolvedConflicts.add(conflict);
        } else {
          resolvedEntries[conflict.entryId] = resolution;
          _notifyEvent(
            ConflictResolutionEvent.resolved(
              conflict: conflict,
              resolution: resolution,
            ),
          );
        }
      } catch (e) {
        unresolvedConflicts.add(conflict);
        _notifyEvent(
          ConflictResolutionEvent.error(
            conflict: conflict,
            error: e.toString(),
          ),
        );
      }
    }

    return ConflictResolutionResult(
      resolvedConflicts: resolvedEntries,
      unresolvedConflicts: unresolvedConflicts,
      totalConflicts: conflicts.length,
    );
  }

  /// Resolve a single conflict with user input
  Future<ResolvedConflict> resolveConflictWithUserChoice({
    required SyncConflict conflict,
    required ConflictResolution userChoice,
    Map<String, dynamic>? mergedData,
  }) async {
    final strategy = _strategies['userChoice']!;

    final resolution = await strategy.resolve(
      conflict,
      userChoice: userChoice,
      mergedData: mergedData,
    );

    _notifyEvent(
      ConflictResolutionEvent.resolved(
        conflict: conflict,
        resolution: resolution,
      ),
    );

    return resolution;
  }

  /// Set conflict resolution strategy for a specific conflict type
  void setStrategy(
    ConflictType conflictType,
    ConflictResolutionStrategy strategy,
  ) {
    _strategies[conflictType.toString()] = strategy;
  }

  /// Get available resolution options for a conflict
  List<ConflictResolution> getResolutionOptions(SyncConflict conflict) {
    switch (conflict.type) {
      case ConflictType.updateUpdate:
        return [
          ConflictResolution.useLocal,
          ConflictResolution.useRemote,
          ConflictResolution.merge,
          ConflictResolution.lastWriterWins,
        ];
      case ConflictType.updateDelete:
        return [ConflictResolution.useLocal, ConflictResolution.useRemote];
      case ConflictType.deleteUpdate:
        return [ConflictResolution.useLocal, ConflictResolution.useRemote];
      case ConflictType.createCreate:
        return [
          ConflictResolution.useLocal,
          ConflictResolution.useRemote,
          ConflictResolution.merge,
        ];
    }
  }

  /// Check if conflicts can be automatically resolved
  bool canAutoResolve(List<SyncConflict> conflicts) {
    return conflicts.every(
      (conflict) =>
          conflict.suggestedResolution != ConflictResolution.userChoice,
    );
  }

  /// Get conflict summary for display
  ConflictSummary getConflictSummary(List<SyncConflict> conflicts) {
    final summary = ConflictSummary();

    for (final conflict in conflicts) {
      switch (conflict.type) {
        case ConflictType.updateUpdate:
          summary.updateUpdateCount++;
          break;
        case ConflictType.updateDelete:
          summary.updateDeleteCount++;
          break;
        case ConflictType.deleteUpdate:
          summary.deleteUpdateCount++;
          break;
        case ConflictType.createCreate:
          summary.createCreateCount++;
          break;
      }
    }

    return summary;
  }

  Future<ResolvedConflict> _resolveConflict(
    SyncConflict conflict,
    ConflictResolutionStrategy strategy,
  ) async {
    return await strategy.resolve(conflict);
  }

  void _initializeDefaultStrategies() {
    _strategies['lastWriterWins'] = LastWriterWinsStrategy();
    _strategies['useLocal'] = UseLocalStrategy();
    _strategies['useRemote'] = UseRemoteStrategy();
    _strategies['merge'] = MergeStrategy();
    _strategies['userChoice'] = UserChoiceStrategy();
  }

  void _notifyEvent(ConflictResolutionEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _eventController.close();
  }
}

/// Abstract base class for conflict resolution strategies
abstract class ConflictResolutionStrategy {
  Future<ResolvedConflict> resolve(
    SyncConflict conflict, {
    ConflictResolution? userChoice,
    Map<String, dynamic>? mergedData,
  });
}

/// Strategy that uses the most recently modified entry
class LastWriterWinsStrategy extends ConflictResolutionStrategy {
  @override
  Future<ResolvedConflict> resolve(
    SyncConflict conflict, {
    ConflictResolution? userChoice,
    Map<String, dynamic>? mergedData,
  }) async {
    final useLocal = conflict.localEntry.timestamp.isAfter(
      conflict.remoteEntry.timestamp,
    );

    return ResolvedConflict(
      entryId: conflict.entryId,
      resolution: useLocal
          ? ConflictResolution.useLocal
          : ConflictResolution.useRemote,
      resolvedEntry: useLocal ? conflict.localEntry : conflict.remoteEntry,
      requiresUserInput: false,
      metadata: {
        'strategy': 'lastWriterWins',
        'localTimestamp': conflict.localEntry.timestamp.toIso8601String(),
        'remoteTimestamp': conflict.remoteEntry.timestamp.toIso8601String(),
      },
    );
  }
}

/// Strategy that always uses the local entry
class UseLocalStrategy extends ConflictResolutionStrategy {
  @override
  Future<ResolvedConflict> resolve(
    SyncConflict conflict, {
    ConflictResolution? userChoice,
    Map<String, dynamic>? mergedData,
  }) async {
    return ResolvedConflict(
      entryId: conflict.entryId,
      resolution: ConflictResolution.useLocal,
      resolvedEntry: conflict.localEntry,
      requiresUserInput: false,
      metadata: {'strategy': 'useLocal'},
    );
  }
}

/// Strategy that always uses the remote entry
class UseRemoteStrategy extends ConflictResolutionStrategy {
  @override
  Future<ResolvedConflict> resolve(
    SyncConflict conflict, {
    ConflictResolution? userChoice,
    Map<String, dynamic>? mergedData,
  }) async {
    return ResolvedConflict(
      entryId: conflict.entryId,
      resolution: ConflictResolution.useRemote,
      resolvedEntry: conflict.remoteEntry,
      requiresUserInput: false,
      metadata: {'strategy': 'useRemote'},
    );
  }
}

/// Strategy that attempts to merge conflicting entries
class MergeStrategy extends ConflictResolutionStrategy {
  @override
  Future<ResolvedConflict> resolve(
    SyncConflict conflict, {
    ConflictResolution? userChoice,
    Map<String, dynamic>? mergedData,
  }) async {
    // For now, merge strategy falls back to last writer wins
    // In a real implementation, this would attempt intelligent merging
    final useLocal = conflict.localEntry.timestamp.isAfter(
      conflict.remoteEntry.timestamp,
    );

    return ResolvedConflict(
      entryId: conflict.entryId,
      resolution: ConflictResolution.merge,
      resolvedEntry: useLocal ? conflict.localEntry : conflict.remoteEntry,
      requiresUserInput: false,
      metadata: {
        'strategy': 'merge',
        'mergeResult': 'fallback_to_last_writer_wins',
      },
    );
  }
}

/// Strategy that requires user input for resolution
class UserChoiceStrategy extends ConflictResolutionStrategy {
  @override
  Future<ResolvedConflict> resolve(
    SyncConflict conflict, {
    ConflictResolution? userChoice,
    Map<String, dynamic>? mergedData,
  }) async {
    if (userChoice == null) {
      return ResolvedConflict(
        entryId: conflict.entryId,
        resolution: ConflictResolution.userChoice,
        resolvedEntry: conflict.localEntry, // Placeholder
        requiresUserInput: true,
        metadata: {'strategy': 'userChoice'},
      );
    }

    SyncEntry resolvedEntry;
    switch (userChoice) {
      case ConflictResolution.useLocal:
        resolvedEntry = conflict.localEntry;
        break;
      case ConflictResolution.useRemote:
        resolvedEntry = conflict.remoteEntry;
        break;
      case ConflictResolution.merge:
        // Use merged data if provided, otherwise fall back to local
        resolvedEntry = mergedData != null
            ? _createMergedEntry(conflict, mergedData)
            : conflict.localEntry;
        break;
      default:
        resolvedEntry = conflict.localEntry;
    }

    return ResolvedConflict(
      entryId: conflict.entryId,
      resolution: userChoice,
      resolvedEntry: resolvedEntry,
      requiresUserInput: false,
      metadata: {
        'strategy': 'userChoice',
        'userSelection': userChoice.toString(),
      },
    );
  }

  SyncEntry _createMergedEntry(
    SyncConflict conflict,
    Map<String, dynamic> mergedData,
  ) {
    return SyncEntry(
      id: conflict.entryId,
      action: SyncAction.update,
      timestamp: DateTime.now(),
      dataHash: _calculateDataHash(mergedData),
      dataSize: jsonEncode(mergedData).length,
      metadata: mergedData,
    );
  }

  String _calculateDataHash(Map<String, dynamic> data) {
    // Simple hash calculation - in production, use proper hashing
    return data.hashCode.toString();
  }
}

/// Result of conflict resolution
class ConflictResolutionResult {
  final Map<String, ResolvedConflict> resolvedConflicts;
  final List<SyncConflict> unresolvedConflicts;
  final int totalConflicts;

  const ConflictResolutionResult({
    required this.resolvedConflicts,
    required this.unresolvedConflicts,
    required this.totalConflicts,
  });

  bool get hasUnresolvedConflicts => unresolvedConflicts.isNotEmpty;
  int get resolvedCount => resolvedConflicts.length;
  int get unresolvedCount => unresolvedConflicts.length;
  double get resolutionProgress =>
      totalConflicts > 0 ? resolvedCount / totalConflicts : 1.0;
}

/// A resolved conflict
class ResolvedConflict {
  final String entryId;
  final ConflictResolution resolution;
  final SyncEntry resolvedEntry;
  final bool requiresUserInput;
  final Map<String, dynamic>? metadata;

  const ResolvedConflict({
    required this.entryId,
    required this.resolution,
    required this.resolvedEntry,
    required this.requiresUserInput,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'resolution': resolution.toString(),
      'resolvedEntry': resolvedEntry.toJson(),
      'requiresUserInput': requiresUserInput,
      'metadata': metadata,
    };
  }
}

/// Summary of conflicts by type
class ConflictSummary {
  int updateUpdateCount = 0;
  int updateDeleteCount = 0;
  int deleteUpdateCount = 0;
  int createCreateCount = 0;

  int get totalCount =>
      updateUpdateCount +
      updateDeleteCount +
      deleteUpdateCount +
      createCreateCount;

  Map<String, int> toMap() {
    return {
      'updateUpdate': updateUpdateCount,
      'updateDelete': updateDeleteCount,
      'deleteUpdate': deleteUpdateCount,
      'createCreate': createCreateCount,
    };
  }
}

/// Conflict resolution event
class ConflictResolutionEvent {
  final ConflictResolutionEventType type;
  final SyncConflict conflict;
  final ResolvedConflict? resolution;
  final String? error;
  final DateTime timestamp;

  ConflictResolutionEvent._({
    required this.type,
    required this.conflict,
    this.resolution,
    this.error,
    required this.timestamp,
  });

  factory ConflictResolutionEvent.resolved({
    required SyncConflict conflict,
    required ResolvedConflict resolution,
  }) {
    return ConflictResolutionEvent._(
      type: ConflictResolutionEventType.resolved,
      conflict: conflict,
      resolution: resolution,
      timestamp: DateTime.now(),
    );
  }

  factory ConflictResolutionEvent.error({
    required SyncConflict conflict,
    required String error,
  }) {
    return ConflictResolutionEvent._(
      type: ConflictResolutionEventType.error,
      conflict: conflict,
      error: error,
      timestamp: DateTime.now(),
    );
  }
}

enum ConflictResolutionEventType { resolved, error }
