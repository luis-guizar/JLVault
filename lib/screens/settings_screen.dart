import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../widgets/theme_settings_widget.dart';
import '../widgets/haptic_feedback_settings_widget.dart';

/// Settings screen for app configuration and preferences
class SettingsScreen extends StatelessWidget {
  final ThemeService themeService;

  const SettingsScreen({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración'), elevation: 0),
      body: ListView(
        children: [
          // Theme settings section
          _buildSectionHeader(context, 'Apariencia'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ThemeSettingsWidget(themeService: themeService),
          ),

          // Haptic feedback settings section
          _buildSectionHeader(context, 'Interacción'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const HapticFeedbackSettingsWidget(),
          ),

          // App info section
          _buildSectionHeader(context, 'Información de la aplicación'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Versión'),
                  subtitle: const Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Privacidad y seguridad'),
                  subtitle: const Text(
                    'Todos los datos se almacenan localmente',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Código abierto'),
                  subtitle: const Text('Simple Vault es software libre'),
                  onTap: () => _showOpenSourceInfo(context),
                ),
              ],
            ),
          ),

          // Advanced settings section
          _buildSectionHeader(context, 'Configuración avanzada'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('Almacenamiento'),
                  subtitle: const Text('Gestionar datos locales'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showStorageInfo(context),
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Información de depuración'),
                  subtitle: const Text('Información técnica del sistema'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDebugInfo(context),
                ),
              ],
            ),
          ),

          // Add some bottom padding
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Build section header
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Show open source information
  void _showOpenSourceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código abierto'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Simple Vault es una aplicación de código abierto que prioriza tu privacidad y seguridad.',
            ),
            SizedBox(height: 16),
            Text(
              'Características principales:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• Almacenamiento local seguro'),
            Text('• Cifrado AES-256'),
            Text('• Sin conexión a internet requerida'),
            Text('• Sincronización P2P opcional'),
            Text('• Autenticación biométrica'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Show storage information
  void _showStorageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de almacenamiento'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Todos tus datos se almacenan de forma segura en tu dispositivo:',
            ),
            SizedBox(height: 16),
            Text('• Base de datos SQLite cifrada'),
            Text('• Claves almacenadas en Android Keystore'),
            Text('• Sin sincronización en la nube'),
            Text('• Respaldos locales opcionales'),
            SizedBox(height: 16),
            Text(
              'Tus datos nunca salen de tu dispositivo a menos que uses la función de sincronización P2P.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Show debug information
  void _showDebugInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de depuración'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDebugItem('Flutter Version', 'Flutter 3.x'),
            _buildDebugItem('Dart Version', 'Dart 3.x'),
            _buildDebugItem('Material Design', 'Material 3'),
            _buildDebugItem(
              'Dynamic Color',
              themeService.supportsDynamicColor ? 'Soportado' : 'No soportado',
            ),
            _buildDebugItem(
              'Theme Mode',
              _getThemeModeText(themeService.themeMode),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta información puede ser útil para reportar problemas.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Build debug information item
  Widget _buildDebugItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Get theme mode text
  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Automático';
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
    }
  }
}
