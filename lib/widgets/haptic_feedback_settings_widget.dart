import 'package:flutter/material.dart';
import '../services/haptic_feedback_service.dart';

/// Widget for managing haptic feedback settings
class HapticFeedbackSettingsWidget extends StatefulWidget {
  const HapticFeedbackSettingsWidget({super.key});

  @override
  State<HapticFeedbackSettingsWidget> createState() =>
      _HapticFeedbackSettingsWidgetState();
}

class _HapticFeedbackSettingsWidgetState
    extends State<HapticFeedbackSettingsWidget> {
  bool _isEnabled = true;
  HapticIntensity _intensity = HapticIntensity.medium;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _isEnabled = HapticFeedbackService.isEnabled;
      _intensity = HapticFeedbackService.intensity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Haptic feedback toggle
        ListTile(
          leading: const Icon(Icons.vibration),
          title: const Text('Vibración háptica'),
          subtitle: const Text(
            'Vibración al tocar botones y realizar acciones',
          ),
          trailing: Switch(
            value: _isEnabled,
            onChanged: (value) async {
              await HapticFeedbackService.setEnabled(value);
              setState(() {
                _isEnabled = value;
              });

              // Provide feedback when enabling
              if (value) {
                await HapticFeedbackService.buttonPress();
              }
            },
          ),
        ),

        // Intensity settings (only show if enabled)
        if (_isEnabled) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              'Intensidad de vibración',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          // Intensity options
          ...HapticIntensity.values.map((intensity) {
            return ListTile(
              leading: Radio<HapticIntensity>(
                value: intensity,
                groupValue: _intensity,
                onChanged: (value) async {
                  if (value != null) {
                    await HapticFeedbackService.setIntensity(value);
                    setState(() {
                      _intensity = value;
                    });

                    // Provide feedback with the new intensity
                    await HapticFeedbackService.buttonPress();
                  }
                },
              ),
              title: Text(intensity.displayName),
              subtitle: Text(intensity.description),
              onTap: () async {
                await HapticFeedbackService.setIntensity(intensity);
                setState(() {
                  _intensity = intensity;
                });

                // Provide feedback with the new intensity
                await HapticFeedbackService.buttonPress();
              },
            );
          }),

          const Divider(),

          // Test haptic feedback section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Probar vibración',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTestButton(
                      context,
                      'Botón',
                      Icons.touch_app,
                      HapticFeedbackService.buttonPress,
                    ),
                    _buildTestButton(
                      context,
                      'Éxito',
                      Icons.check_circle,
                      HapticFeedbackService.success,
                    ),
                    _buildTestButton(
                      context,
                      'Error',
                      Icons.error,
                      HapticFeedbackService.error,
                    ),
                    _buildTestButton(
                      context,
                      'Advertencia',
                      Icons.warning,
                      HapticFeedbackService.warning,
                    ),
                    _buildTestButton(
                      context,
                      'TOTP',
                      Icons.security,
                      HapticFeedbackService.totpGenerated,
                    ),
                    _buildTestButton(
                      context,
                      'Cambio de bóveda',
                      Icons.folder,
                      HapticFeedbackService.vaultSwitch,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    String label,
    IconData icon,
    Future<void> Function() onPressed,
  ) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
