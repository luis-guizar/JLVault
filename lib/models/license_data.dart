/// Represents license data stored locally
class LicenseData {
  final String licenseKey;
  final DateTime purchaseDate;
  final DateTime? expirationDate; // null for lifetime licenses
  final LicenseType type;
  final String platformPurchaseId;
  final DateTime lastValidated;
  final Map<String, dynamic> platformSpecificData;

  const LicenseData({
    required this.licenseKey,
    required this.purchaseDate,
    this.expirationDate,
    required this.type,
    required this.platformPurchaseId,
    required this.lastValidated,
    this.platformSpecificData = const {},
  });

  /// Creates LicenseData from JSON map
  factory LicenseData.fromJson(Map<String, dynamic> json) {
    return LicenseData(
      licenseKey: json['licenseKey'] as String,
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      type: LicenseType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LicenseType.lifetime,
      ),
      platformPurchaseId: json['platformPurchaseId'] as String,
      lastValidated: DateTime.parse(json['lastValidated'] as String),
      platformSpecificData: Map<String, dynamic>.from(
        json['platformSpecificData'] as Map? ?? {},
      ),
    );
  }

  /// Converts LicenseData to JSON map
  Map<String, dynamic> toJson() {
    return {
      'licenseKey': licenseKey,
      'purchaseDate': purchaseDate.toIso8601String(),
      'expirationDate': expirationDate?.toIso8601String(),
      'type': type.name,
      'platformPurchaseId': platformPurchaseId,
      'lastValidated': lastValidated.toIso8601String(),
      'platformSpecificData': platformSpecificData,
    };
  }

  /// Creates a copy with updated fields
  LicenseData copyWith({
    String? licenseKey,
    DateTime? purchaseDate,
    DateTime? expirationDate,
    LicenseType? type,
    String? platformPurchaseId,
    DateTime? lastValidated,
    Map<String, dynamic>? platformSpecificData,
  }) {
    return LicenseData(
      licenseKey: licenseKey ?? this.licenseKey,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expirationDate: expirationDate ?? this.expirationDate,
      type: type ?? this.type,
      platformPurchaseId: platformPurchaseId ?? this.platformPurchaseId,
      lastValidated: lastValidated ?? this.lastValidated,
      platformSpecificData: platformSpecificData ?? this.platformSpecificData,
    );
  }

  /// Checks if the license is expired
  bool get isExpired {
    if (expirationDate == null) return false; // Lifetime license
    return DateTime.now().isAfter(expirationDate!);
  }

  /// Checks if the license needs validation (older than 24 hours)
  bool get needsValidation {
    final daysSinceValidation = DateTime.now().difference(lastValidated).inDays;
    return daysSinceValidation >= 1;
  }
}

/// Types of licenses available
enum LicenseType {
  /// Trial license with limited time
  trial,

  /// One-time purchase lifetime license
  lifetime,

  /// Subscription license (for future use)
  subscription,
}
