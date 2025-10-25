import 'license_manager.dart';
import 'android_license_manager.dart';

/// Factory class to create the Android license manager
class LicenseManagerFactory {
  static LicenseManager? _instance;

  /// Gets the singleton instance of the Android license manager
  static LicenseManager getInstance() {
    _instance ??= AndroidLicenseManager();
    return _instance!;
  }

  /// Resets the singleton instance (useful for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }
}
