import 'package:flutter/material.dart';
import '../models/sync_protocol.dart';
import '../services/sync_conflict_resolver.dart';

/// Widget for displaying and resolving sync conflicts
class ConflictResolutionWidget extends StatefulWidget {
  final List<SyncConflict> conflicts;
  final SyncConflictResolver conflictResolver;
  final Function(ConflictResolutionResult) onResolutionComplete;
  final VoidCallback? onCancel;

  const ConflictResolutionWidget({
    super.key,
    required this.conflicts,
    required this.conflictResolver,
    required this.onResolutionComplete,
    this.onCancel,
  });

  @override
  State<ConflictResolutionWidget> createState() =>
      _ConflictResolutionWidgetState();
}

class _ConflictResolutionWidgetState extends State<ConflictResolutionWidget> {
  final Map<String, ConflictResolution> _userChoices = {};
  final Map<String, Map<String, dynamic>> _mergedData = {};
  bool _isResolving = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.conflictResolver.getConflictSummary(
      widget.conflicts,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(summary),
            const SizedBox(height: 16),
            _buildConflictsList(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ConflictSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sync Conflicts Detected',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Found ${summary.totalCount} conflicts that need resolution:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        _buildConflictSummary(summary),
      ],
    );
  }

  Widget _buildConflictSummary(ConflictSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          if (summary.updateUpdateCount > 0)
            _buildSummaryRow(
              'Simultaneous Updates',
              summary.updateUpdateCount,
              Icons.edit,
            ),
          if (summary.updateDeleteCount > 0)
            _buildSummaryRow(
              'Update vs Delete',
              summary.updateDeleteCount,
              Icons.delete_forever,
            ),
          if (summary.deleteUpdateCount > 0)
            _buildSummaryRow(
              'Delete vs Update',
              summary.deleteUpdateCount,
              Icons.restore,
            ),
          if (summary.createCreateCount > 0)
            _buildSummaryRow(
              'Duplicate Creation',
              summary.createCreateCount,
              Icons.content_copy,
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Text('$label: $count'),
        ],
      ),
    );
  }

  Widget _buildConflictsList() {
    return Expanded(
      child: ListView.builder(
        itemCount: widget.conflicts.length,
        itemBuilder: (context, index) {
          final conflict = widget.conflicts[index];
          return _buildConflictCard(conflict, index);
        },
      ),
    );
  }

  Widget _buildConflictCard(SyncConflict conflict, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text('Conflict ${index + 1}: ${_getConflictTitle(conflict)}'),
        subtitle: Text(_getConflictDescription(conflict)),
        leading: Icon(_getConflictIcon(conflict.type), color: Colors.orange),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConflictDetails(conflict),
                const SizedBox(height: 16),
                _buildResolutionOptions(conflict),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictDetails(SyncConflict conflict) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conflict Details:',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildEntryDetails(
                'Local Version',
                conflict.localEntry,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEntryDetails(
                'Remote Version',
                conflict.remoteEntry,
                Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntryDetails(String title, SyncEntry entry, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text('Action: ${entry.action.toString().split('.').last}'),
          Text('Modified: ${_formatTimestamp(entry.timestamp)}'),
          if (entry.dataSize != null) Text('Size: ${entry.dataSize} bytes'),
        ],
      ),
    );
  }

  Widget _buildResolutionOptions(SyncConflict conflict) {
    final options = widget.conflictResolver.getResolutionOptions(conflict);
    final selectedOption = _userChoices[conflict.entryId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Resolution:',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...options.map(
          (option) => RadioListTile<ConflictResolution>(
            title: Text(_getResolutionTitle(option)),
            subtitle: Text(_getResolutionDescription(option)),
            value: option,
            groupValue: selectedOption,
            onChanged: (value) {
              setState(() {
                _userChoices[conflict.entryId] = value!;
              });
            },
          ),
        ),
        if (selectedOption == ConflictResolution.merge)
          _buildMergeOptions(conflict),
      ],
    );
  }

  Widget _buildMergeOptions(SyncConflict conflict) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merge Options:',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Automatic merge will be attempted. Manual merge options coming soon.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasUnresolvedChoices = widget.conflicts.any(
      (conflict) => !_userChoices.containsKey(conflict.entryId),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.onCancel != null)
          TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: hasUnresolvedChoices || _isResolving
              ? null
              : _resolveConflicts,
          child: _isResolving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resolve Conflicts'),
        ),
      ],
    );
  }

  Future<void> _resolveConflicts() async {
    setState(() {
      _isResolving = true;
    });

    try {
      final resolvedConflicts = <String, ResolvedConflict>{};

      for (final conflict in widget.conflicts) {
        final userChoice = _userChoices[conflict.entryId];
        if (userChoice != null) {
          final resolved = await widget.conflictResolver
              .resolveConflictWithUserChoice(
                conflict: conflict,
                userChoice: userChoice,
                mergedData: _mergedData[conflict.entryId],
              );
          resolvedConflicts[conflict.entryId] = resolved;
        }
      }

      final result = ConflictResolutionResult(
        resolvedConflicts: resolvedConflicts,
        unresolvedConflicts: [],
        totalConflicts: widget.conflicts.length,
      );

      widget.onResolutionComplete(result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error resolving conflicts: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isResolving = false;
      });
    }
  }

  String _getConflictTitle(SyncConflict conflict) {
    switch (conflict.type) {
      case ConflictType.updateUpdate:
        return 'Simultaneous Update';
      case ConflictType.updateDelete:
        return 'Update vs Delete';
      case ConflictType.deleteUpdate:
        return 'Delete vs Update';
      case ConflictType.createCreate:
        return 'Duplicate Creation';
    }
  }

  String _getConflictDescription(SyncConflict conflict) {
    switch (conflict.type) {
      case ConflictType.updateUpdate:
        return 'Both devices modified the same entry';
      case ConflictType.updateDelete:
        return 'One device updated while another deleted';
      case ConflictType.deleteUpdate:
        return 'One device deleted while another updated';
      case ConflictType.createCreate:
        return 'Both devices created entries with the same ID';
    }
  }

  IconData _getConflictIcon(ConflictType type) {
    switch (type) {
      case ConflictType.updateUpdate:
        return Icons.edit;
      case ConflictType.updateDelete:
        return Icons.delete_forever;
      case ConflictType.deleteUpdate:
        return Icons.restore;
      case ConflictType.createCreate:
        return Icons.content_copy;
    }
  }

  String _getResolutionTitle(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.useLocal:
        return 'Use Local Version';
      case ConflictResolution.useRemote:
        return 'Use Remote Version';
      case ConflictResolution.merge:
        return 'Merge Both Versions';
      case ConflictResolution.lastWriterWins:
        return 'Use Most Recent';
      case ConflictResolution.userChoice:
        return 'Manual Choice';
    }
  }

  String _getResolutionDescription(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.useLocal:
        return 'Keep the version from this device';
      case ConflictResolution.useRemote:
        return 'Use the version from the other device';
      case ConflictResolution.merge:
        return 'Attempt to combine both versions';
      case ConflictResolution.lastWriterWins:
        return 'Use whichever was modified most recently';
      case ConflictResolution.userChoice:
        return 'Let me decide manually';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
