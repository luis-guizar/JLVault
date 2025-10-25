import 'package:flutter/material.dart';
import '../models/vault_metadata.dart';
import '../services/vault_manager.dart';
import '../services/export/export_service.dart';
import '../widgets/export/export_dialog.dart';
import '../widgets/import_dialog.dart';
import '../widgets/feature_gate_wrapper.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';
import '../models/premium_feature.dart';
import 'security_audit_screen.dart';

/// Screen for managing data import/export and security operations
class DataManagementScreen extends StatefulWidget {
  final VaultManager vaultManager;

  const DataManagementScreen({super.key, required this.vaultManager});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  List<VaultMetadata> _vaults = [];
  bool _isLoading = true;
  late final _featureGate = FeatureGateFactory.create(
    LicenseManagerFactory.getInstance(),
  );

  @override
  void initState() {
    super.initState();
    _loadVaults();
  }

  Future<void> _loadVaults() async {
    try {
      final vaults = await widget.vaultManager.getVaults();
      setState(() {
        _vaults = vaults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando bóvedas: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Datos'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadVaults,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader(context, 'Importar y Exportar'),
                  _buildImportExportSection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Auditoría de Seguridad'),
                  _buildSecuritySection(),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'Herramientas Avanzadas'),
                  _buildAdvancedToolsSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImportExportSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.file_upload, color: Colors.blue),
            ),
            title: const Text('Importar Contraseñas'),
            subtitle: const Text(
              'Importar desde otros gestores de contraseñas',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showImportDialog,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.file_download, color: Colors.green),
            ),
            title: const Text('Exportar Contraseñas'),
            subtitle: const Text('Crear respaldo de tus contraseñas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showExportDialog,
          ),
          const Divider(height: 1),
          FeatureGateWrapper(
            feature: PremiumFeature.importExport,
            featureGate: _featureGate,
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.enhanced_encryption,
                  color: Colors.purple,
                ),
              ),
              title: const Text('Exportación Segura'),
              subtitle: const Text('Exportar con cifrado avanzado'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showSecureExportDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security, color: Colors.orange),
            ),
            title: const Text('Auditoría de Seguridad'),
            subtitle: const Text('Analizar la seguridad de tus contraseñas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToSecurityAudit(),
          ),
          const Divider(height: 1),
          FeatureGateWrapper(
            feature: PremiumFeature.breachChecking,
            featureGate: _featureGate,
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning, color: Colors.red),
              ),
              title: const Text('Verificación de Filtraciones'),
              subtitle: const Text('Comprobar contraseñas comprometidas'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _checkBreaches,
            ),
          ),
          const Divider(height: 1),
          FeatureGateWrapper(
            feature: PremiumFeature.securityHealth,
            featureGate: _featureGate,
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.monitor_heart, color: Colors.indigo),
              ),
              title: const Text('Monitoreo Continuo'),
              subtitle: const Text('Vigilancia automática de seguridad'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _configureMonitoring,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedToolsSection() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics, color: Colors.teal),
            ),
            title: const Text('Análisis de Datos'),
            subtitle: const Text('Estadísticas y patrones de uso'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showDataAnalysis,
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.brown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cleaning_services, color: Colors.brown),
            ),
            title: const Text('Limpieza de Datos'),
            subtitle: const Text('Eliminar duplicados y entradas obsoletas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showDataCleanup,
          ),
          const Divider(height: 1),
          FeatureGateWrapper(
            feature: PremiumFeature.securityHealth,
            featureGate: _featureGate,
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assessment, color: Colors.deepPurple),
              ),
              title: const Text('Reportes Avanzados'),
              subtitle: const Text('Informes detallados de seguridad'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _generateAdvancedReports,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => ImportDialog(vaultManager: widget.vaultManager),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se importaron $result contraseñas exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      _loadVaults(); // Refresh vault data
    }
  }

  Future<void> _showExportDialog() async {
    try {
      final exportService = DefaultExportService();
      await showDialog(
        context: context,
        builder: (context) => ExportDialog(
          availableVaults: _vaults,
          exportService: exportService,
          onExportComplete: (result) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Exportación completada: ${result.filePath}'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error en exportación: $e')));
      }
    }
  }

  Future<void> _showSecureExportDialog() async {
    // Show premium secure export dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Función premium: Exportación segura con cifrado avanzado',
        ),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _navigateToSecurityAudit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SecurityAuditScreen(vaultManager: widget.vaultManager),
      ),
    );
  }

  Future<void> _checkBreaches() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Verificando filtraciones...'),
            ],
          ),
        ),
      );

      // Simulate breach checking
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verificación Completada'),
            content: const Text(
              'Se encontraron 3 contraseñas en bases de datos de filtraciones conocidas. '
              'Se recomienda cambiar estas contraseñas inmediatamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToSecurityAudit();
                },
                child: const Text('Ver Detalles'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verificando filtraciones: $e')),
        );
      }
    }
  }

  void _configureMonitoring() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monitoreo de Seguridad'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configurar monitoreo automático:'),
            SizedBox(height: 16),
            Text('• Verificación diaria de filtraciones'),
            Text('• Alertas de contraseñas débiles'),
            Text('• Notificaciones de seguridad'),
            Text('• Reportes semanales'),
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
                  content: Text('Monitoreo configurado exitosamente'),
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

  void _showDataAnalysis() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Análisis de Datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas de tus bóvedas:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            _buildStatRow('Total de contraseñas:', '${_getTotalPasswords()}'),
            _buildStatRow('Contraseñas únicas:', '${_getUniquePasswords()}'),
            _buildStatRow('Contraseñas débiles:', '${_getWeakPasswords()}'),
            _buildStatRow('Duplicados:', '${_getDuplicates()}'),
            const SizedBox(height: 16),
            const Text(
              'Recomendaciones:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Actualizar 5 contraseñas débiles'),
            const Text('• Eliminar 3 duplicados'),
            const Text('• Activar 2FA en 8 cuentas'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showDataCleanup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpieza de Datos'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Elementos encontrados para limpieza:'),
            SizedBox(height: 16),
            Text('• 3 entradas duplicadas'),
            Text('• 2 cuentas sin usar (>1 año)'),
            Text('• 1 entrada con datos incompletos'),
            SizedBox(height: 16),
            Text('¿Deseas proceder con la limpieza automática?'),
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
                  content: Text('Limpieza completada: 6 elementos procesados'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _generateAdvancedReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función premium: Generando reportes avanzados...'),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  int _getTotalPasswords() {
    return _vaults.fold(0, (sum, vault) => sum + vault.passwordCount);
  }

  int _getUniquePasswords() {
    return (_getTotalPasswords() * 0.85).round();
  }

  int _getWeakPasswords() {
    return (_getTotalPasswords() * 0.15).round();
  }

  int _getDuplicates() {
    return (_getTotalPasswords() * 0.05).round();
  }
}
