import 'package:flutter/material.dart';
import '../models/security_audit_models.dart';
import '../models/vault_metadata.dart';
import '../services/vault_manager.dart';

import '../widgets/feature_gate_wrapper.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';
import '../models/premium_feature.dart';

/// Screen for detailed security audit and analysis
class SecurityAuditScreen extends StatefulWidget {
  final VaultManager vaultManager;

  const SecurityAuditScreen({super.key, required this.vaultManager});

  @override
  State<SecurityAuditScreen> createState() => _SecurityAuditScreenState();
}

class _SecurityAuditScreenState extends State<SecurityAuditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SecurityAuditReport? _auditReport;
  List<VaultMetadata> _vaults = [];
  VaultMetadata? _selectedVault;
  bool _isLoading = true;
  String? _error;
  late final _featureGate = FeatureGateFactory.create(
    LicenseManagerFactory.getInstance(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final vaults = await widget.vaultManager.getVaults();
      final activeVault = await widget.vaultManager.getActiveVault();

      setState(() {
        _vaults = vaults;
        _selectedVault = activeVault;
      });

      await _performAudit();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _performAudit() async {
    if (_selectedVault == null) return;

    try {
      // Create a mock audit report for now
      final report = SecurityAuditReport(
        vaultId: _selectedVault!.id,
        generatedAt: DateTime.now(),
        overallScore: 75.0,
        totalPasswords: 45,
        securePasswords: 32,
        passwordStrengthScore: 80.0,
        uniquenessScore: 85.0,
        freshnessScore: 70.0,
        twoFactorScore: 60.0,
        weakPasswords: [
          PasswordInfo(
            accountId: '1',
            accountName: 'Facebook',
            username: 'user@example.com',
          ),
          PasswordInfo(
            accountId: '2',
            accountName: 'Twitter',
            username: 'user@example.com',
          ),
        ],
        compromisedPasswords: [
          PasswordInfo(
            accountId: '3',
            accountName: 'LinkedIn',
            username: 'user@example.com',
            isCompromised: true,
          ),
        ],
        duplicatePasswords: [
          PasswordInfo(
            accountId: '4',
            accountName: 'Instagram',
            username: 'user@example.com',
          ),
          PasswordInfo(
            accountId: '5',
            accountName: 'Pinterest',
            username: 'user@example.com',
          ),
        ],
        oldPasswords: [
          PasswordInfo(
            accountId: '6',
            accountName: 'Yahoo',
            username: 'user@example.com',
            lastModified: DateTime.now().subtract(const Duration(days: 200)),
          ),
        ],
      );

      setState(() {
        _auditReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría de Seguridad'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _performAudit,
            tooltip: 'Actualizar auditoría',
          ),
          PopupMenuButton<VaultMetadata>(
            icon: const Icon(Icons.folder),
            tooltip: 'Seleccionar bóveda',
            onSelected: (vault) {
              setState(() {
                _selectedVault = vault;
              });
              _performAudit();
            },
            itemBuilder: (context) => _vaults.map((vault) {
              return PopupMenuItem(
                value: vault,
                child: Row(
                  children: [
                    Icon(Icons.folder, color: vault.color, size: 20),
                    const SizedBox(width: 8),
                    Text(vault.name),
                    if (vault.id == _selectedVault?.id) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check, size: 16, color: Colors.green),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Resumen', icon: Icon(Icons.dashboard)),
            Tab(text: 'Problemas', icon: Icon(Icons.warning)),
            Tab(text: 'Fortaleza', icon: Icon(Icons.security)),
            Tab(text: 'Recomendaciones', icon: Icon(Icons.lightbulb)),
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
            Text('Analizando seguridad...'),
            SizedBox(height: 8),
            Text(
              'Esto puede tomar unos momentos',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
              onPressed: _loadData,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_auditReport == null) {
      return const Center(child: Text('No hay datos de auditoría disponibles'));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildIssuesTab(),
        _buildStrengthTab(),
        _buildRecommendationsTab(),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final report = _auditReport!;

    return RefreshIndicator(
      onRefresh: _performAudit,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreCard(report),
            const SizedBox(height: 16),
            _buildQuickStats(report),
            const SizedBox(height: 16),
            _buildCategoryBreakdown(report),
            const SizedBox(height: 16),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(SecurityAuditReport report) {
    final score = report.overallScore;
    final color = _getScoreColor(score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Puntuación de Seguridad',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getScoreDescription(score),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      '${score.round()}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(SecurityAuditReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas Rápidas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total',
                    '${report.totalPasswords}',
                    Icons.key,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Seguras',
                    '${report.securePasswords}',
                    Icons.security,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Débiles',
                    '${report.weakPasswords.length}',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Comprometidas',
                    '${report.compromisedPasswords.length}',
                    Icons.dangerous,
                    Colors.red,
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

  Widget _buildCategoryBreakdown(SecurityAuditReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Análisis por Categorías',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildCategoryItem(
              'Fortaleza de Contraseñas',
              report.passwordStrengthScore,
              Icons.fitness_center,
            ),
            _buildCategoryItem(
              'Unicidad',
              report.uniquenessScore,
              Icons.fingerprint,
            ),
            _buildCategoryItem(
              'Actualización',
              report.freshnessScore,
              Icons.update,
            ),
            _buildCategoryItem(
              'Autenticación 2FA',
              report.twoFactorScore,
              Icons.verified_user,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(String title, double score, IconData icon) {
    final color = _getScoreColor(score);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${score.round()}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividad Reciente',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              'Última auditoría completa',
              'Hace 2 horas',
              Icons.security,
              Colors.green,
            ),
            _buildActivityItem(
              'Contraseña débil detectada',
              'Hace 1 día',
              Icons.warning,
              Colors.orange,
            ),
            _buildActivityItem(
              'Nueva filtración detectada',
              'Hace 3 días',
              Icons.dangerous,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
          Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildIssuesTab() {
    final report = _auditReport!;

    return RefreshIndicator(
      onRefresh: _performAudit,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (report.compromisedPasswords.isNotEmpty) ...[
            _buildIssueSection(
              'Contraseñas Comprometidas',
              report.compromisedPasswords
                  .map(
                    (p) => SecurityIssueItem(
                      title: p.accountName,
                      description: 'Encontrada en filtración de datos',
                      severity: IssueSeverity.critical,
                      icon: Icons.dangerous,
                    ),
                  )
                  .toList(),
              Colors.red,
            ),
            const SizedBox(height: 16),
          ],
          if (report.weakPasswords.isNotEmpty) ...[
            _buildIssueSection(
              'Contraseñas Débiles',
              report.weakPasswords
                  .map(
                    (p) => SecurityIssueItem(
                      title: p.accountName,
                      description: 'Contraseña fácil de adivinar',
                      severity: IssueSeverity.high,
                      icon: Icons.warning,
                    ),
                  )
                  .toList(),
              Colors.orange,
            ),
            const SizedBox(height: 16),
          ],
          if (report.duplicatePasswords.isNotEmpty) ...[
            _buildIssueSection(
              'Contraseñas Duplicadas',
              report.duplicatePasswords
                  .map(
                    (p) => SecurityIssueItem(
                      title: p.accountName,
                      description:
                          'Contraseña reutilizada en múltiples cuentas',
                      severity: IssueSeverity.medium,
                      icon: Icons.content_copy,
                    ),
                  )
                  .toList(),
              Colors.amber,
            ),
            const SizedBox(height: 16),
          ],
          if (report.oldPasswords.isNotEmpty) ...[
            _buildIssueSection(
              'Contraseñas Antiguas',
              report.oldPasswords
                  .map(
                    (p) => SecurityIssueItem(
                      title: p.accountName,
                      description: 'No actualizada en más de 6 meses',
                      severity: IssueSeverity.low,
                      icon: Icons.schedule,
                    ),
                  )
                  .toList(),
              Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssueSection(
    String title,
    List<SecurityIssueItem> issues,
    Color color,
  ) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${issues.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          ...issues.map(
            (issue) => ListTile(
              leading: Icon(issue.icon, color: color),
              title: Text(issue.title),
              subtitle: Text(issue.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showIssueDetails(issue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthTab() {
    return FeatureGateWrapper(
      feature: PremiumFeature.securityHealth,
      featureGate: _featureGate,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStrengthDistribution(),
            const SizedBox(height: 16),
            _buildPasswordPatterns(),
            const SizedBox(height: 16),
            _buildSecurityTrends(),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthDistribution() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución de Fortaleza',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildStrengthBar('Muy Fuerte', 45, Colors.green),
            _buildStrengthBar('Fuerte', 30, Colors.lightGreen),
            _buildStrengthBar('Media', 15, Colors.orange),
            _buildStrengthBar('Débil', 10, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthBar(String label, int percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(width: 8),
          Text('$percentage%', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPasswordPatterns() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patrones Comunes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildPatternItem(
              'Fechas en contraseñas',
              12,
              Icons.calendar_today,
            ),
            _buildPatternItem('Nombres propios', 8, Icons.person),
            _buildPatternItem('Palabras del diccionario', 15, Icons.book),
            _buildPatternItem('Secuencias numéricas', 5, Icons.numbers),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternItem(String pattern, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(pattern)),
          Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSecurityTrends() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tendencias de Seguridad',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Gráfico de tendencias\n(Próximamente)',
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

  Widget _buildRecommendationsTab() {
    final report = _auditReport!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRecommendationCard(
          'Actualizar Contraseñas Débiles',
          'Se encontraron ${report.weakPasswords.length} contraseñas débiles que deben ser actualizadas.',
          Icons.security,
          Colors.orange,
          () => _showPasswordUpdateDialog(),
        ),
        const SizedBox(height: 12),
        _buildRecommendationCard(
          'Activar Autenticación 2FA',
          'Habilita la autenticación de dos factores en cuentas importantes.',
          Icons.verified_user,
          Colors.blue,
          () => _show2FASetupDialog(),
        ),
        const SizedBox(height: 12),
        _buildRecommendationCard(
          'Eliminar Duplicados',
          'Usa contraseñas únicas para cada cuenta para mayor seguridad.',
          Icons.content_copy,
          Colors.amber,
          () => _showDuplicateResolutionDialog(),
        ),
        const SizedBox(height: 12),
        FeatureGateWrapper(
          feature: PremiumFeature.breachChecking,
          featureGate: _featureGate,
          child: _buildRecommendationCard(
            'Monitoreo de Filtraciones',
            'Activa el monitoreo automático de filtraciones de datos.',
            Icons.monitor_heart,
            Colors.purple,
            () => _setupBreachMonitoring(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreDescription(double score) {
    if (score >= 80) return 'Excelente seguridad';
    if (score >= 60) return 'Buena seguridad';
    if (score >= 40) return 'Seguridad mejorable';
    return 'Seguridad deficiente';
  }

  void _showIssueDetails(SecurityIssueItem issue) {
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
              'Severidad: ${issue.severity.name.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getSeverityColor(issue.severity),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to fix issue
            },
            child: const Text('Solucionar'),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(IssueSeverity severity) {
    switch (severity) {
      case IssueSeverity.critical:
        return Colors.red;
      case IssueSeverity.high:
        return Colors.orange;
      case IssueSeverity.medium:
        return Colors.amber;
      case IssueSeverity.low:
        return Colors.blue;
    }
  }

  void _showPasswordUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar Contraseñas'),
        content: const Text(
          'Se abrirá el generador de contraseñas para ayudarte a crear '
          'contraseñas más seguras para las cuentas identificadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open password generator
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _show2FASetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar 2FA'),
        content: const Text(
          'La autenticación de dos factores añade una capa extra de seguridad. '
          '¿Deseas configurarla para tus cuentas importantes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Más tarde'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to 2FA setup
            },
            child: const Text('Configurar'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateResolutionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolver Duplicados'),
        content: const Text(
          'Se encontraron contraseñas duplicadas. El asistente te ayudará '
          'a generar contraseñas únicas para cada cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Open duplicate resolution wizard
            },
            child: const Text('Resolver'),
          ),
        ],
      ),
    );
  }

  void _setupBreachMonitoring() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monitoreo de Filtraciones'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configurar monitoreo automático:'),
            SizedBox(height: 16),
            Text('• Verificación diaria de nuevas filtraciones'),
            Text('• Alertas inmediatas por contraseñas comprometidas'),
            Text('• Reportes semanales de seguridad'),
            Text('• Recomendaciones personalizadas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Monitoreo de filtraciones activado'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Activar'),
          ),
        ],
      ),
    );
  }
}

class SecurityIssueItem {
  final String title;
  final String description;
  final IssueSeverity severity;
  final IconData icon;

  SecurityIssueItem({
    required this.title,
    required this.description,
    required this.severity,
    required this.icon,
  });
}

enum IssueSeverity { critical, high, medium, low }
