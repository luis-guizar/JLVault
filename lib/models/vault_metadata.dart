import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Metadata for a password vault
class VaultMetadata {
  final String id;
  final String name;
  final String iconName;
  final Color color;
  final DateTime createdAt;
  final DateTime lastAccessedAt;
  final int passwordCount;
  final double securityScore;

  const VaultMetadata({
    required this.id,
    required this.name,
    required this.iconName,
    required this.color,
    required this.createdAt,
    required this.lastAccessedAt,
    this.passwordCount = 0,
    this.securityScore = 0.0,
  });

  /// Creates a new vault with generated ID and current timestamps
  factory VaultMetadata.create({
    required String name,
    required String iconName,
    required Color color,
  }) {
    final now = DateTime.now();
    return VaultMetadata(
      id: const Uuid().v4(),
      name: name,
      iconName: iconName,
      color: color,
      createdAt: now,
      lastAccessedAt: now,
      passwordCount: 0,
      securityScore: 0.0,
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
    );
  }

  /// Converts to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'color': color.value,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
      'passwordCount': passwordCount,
      'securityScore': securityScore,
    };
  }

  /// Creates from JSON map
  factory VaultMetadata.fromJson(Map<String, dynamic> json) {
    return VaultMetadata(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['iconName'] as String,
      color: Color(json['color'] as int),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
      passwordCount: json['passwordCount'] as int? ?? 0,
      securityScore: (json['securityScore'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts to Map (alias for toJson for compatibility)
  Map<String, dynamic> toMap() => toJson();

  /// Creates from Map (alias for fromJson for compatibility)
  factory VaultMetadata.fromMap(Map<String, dynamic> map) =>
      VaultMetadata.fromJson(map);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VaultMetadata && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VaultMetadata(id: $id, name: $name, passwordCount: $passwordCount)';
  }
}
