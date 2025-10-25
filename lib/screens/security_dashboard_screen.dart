import 'package:flutter/material.dart';
import '../models/security_report.dart';
import '../models/security_issue.dart';
import '../models/premium_feature.dart';
import '../services/security_analyzer.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';
import '../services/development_helpers.dart';
import '../widgets/security_score_card.dart';
import '../widgets/security_issues_list.dart';
import '../widgets/security_recommendations_list.dart';
import '../widgets/security_category_scores.dart';
import '../widgets/premium_upgrade_card.dart';
import 'hibp_import_screen.dart';

class SecurityDashboardScreen extends StatefulWidget {
  final String? vaultId;

  const SecurityDashboardScreen({super.key, this.vaultId});

  @override
  State<SecurityDashboardScreen> createState() =>
      _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SecurityReport? _securityReport;
  bool _isLoading = true;
  String? _error;
  String _currentVaultId = 'default';
  bool _hasBreachChecking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentVaultId = widget.vaultId ?? 'default';
    _checkPremiumAccess();
    _loadSecurityReport();
  }

  void _checkPremiumAccess() {
    final licenseManager = LicenseManagerFactory.getInstance();
    final featureGate = FeatureGateFactory.create(licenseManager);
    _hasBreachChecking = featureGate.canAccess(PremiumFeature.breachChecking);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await SecurityAnalyzer.analyzeVault(_currentVaultId);
      setState(() {
        _securityReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSecurityData() async {
    try {
      await SecurityAnalyzer.refreshBreachData(_currentVaultId);
      await _loadSecurityReport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security data refreshed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security Dashboard'),
            if (FeatureGateFactory.isDevelopmentMode)
              const Text(
                'DEV MODE - All Features Unlocked',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshSecurityData,
            tooltip: 'Refresh Security Data',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'hibp_import') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HIBPImportScreen(),
                  ),
                );
              } else {
                setState(() {
                  _currentVaultId = value;
                });
                _loadSecurityReport();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'default',
                child: Text('Default Vault'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'hibp_import',
                child: Row(
                  children: [
                    Icon(
                      _hasBreachChecking ? Icons.shield : Icons.lock,
                      color: _hasBreachChecking ? null : Colors.amber.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text('Breach Dataset'),
                    if (!_hasBreachChecking) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.workspace_premium,
                        size: 16,
                        color: Colors.amber.shade700,
                      ),
                    ],
                  ],
                ),
              ),
              // Add more vault options here when multi-vault is implemented
            ],
          ),
        ],
        bottom: TabBar(
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
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing vault security...'),
            SizedBox(height: 8),
            Text(
              'This may take a moment while we check for breached passwords',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSecurityReport,
              child: const Text('Retry'),
            ),
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
    final report = _securityReport!;

    return RefreshIndicator(
      onRefresh: _loadSecurityReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SecurityScoreCard(
              score: report.overallScore,
              totalAccounts: report.totalAccounts,
              secureAccounts: report.secureAccounts,
              lastUpdated: report.generatedAt,
            ),
            const SizedBox(height: 16),
            SecurityCategoryScores(categoryScores: report.categoryScores),
            const SizedBox(height: 16),
            // Show premium upgrade card if breach checking is not available
            if (!_hasBreachChecking) ...[
              PremiumUpgradeCard(
                feature: PremiumFeature.breachChecking,
                customTitle: 'Unlock Advanced Security',
                customDescription:
                    'Get comprehensive breach monitoring and advanced security analysis with premium.',
              ),
              const SizedBox(height: 16),
            ],
            // Development mode testing buttons
            if (FeatureGateFactory.isDevelopmentMode) ...[
              _buildDevelopmentTestCard(),
              const SizedBox(height: 16),
            ],
            _buildQuickStats(report),
            const SizedBox(height: 16),
            _buildSecurityTrends(),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuesTab() {
    final report = _securityReport!;

    return RefreshIndicator(
      onRefresh: _loadSecurityReport,
      child: SecurityIssuesList(
        issues: report.issues,
        onIssueSelected: _handleIssueSelected,
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    final report = _securityReport!;

    return RefreshIndicator(
      onRefresh: _loadSecurityReport,
      child: SecurityRecommendationsList(
        recommendations: report.recommendations,
        onRecommendationSelected: _handleRecommendationSelected,
      ),
    );
  }

  Widget _buildQuickStats(SecurityReport report) {
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Accounts',
                    report.totalAccounts.toString(),
                    Icons.account_circle,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Security Issues',
                    report.issues.length.toString(),
                    Icons.warning,
                    color: report.issues.isEmpty ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Secure Accounts',
                    '${report.secureAccounts}/${report.totalAccounts}',
                    Icons.security,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Recommendations',
                    report.recommendations.length.toString(),
                    Icons.lightbulb,
                    color: Colors.blue,
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
    IconData icon, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color ?? Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSecurityTrends() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Security Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Track your security improvements over time',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Security trends chart\n(Coming soon)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleIssueSelected(SecurityIssue issue) {
    // Navigate to issue details or show action dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(issue.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue.description),
            const SizedBox(height: 16),
            Text(
              'Recommendation:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(issue.recommendation),
            const SizedBox(height: 16),
            Text(
              'Affected accounts: ${issue.affectedAccountIds.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to fix issue screen
            },
            child: const Text('Fix Issue'),
          ),
        ],
      ),
    );
  }

  void _handleRecommendationSelected(SecurityRecommendation recommendation) {
    // Handle recommendation selection
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recommendation.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recommendation.description),
            const SizedBox(height: 16),
            Text(
              'Affected accounts: ${recommendation.affectedAccountIds.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to action screen
            },
            child: Text(recommendation.actionText),
          ),
        ],
      ),
    );
  }

  Widget _buildDevelopmentTestCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'Development Testing',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Test premium features in development mode',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await DevelopmentHelpers.testBreachChecking();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'HIBP test completed - check debug console',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.shield),
                  label: const Text('Test HIBP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await DevelopmentHelpers.testAllPremiumFeatures();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Premium features test completed - check debug console',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.star),
                  label: const Text('Test All Features'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    DevelopmentHelpers.showDevelopmentStatus();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Development status shown in debug console',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info),
                  label: const Text('Show Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
