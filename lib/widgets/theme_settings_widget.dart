import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Widget for managing theme settings and preferences
class ThemeSettingsWidget extends StatelessWidget {
  final ThemeService themeService;

  const ThemeSettingsWidget({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme mode selection
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema de la aplicación'),
              subtitle: Text(_getThemeModeDescription(themeService.themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeModeDialog(context),
            ),

            // Material You indicator (if supported)
            if (themeService.supportsDynamicColor)
              ListTile(
                leading: Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Material You'),
                subtitle: const Text('Colores dinámicos del sistema activados'),
                trailing: Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

            // Theme preview cards
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista previa del tema',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildThemePreview(context),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build theme preview cards
  Widget _buildThemePreview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primary colors
            Row(
              children: [
                _buildColorSwatch(
                  'Primario',
                  colorScheme.primary,
                  colorScheme.onPrimary,
                ),
                const SizedBox(width: 12),
                _buildColorSwatch(
                  'Secundario',
                  colorScheme.secondary,
                  colorScheme.onSecondary,
                ),
                const SizedBox(width: 12),
                _buildColorSwatch(
                  'Terciario',
                  colorScheme.tertiary,
                  colorScheme.onTertiary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sample UI elements
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Botón principal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text('Botón secundario'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sample text field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Campo de texto',
                hintText: 'Ejemplo de entrada',
                prefixIcon: Icon(Icons.search),
              ),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }

  /// Build color swatch preview
  Widget _buildColorSwatch(String label, Color color, Color onColor) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: onColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Show theme mode selection dialog
  void _showThemeModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar tema'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return ListTile(
              leading: Radio<ThemeMode>(
                value: mode,
                groupValue: themeService.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeService.setThemeMode(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Text(_getThemeModeTitle(mode)),
              subtitle: Text(_getThemeModeDescription(mode)),
              onTap: () {
                themeService.setThemeMode(mode);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Get theme mode title
  String _getThemeModeTitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Automático';
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
    }
  }

  /// Get theme mode description
  String _getThemeModeDescription(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Sigue la configuración del sistema';
      case ThemeMode.light:
        return 'Tema claro siempre';
      case ThemeMode.dark:
        return 'Tema oscuro siempre';
    }
  }
}
