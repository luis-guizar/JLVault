import 'totp_config.dart';

class Account {
  final int? id;
  final String name;
  final String username;
  final String password;
  final String? url;
  final String? notes;
  final String vaultId;
  final DateTime? createdAt;
  final DateTime? modifiedAt;
  final DateTime? lastUsedAt;
  final TOTPConfig? totpConfig;

  // Transient field for search relevance (not stored in database)
  double? relevanceScore;

  Account({
    this.id,
    required this.name,
    required this.username,
    required this.password,
    this.url,
    this.notes,
    required this.vaultId,
    this.createdAt,
    this.modifiedAt,
    this.lastUsedAt,
    this.totpConfig,
    this.relevanceScore,
  });

  Account copyWith({
    int? id,
    String? name,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? vaultId,
    DateTime? createdAt,
    DateTime? modifiedAt,
    DateTime? lastUsedAt,
    TOTPConfig? totpConfig,
    double? relevanceScore,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      vaultId: vaultId ?? this.vaultId,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      totpConfig: totpConfig ?? this.totpConfig,
      relevanceScore: relevanceScore ?? this.relevanceScore,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'username': username,
    'password': password,
    'url': url,
    'notes': notes,
    'vault_id': vaultId,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'modified_at': modifiedAt?.millisecondsSinceEpoch,
    'last_used_at': lastUsedAt?.millisecondsSinceEpoch,
    'totp_config': totpConfig?.toJson(),
  };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
    id: map['id'],
    name: map['name'],
    username: map['username'],
    password: map['password'],
    url: map['url'],
    notes: map['notes'],
    vaultId: map['vault_id'] ?? 'default', // Backward compatibility
    createdAt: map['created_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
        : null,
    modifiedAt: map['modified_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['modified_at'])
        : null,
    lastUsedAt: map['last_used_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['last_used_at'])
        : null,
    totpConfig: map['totp_config'] != null
        ? TOTPConfig.fromJson(map['totp_config'])
        : null,
  );
}
