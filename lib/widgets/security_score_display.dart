import 'package:flutter/material.dart';
import '../services/security_analyzer.dart';
import '../models/security_report.dart';
import 'security_score_card.dart';

/// A stateful widget that displays and manages real-time security score updates
class SecurityScoreDisplay extends StatefulWidget {
  final String vaultId;
  final VoidCallback? onRefresh;

  const SecurityScoreDisplay({
    super.key,
    required this.vaultId,
    this.onRefresh,
  });

  @override
  State<SecurityScoreDisplay> createState() => _SecurityScoreDisplayState();
}

class _SecurityScoreDisplayState extends State<SecurityScoreDisplay> {
  SecurityReport? _securityReport;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSecurityReport();
  }

  Future<void> _loadSecurityReport() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await SecurityAnalyzer.analyzeVault(widget.vaultId);
      if (mounted) {
        setState(() {
          _securityReport = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshSecurityReport() async {
    await _loadSecurityReport();
    widget.onRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Card(
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Security Score',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _refreshSecurityReport,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || _securityReport == null) {
      return SecurityScoreCard(
        score: 0,
        totalAccounts: 0,
        secureAccounts: 0,
        lastUpdated: DateTime.now(),
        isLoading: true,
      );
    }

    return GestureDetector(
      onTap: _refreshSecurityReport,
      child: SecurityScoreCard(
        score: _securityReport!.overallScore,
        totalAccounts: _securityReport!.totalAccounts,
        secureAccounts: _securityReport!.secureAccounts,
        lastUpdated: _securityReport!.generatedAt,
        isLoading: false,
      ),
    );
  }
}
