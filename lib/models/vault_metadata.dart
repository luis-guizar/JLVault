import 'package:flutter/material.dart';

/// Represents metadata for a vault including display information and statistics
class VaultMetadata {
  final String id;
  final String name;
  final String iconName;
  final Color color;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final int passwordCount;
  final double securityScore;
  final bool isDefault;

  const VaultMetadata({
    required this.id,
    required this.name,
    required this.iconName,
    required this.color,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.passwordCount,
    required this.securityScore,
    this.isDefault = false,
  });

  /// Creates a new vault metadata instance
  factory VaultMetadata.create({
    required String name,
    required String iconName,
    required Color color,
    bool isDefault = false,
  }) {
    final now = DateTime.now();
    return VaultMetadata(
      id: _generateId(),
      name: name,
      iconName: iconName,
      color: color,
      createdAt: now,
      lastAccessedAt: now,
      passwordCount: 0,
      securityScore: 100.0,
      isDefault: isDefault,
    );
  }

  /// Creates a copy with updated fields
  VaultMetadata copyWith({
    String? id,
    String? name,
    String? iconName,
    Color? color,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    int? passwordCount,
    double? securityScore,
    bool? isDefault,
  }) {
    return VaultMetadata(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      passwordCount: passwordCount ?? this.passwordCount,
      securityScore: securityScore ?? this.securityScore,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// Converts to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'color': color.value,
      'created_at': createdAt.millisecondsSinceEpoch,
      'last_accessed_at': lastAccessedAt.millisecondsSinceEpoch,
      'password_count': passwordCount,
      'security_score': securityScore,
      'is_default': isDefault ? 1 : 0,
    };
  }

  /// Creates from database map
  factory VaultMetadata.fromMap(Map<String, dynamic> map) {
    return VaultMetadata(
      id: map['id'] as String,
      name: map['name'] as String,
      iconName: map['icon_name'] as String,
      color: Color(map['color'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(
        map['last_accessed_at'] as int,
      ),
      passwordCount: map['password_count'] as int,
      securityScore: (map['security_score'] as num).toDouble(),
      isDefault: (map['is_default'] as int) == 1,
    );
  }

  /// Generates a unique ID for the vault
  static String _generateId() {
    return 'vault_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VaultMetadata && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VaultMetadata(id: $id, name: $name, passwordCount: $passwordCount, securityScore: $securityScore)';
  }
}

/// Available vault icons
class VaultIcons {
  static const List<String> available = [
    'lock',
    'work',
    'home',
    'family',
    'travel',
    'shopping',
    'gaming',
    'social',
    'finance',
    'health',
    'education',
    'business',
  ];

  /// Gets the Flutter icon for a given icon name
  static IconData getIcon(String iconName) {
    switch (iconName) {
      case 'lock':
        return Icons.lock;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      case 'family':
        return Icons.family_restroom;
      case 'travel':
        return Icons.flight;
      case 'shopping':
        return Icons.shopping_cart;
      case 'gaming':
        return Icons.games;
      case 'social':
        return Icons.people;
      case 'finance':
        return Icons.account_balance;
      case 'health':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'business':
        return Icons.business;
      default:
        return Icons.lock;
    }
  }
}

/// Predefined vault colors
class VaultColors {
  static const List<Color> available = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
  ];
}
