import 'dart:async';
import 'package:flutter/material.dart';
import '../services/time_sync_service.dart';

/// Widget that displays time synchronization warnings
class TimeSyncWarningWidget extends StatefulWidget {
  final bool showOnlyWhenIssue;
  final EdgeInsets margin;
  final bool showDismissButton;

  const TimeSyncWarningWidget({
    super.key,
    this.showOnlyWhenIssue = true,
    this.margin = const EdgeInsets.all(16),
    this.showDismissButton = true,
  });

  @override
  State<TimeSyncWarningWidget> createState() => _TimeSyncWarningWidgetState();
}

class _TimeSyncWarningWidgetState extends State<TimeSyncWarningWidget> {
  late StreamSubscription<TimeSyncStatus> _statusSubscription;
  TimeSyncStatus _currentStatus = TimeSyncStatus.unknown;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = TimeSyncService.currentStatus;

    _statusSubscription = TimeSyncService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
          // Reset dismissed state when status changes
          if (status != TimeSyncStatus.synchronized) {
            _isDismissed = false;
          }
        });
      }
    });

    // Start monitoring if not already started
    TimeSyncService.startMonitoring();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final warningMessage = TimeSyncService.getWarningMessageForStatus(
      _currentStatus,
    );

    if (widget.showOnlyWhenIssue && warningMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin,
      child: _buildWarningCard(warningMessage),
    );
  }

  Widget _buildWarningCard(String? warningMessage) {
    final isWarning = warningMessage != null;
    final backgroundColor = isWarning
        ? Colors.orange.shade100
        : Colors.green.shade100;
    final borderColor = isWarning
        ? Colors.orange.shade300
        : Colors.green.shade300;
    final iconColor = isWarning
        ? Colors.orange.shade700
        : Colors.green.shade700;
    final textColor = isWarning
        ? Colors.orange.shade700
        : Colors.green.shade700;

    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isWarning ? Icons.warning : Icons.check_circle,
                  color: iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isWarning ? 'Time Sync Warning' : 'Time Synchronized',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.showDismissButton && isWarning)
                  IconButton(
                    onPressed: () => setState(() => _isDismissed = true),
                    icon: Icon(Icons.close, color: iconColor, size: 20),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            if (warningMessage != null) ...[
              const SizedBox(height: 8),
              Text(warningMessage, style: TextStyle(color: textColor)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showTimeSyncDetails(context),
                style: TextButton.styleFrom(
                  foregroundColor: textColor,
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Learn more'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTimeSyncDetails(BuildContext context) {
    final info = TimeSyncService.getTimeSyncInfo();
    final recommendations = TimeSyncService.getFixRecommendations(info.status);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time Synchronization'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status: ${_getStatusDisplayName(info.status)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Local Time: ${_formatDateTime(info.localTime)}'),
              Text('UTC Time: ${_formatDateTime(info.utcTime)}'),
              Text('Time Zone: ${_formatTimeZone(info.timeZoneOffset)}'),

              if (info.warningMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Issue:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                Text(
                  info.warningMessage!,
                  style: TextStyle(color: Colors.orange.shade700),
                ),
              ],

              if (recommendations.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Recommendations:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...recommendations.map(
                  (rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(rec)),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              const Text(
                'Why is this important?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'TOTP codes are time-based and change every 30 seconds. '
                'If your device time is incorrect, the codes may not work '
                'with the services you\'re trying to authenticate with.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await TimeSyncService.checkTimeSync();
            },
            child: const Text('Check Again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplayName(TimeSyncStatus status) {
    switch (status) {
      case TimeSyncStatus.synchronized:
        return 'Synchronized';
      case TimeSyncStatus.unknown:
        return 'Unknown';
      case TimeSyncStatus.offsetTooLarge:
        return 'Time Zone Issue';
      case TimeSyncStatus.timeUnrealistic:
        return 'Incorrect Time';
      case TimeSyncStatus.utcMismatch:
        return 'Sync Issue';
      case TimeSyncStatus.networkUnavailable:
        return 'Network Unavailable';
      case TimeSyncStatus.checkFailed:
        return 'Check Failed';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatTimeZone(Duration offset) {
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();
    final sign = hours >= 0 ? '+' : '-';
    return 'UTC$sign${hours.abs().toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    super.dispose();
  }
}

/// Compact version of time sync warning for smaller spaces
class CompactTimeSyncWarning extends StatefulWidget {
  const CompactTimeSyncWarning({super.key});

  @override
  State<CompactTimeSyncWarning> createState() => _CompactTimeSyncWarningState();
}

class _CompactTimeSyncWarningState extends State<CompactTimeSyncWarning> {
  late StreamSubscription<TimeSyncStatus> _statusSubscription;
  TimeSyncStatus _currentStatus = TimeSyncStatus.unknown;

  @override
  void initState() {
    super.initState();
    _currentStatus = TimeSyncService.currentStatus;

    _statusSubscription = TimeSyncService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final warningMessage = TimeSyncService.getWarningMessageForStatus(
      _currentStatus,
    );

    if (warningMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
          const SizedBox(width: 4),
          Text(
            'Time sync issue',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _statusSubscription.cancel();
    super.dispose();
  }
}
