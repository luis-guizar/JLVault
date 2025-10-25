import 'package:flutter/material.dart';
import '../services/security_analyzer.dart';
import '../models/security_report.dart';
import '../models/security_issue.dart';
import 'security_score_card.dart';
import 'security_category_scores.dart';
import 'security_issues_list.dart';
import 'security_recommendations_list.dart';

/// A comprehensive security dashboard that displays all security information
class SecurityDashboard extends StatefulWidget {
  final String vaultId;
  final Function(SecurityIssue)? onIssueSelected;
  final Function(SecurityRecommendation)? onRecommendationSelected;

  const SecurityDashboard({
    super.key,
    required this.vaultId,
    this.onIssueSelected,
    this.onRecommendationSelected,
  });

  @override
  State<SecurityDashboard> createState() => _SecurityDashboardState();
}

class _SecurityDashboardState extends State<SecurityDashboard>
    with SingleTickerProviderStateMixin {
  SecurityReport? _securityReport;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSecurityReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSecurityReport,
            tooltip: 'Refresh Security Analysis',
          ),
        ],
        bottom: _isLoading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                  Tab(text: 'Issues', icon: Icon(Icons.warning)),
                  Tab(text: 'Recommendations', icon: Icon(Icons.lightbulb)),
                ],
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Security Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshSecurityReport,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing vault security...'),
          ],
        ),
      );
    }

    if (_securityReport == null) {
      return const Center(child: Text('No security data available'));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildIssuesTab(),
        _buildRecommendationsTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshSecurityReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SecurityScoreCard(
              score: _securityReport!.overallScore,
              totalAccounts: _securityReport!.totalAccounts,
              secureAccounts: _securityReport!.secureAccounts,
              lastUpdated: _securityReport!.generatedAt,
            ),
            const SizedBox(height: 16),
            SecurityCategoryScores(
              categoryScores: _securityReport!.categoryScores,
            ),
            const SizedBox(height: 16),
            _buildQuickStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesTab() {
    return RefreshIndicator(
      onRefresh: _refreshSecurityReport,
      child: SecurityIssuesList(
        issues: _securityReport!.issues,
        onIssueSelected: widget.onIssueSelected ?? (_) {},
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    return RefreshIndicator(
      onRefresh: _refreshSecurityReport,
      child: SecurityRecommendationsList(
        recommendations: _securityReport!.recommendations,
        onRecommendationSelected: widget.onRecommendationSelected ?? (_) {},
      ),
    );
  }

  Widget _buildQuickStats() {
    final report = _securityReport!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Stats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Accounts',
                    report.totalAccounts.toString(),
                    Icons.account_circle,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Secure Accounts',
                    report.secureAccounts.toString(),
                    Icons.security,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Security Issues',
                    report.issues.length.toString(),
                    Icons.warning,
                    report.issues.isEmpty ? Colors.green : Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Recommendations',
                    report.recommendations.length.toString(),
                    Icons.lightbulb,
                    report.recommendations.isEmpty ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
