import 'package:flutter/material.dart';
import '../models/security_audit_models.dart';

import '../widgets/feature_gate_wrapper.dart';
import '../services/feature_gate_factory.dart';
import '../services/license_manager_factory.dart';
import '../models/premium_feature.dart';

/// Screen for real-time security monitoring and alerts
class SecurityMonitoringScreen extends StatefulWidget {
  const SecurityMonitoringScreen({super.key});

  @override
  State<SecurityMonitoringScreen> createState() =>
      _SecurityMonitoringScreenState();
}

class _SecurityMonitoringScreenState extends State<SecurityMonitoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SecurityAlert> _alerts = [];
  SecurityMonitoringStatus _status = SecurityMonitoringStatus.inactive;
  bool _isLoading = true;
  late final _featureGate = FeatureGateFactory.create(
    LicenseManagerFactory.getInstance(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMonitoringData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMonitoringData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Mock data for now
      final alerts = [
        SecurityAlert(
          id: '1',
          type: AlertType.breach,
          severity: AlertSeverity.high,
          title: 'Contraseña comprometida detectada',
          description: 'Se encontró una contraseña en una filtración de datos',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          affectedAccounts: ['account1'],
        ),
        SecurityAlert(
          id: '2',
          type: AlertType.weakPassword,
          severity: AlertSeverity.medium,
          title: 'Contraseña débil detectada',
          description: 'Se detectó una contraseña fácil de adivinar',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          affectedAccounts: ['account2'],
        ),
      ];

      setState(() {
        _status = SecurityMonitoringStatus.active;
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando datos: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoreo de Seguridad'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadMonitoringData,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showMonitoringSettings,
            tooltip: 'Configuración',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Estado', icon: Icon(Icons.dashboard)),
            Tab(text: 'Alertas', icon: Icon(Icons.notifications)),
            Tab(text: 'Historial', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatusTab(),
                _buildAlertsTab(),
                _buildHistoryTab(),
              ],
            ),
      floatingActionButton: FeatureGateWrapper(
        feature: PremiumFeature.securityHealth,
        featureGate: _featureGate,
        child: FloatingActionButton.extended(
          onPressed: _toggleMonitoring,
          icon: Icon(
            _status == SecurityMonitoringStatus.active
                ? Icons.pause
                : Icons.play_arrow,
          ),
          label: Text(
            _status == SecurityMonitoringStatus.active ? 'Pausar' : 'Activar',
          ),
          backgroundColor: _status == SecurityMonitoringStatus.active
              ? Colors.orange
              : Colors.green,
        ),
      ),
    );
  }

  Widget _buildStatusTab() {
    return RefreshIndicator(
      onRefresh: _loadMonitoringData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildMonitoringMetrics(),
            const SizedBox(height: 16),
            _buildActiveScans(),
            const SizedBox(height: 16),
            _buildSystemHealth(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isActive = _status == SecurityMonitoringStatus.active;
    final color = isActive ? Colors.green : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1),
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    isActive ? Icons.security : Icons.security_outlined,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monitoreo de Seguridad',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusDescription(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Última verificación: ${_getLastCheckTime()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Text(
                'Última verificación: ${_getLastCheckTime()}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Métricas de Monitoreo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Cuentas Monitoreadas',
                    '127',
                    Icons.account_circle,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Alertas Activas',
                    '${_alerts.where((a) => a.isActive).length}',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    'Escaneos Hoy',
                    '24',
                    Icons.search,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    'Amenazas Detectadas',
                    '3',
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

  Widget _buildMetricItem(
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

  Widget _buildActiveScans() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escaneos Activos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildScanItem('Verificación de Filtraciones', 'En progreso', true),
            _buildScanItem('Análisis de Fortaleza', 'Completado', false),
            _buildScanItem('Detección de Duplicados', 'Programado', false),
          ],
        ),
      ),
    );
  }

  Widget _buildScanItem(String name, String status, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name)),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.green : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealth() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estado del Sistema',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildHealthItem('Base de Datos', 'Óptimo', Colors.green),
            _buildHealthItem('Conectividad', 'Buena', Colors.green),
            _buildHealthItem('Rendimiento', 'Normal', Colors.orange),
            _buildHealthItem('Almacenamiento', 'Disponible', Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem(String component, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(component)),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return RefreshIndicator(
      onRefresh: _loadMonitoringData,
      child: _alerts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay alertas activas'),
                  SizedBox(height: 8),
                  Text(
                    'Las alertas de seguridad aparecerán aquí',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                return _buildAlertCard(alert);
              },
            ),
    );
  }

  Widget _buildAlertCard(SecurityAlert alert) {
    final color = _getAlertColor(alert.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getAlertIcon(alert.type), color: color),
        ),
        title: Text(alert.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.description),
            const SizedBox(height: 4),
            Text(
              _formatAlertTime(alert.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: alert.isActive
            ? Icon(Icons.circle, color: color, size: 12)
            : const Icon(Icons.check_circle, color: Colors.grey, size: 12),
        onTap: () => _showAlertDetails(alert),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return FeatureGateWrapper(
      feature: PremiumFeature.securityHealth,
      featureGate: _featureGate,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHistorySection('Hoy', [
            'Escaneo de filtraciones completado - 14:30',
            'Contraseña débil detectada - 12:15',
            'Monitoreo iniciado - 09:00',
          ]),
          const SizedBox(height: 16),
          _buildHistorySection('Ayer', [
            'Alerta de duplicado resuelta - 18:45',
            'Escaneo programado ejecutado - 15:00',
            'Nueva filtración detectada - 11:30',
          ]),
          const SizedBox(height: 16),
          _buildHistorySection('Esta Semana', [
            'Reporte semanal generado',
            '5 alertas procesadas',
            '12 escaneos completados',
            '2 amenazas mitigadas',
          ]),
        ],
      ),
    );
  }

  Widget _buildHistorySection(String title, List<String> events) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(event, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusDescription() {
    switch (_status) {
      case SecurityMonitoringStatus.active:
        return 'Activo - Monitoreando continuamente';
      case SecurityMonitoringStatus.paused:
        return 'Pausado - Monitoreo suspendido';
      case SecurityMonitoringStatus.inactive:
        return 'Inactivo - Monitoreo deshabilitado';
      case SecurityMonitoringStatus.error:
        return 'Error - Problema en el sistema';
    }
  }

  String _getLastCheckTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Color _getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.high:
        return Colors.orange;
      case AlertSeverity.medium:
        return Colors.amber;
      case AlertSeverity.low:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.breach:
        return Icons.dangerous;
      case AlertType.weakPassword:
        return Icons.warning;
      case AlertType.duplicate:
        return Icons.content_copy;
      case AlertType.suspicious:
        return Icons.security;
      case AlertType.system:
        return Icons.settings;
    }
  }

  String _formatAlertTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else {
      return 'Hace ${difference.inDays} días';
    }
  }

  Future<void> _toggleMonitoring() async {
    try {
      // Mock toggle for now
      if (_status == SecurityMonitoringStatus.active) {
        setState(() {
          _status = SecurityMonitoringStatus.paused;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Monitoreo pausado'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _status = SecurityMonitoringStatus.active;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Monitoreo activado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showMonitoringSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuración de Monitoreo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Monitoreo Automático'),
              subtitle: const Text('Escanear automáticamente cada hora'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('Notificaciones Push'),
              subtitle: const Text('Recibir alertas inmediatas'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: const Text('Reportes Semanales'),
              subtitle: const Text('Resumen semanal por email'),
              value: false,
              onChanged: (value) {},
            ),
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
                  content: Text('Configuración guardada'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showAlertDetails(SecurityAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert.description),
            const SizedBox(height: 16),
            Text(
              'Severidad: ${alert.severity.name.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getAlertColor(alert.severity),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Detectado: ${_formatAlertTime(alert.timestamp)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (alert.affectedAccounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Cuentas afectadas: ${alert.affectedAccounts.length}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (alert.isActive)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Handle alert action
              },
              child: const Text('Resolver'),
            ),
        ],
      ),
    );
  }
}
