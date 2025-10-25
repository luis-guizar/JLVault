import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for managing Android haptic feedback with contextual vibration patterns
class HapticFeedbackService {
  static const String _hapticPreferenceKey = 'haptic_feedback_enabled';
  static const String _hapticIntensityKey = 'haptic_feedback_intensity';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static bool _isEnabled = true;
  static HapticIntensity _intensity = HapticIntensity.medium;

  /// Initialize haptic feedback service
  static Future<void> initialize() async {
    await _loadPreferences();
  }

  /// Load haptic feedback preferences
  static Future<void> _loadPreferences() async {
    try {
      final enabledStr = await _storage.read(key: _hapticPreferenceKey);
      _isEnabled = enabledStr != 'false';

      final intensityStr = await _storage.read(key: _hapticIntensityKey);
      if (intensityStr != null) {
        _intensity = HapticIntensity.values.firstWhere(
          (intensity) => intensity.toString() == intensityStr,
          orElse: () => HapticIntensity.medium,
        );
      }
    } catch (e) {
      // Use defaults if there's an error
      _isEnabled = true;
      _intensity = HapticIntensity.medium;
    }
  }

  /// Set haptic feedback enabled state
  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _storage.write(key: _hapticPreferenceKey, value: enabled.toString());
  }

  /// Set haptic feedback intensity
  static Future<void> setIntensity(HapticIntensity intensity) async {
    _intensity = intensity;
    await _storage.write(key: _hapticIntensityKey, value: intensity.toString());
  }

  /// Get current enabled state
  static bool get isEnabled => _isEnabled;

  /// Get current intensity
  static HapticIntensity get intensity => _intensity;

  // Button press feedback
  static Future<void> buttonPress() async {
    if (!_isEnabled) return;

    switch (_intensity) {
      case HapticIntensity.light:
        await HapticFeedback.selectionClick();
        break;
      case HapticIntensity.medium:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.strong:
        await HapticFeedback.mediumImpact();
        break;
    }
  }

  // Selection feedback (for list items, radio buttons, etc.)
  static Future<void> selection() async {
    if (!_isEnabled) return;
    await HapticFeedback.selectionClick();
  }

  // Success feedback (for completed actions)
  static Future<void> success() async {
    if (!_isEnabled) return;

    switch (_intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.strong:
        await HapticFeedback.heavyImpact();
        break;
    }
  }

  // Error feedback (for errors, validation failures)
  static Future<void> error() async {
    if (!_isEnabled) return;

    // Use heavy impact for errors regardless of intensity setting
    await HapticFeedback.heavyImpact();
  }

  // Warning feedback (for warnings, confirmations)
  static Future<void> warning() async {
    if (!_isEnabled) return;

    switch (_intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
      case HapticIntensity.strong:
        await HapticFeedback.mediumImpact();
        break;
    }
  }

  // TOTP code generation feedback
  static Future<void> totpGenerated() async {
    if (!_isEnabled) return;

    // Light feedback for TOTP generation
    await HapticFeedback.selectionClick();
  }

  // TOTP code expiring warning (when <10 seconds remaining)
  static Future<void> totpExpiring() async {
    if (!_isEnabled) return;

    // Medium impact for expiring warning
    await HapticFeedback.mediumImpact();
  }

  // Security alert feedback (for security dashboard alerts)
  static Future<void> securityAlert() async {
    if (!_isEnabled) return;

    // Heavy impact for security alerts
    await HapticFeedback.heavyImpact();
  }

  // Vault switching feedback
  static Future<void> vaultSwitch() async {
    if (!_isEnabled) return;

    switch (_intensity) {
      case HapticIntensity.light:
        await HapticFeedback.selectionClick();
        break;
      case HapticIntensity.medium:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.strong:
        await HapticFeedback.mediumImpact();
        break;
    }
  }

  // Copy to clipboard feedback
  static Future<void> copyToClipboard() async {
    if (!_isEnabled) return;

    // Light feedback for copy actions
    await HapticFeedback.selectionClick();
  }

  // Long press feedback
  static Future<void> longPress() async {
    if (!_isEnabled) return;

    switch (_intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
        await HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.strong:
        await HapticFeedback.heavyImpact();
        break;
    }
  }

  // Swipe gesture feedback
  static Future<void> swipe() async {
    if (!_isEnabled) return;
    await HapticFeedback.selectionClick();
  }

  // Pull to refresh feedback
  static Future<void> pullToRefresh() async {
    if (!_isEnabled) return;

    switch (_intensity) {
      case HapticIntensity.light:
        await HapticFeedback.lightImpact();
        break;
      case HapticIntensity.medium:
      case HapticIntensity.strong:
        await HapticFeedback.mediumImpact();
        break;
    }
  }
}

/// Haptic feedback intensity levels
enum HapticIntensity {
  light,
  medium,
  strong;

  String get displayName {
    switch (this) {
      case HapticIntensity.light:
        return 'Suave';
      case HapticIntensity.medium:
        return 'Medio';
      case HapticIntensity.strong:
        return 'Fuerte';
    }
  }

  String get description {
    switch (this) {
      case HapticIntensity.light:
        return 'Vibración ligera para acciones básicas';
      case HapticIntensity.medium:
        return 'Vibración moderada para la mayoría de acciones';
      case HapticIntensity.strong:
        return 'Vibración fuerte para acciones importantes';
    }
  }
}
