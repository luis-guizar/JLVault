import 'package:flutter/material.dart';
import '../../models/import_result.dart';
import '../../models/account.dart';
import '../../services/import/duplicate_detector.dart';

/// Dialog for resolving duplicate accounts during import
class DuplicateResolutionDialog extends StatefulWidget {
  final List<MergeSuggestion> suggestions;
  final Function(Map<String, DuplicateResolution>) onResolutionsSelected;

  const DuplicateResolutionDialog({
    super.key,
    required this.suggestions,
    required this.onResolutionsSelected,
  });

  @override
  State<DuplicateResolutionDialog> createState() =>
      _DuplicateResolutionDialogState();
}

class _DuplicateResolutionDialogState extends State<DuplicateResolutionDialog> {
  final Map<String, DuplicateResolution> _resolutions = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with recommended actions
    for (final suggestion in widget.suggestions) {
      _resolutions[suggestion.duplicate.existingAccountId] =
          DuplicateResolution(
            action: suggestion.recommendedAction,
            mergeFields: {},
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) {
      return AlertDialog(
        title: const Text('No Duplicates'),
        content: const Text('No duplicate accounts were found.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    final currentSuggestion = widget.suggestions[_currentIndex];
    final currentResolution =
        _resolutions[currentSuggestion.duplicate.existingAccountId]!;

    return AlertDialog(
      title: Text(
        'Duplicate Found (${_currentIndex + 1}/${widget.suggestions.length})',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountComparison(currentSuggestion),
            const SizedBox(height: 16),
            _buildActionSelection(currentSuggestion, currentResolution),
            if (currentSuggestion.conflicts.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildConflictResolution(currentSuggestion, currentResolution),
            ],
          ],
        ),
      ),
      actions: [
        if (_currentIndex > 0)
          TextButton(
            onPressed: () => setState(() => _currentIndex--),
            child: const Text('Previous'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_currentIndex < widget.suggestions.length - 1)
          TextButton(
            onPressed: () => setState(() => _currentIndex++),
            child: const Text('Next'),
          ),
        if (_currentIndex == widget.suggestions.length - 1)
          ElevatedButton(
            onPressed: () {
              widget.onResolutionsSelected(_resolutions);
              Navigator.of(context).pop();
            },
            child: const Text('Apply All'),
          ),
      ],
    );
  }

  Widget _buildAccountComparison(MergeSuggestion suggestion) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Potential Duplicate Detected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildMatchInfo(suggestion.duplicate),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAccountCard(
                    'Importing',
                    suggestion.duplicate.imported.title,
                    suggestion.duplicate.imported.username,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildAccountCard(
                    'Existing',
                    suggestion.existingAccount.name,
                    suggestion.existingAccount.username,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfo(ImportDuplicate duplicate) {
    String matchDescription;
    Color matchColor;

    switch (duplicate.matchType) {
      case DuplicateMatchType.exact:
        matchDescription = 'Exact match';
        matchColor = Colors.red;
        break;
      case DuplicateMatchType.titleAndUsername:
        matchDescription = 'Title and username match';
        matchColor = Colors.orange;
        break;
      case DuplicateMatchType.titleOnly:
        matchDescription = 'Title matches';
        matchColor = Colors.yellow.shade700;
        break;
      case DuplicateMatchType.usernameAndUrl:
        matchDescription = 'Username and URL match';
        matchColor = Colors.orange;
        break;
      case DuplicateMatchType.fuzzy:
        matchDescription = 'Similar accounts';
        matchColor = Colors.grey;
        break;
    }

    return Row(
      children: [
        Icon(Icons.warning, color: matchColor, size: 16),
        const SizedBox(width: 8),
        Text(
          '$matchDescription (${(duplicate.confidence * 100).toInt()}% confidence)',
          style: TextStyle(color: matchColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAccountCard(
    String label,
    String title,
    String username,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            username,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelection(
    MergeSuggestion suggestion,
    DuplicateResolution resolution,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Action:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...MergeAction.values.map(
          (action) => RadioListTile<MergeAction>(
            title: Text(_getActionDescription(action)),
            subtitle: Text(_getActionSubtitle(action)),
            value: action,
            groupValue: resolution.action,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _resolutions[suggestion.duplicate.existingAccountId] =
                      DuplicateResolution(
                        action: value,
                        mergeFields: resolution.mergeFields,
                      );
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConflictResolution(
    MergeSuggestion suggestion,
    DuplicateResolution resolution,
  ) {
    if (resolution.action != MergeAction.merge) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Merge Conflicts:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...suggestion.conflicts.map(
          (conflict) => _buildConflictTile(suggestion, conflict, resolution),
        ),
      ],
    );
  }

  Widget _buildConflictTile(
    MergeSuggestion suggestion,
    MergeConflict conflict,
    DuplicateResolution resolution,
  ) {
    final useImported = resolution.mergeFields[conflict.field] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.field.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Use Imported'),
                    subtitle: Text(
                      conflict.importedValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: true,
                    groupValue: useImported,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          final newMergeFields = Map<String, bool>.from(
                            resolution.mergeFields,
                          );
                          newMergeFields[conflict.field] = value;
                          _resolutions[suggestion.duplicate.existingAccountId] =
                              DuplicateResolution(
                                action: resolution.action,
                                mergeFields: newMergeFields,
                              );
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Keep Existing'),
                    subtitle: Text(
                      conflict.existingValue.isEmpty
                          ? 'None'
                          : conflict.existingValue,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: false,
                    groupValue: useImported,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          final newMergeFields = Map<String, bool>.from(
                            resolution.mergeFields,
                          );
                          newMergeFields[conflict.field] = !value;
                          _resolutions[suggestion.duplicate.existingAccountId] =
                              DuplicateResolution(
                                action: resolution.action,
                                mergeFields: newMergeFields,
                              );
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getActionDescription(MergeAction action) {
    switch (action) {
      case MergeAction.skip:
        return 'Skip Import';
      case MergeAction.replace:
        return 'Replace Existing';
      case MergeAction.merge:
        return 'Merge Data';
      case MergeAction.updatePassword:
        return 'Update Password Only';
      case MergeAction.askUser:
        return 'Let Me Decide';
    }
  }

  String _getActionSubtitle(MergeAction action) {
    switch (action) {
      case MergeAction.skip:
        return 'Don\'t import this account';
      case MergeAction.replace:
        return 'Replace existing account with imported data';
      case MergeAction.merge:
        return 'Combine data from both accounts';
      case MergeAction.updatePassword:
        return 'Only update the password';
      case MergeAction.askUser:
        return 'Review each conflict manually';
    }
  }
}

/// Represents user's resolution choice for a duplicate
class DuplicateResolution {
  final MergeAction action;
  final Map<String, bool> mergeFields; // field -> use imported value

  DuplicateResolution({required this.action, required this.mergeFields});
}
