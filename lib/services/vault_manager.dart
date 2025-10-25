import 'package:flutter/material.dart';
import '../models/vault_metadata.dart';
import '../data/vault_db_helper.dart';

/// Abstract interface for vault management operations
abstract class VaultManager {
  /// Gets all available vaults
  Future<List<VaultMetadata>> getVaults();

  /// Gets the currently active vault
  Future<VaultMetadata?> getActiveVault();

  /// Creates a new vault with the specified metadata
  Future<VaultMetadata> createVault({
    required String name,
    required String iconName,
    required Color color,
  });

  /// Updates vault metadata
  Future<void> updateVault(VaultMetadata vault);

  /// Switches to the specified vault
  Future<void> switchToVault(String vaultId);

  /// Deletes a vault and all its data
  Future<void> deleteVault(String vaultId);

  /// Updates vault statistics (password count, security score)
  Future<void> updateVaultStatistics(
    String vaultId, {
    int? passwordCount,
    double? securityScore,
  });

  /// Gets vault by ID
  Future<VaultMetadata?> getVaultById(String vaultId);

  /// Checks if a vault name already exists
  Future<bool> vaultNameExists(String name, {String? excludeVaultId});
}

/// Default implementation of VaultManager
class DefaultVaultManager implements VaultManager {
  String? _activeVaultId;

  @override
  Future<List<VaultMetadata>> getVaults() async {
    return await VaultDbHelper.getAllVaults();
  }

  @override
  Future<VaultMetadata?> getActiveVault() async {
    if (_activeVaultId == null) {
      _activeVaultId = await VaultDbHelper.getActiveVaultId();
    }

    if (_activeVaultId == null) {
      // No active vault set, get the default vault or create one
      final vaults = await getVaults();
      if (vaults.isEmpty) {
        // Create default vault
        final defaultVault = await createVault(
          name: 'Personal',
          iconName: 'lock',
          color: Colors.blue,
        );
        await VaultDbHelper.setActiveVaultId(defaultVault.id);
        _activeVaultId = defaultVault.id;
        return defaultVault;
      } else {
        // Use first vault as active
        final firstVault = vaults.first;
        await VaultDbHelper.setActiveVaultId(firstVault.id);
        _activeVaultId = firstVault.id;
        return firstVault;
      }
    }

    return await getVaultById(_activeVaultId!);
  }

  @override
  Future<VaultMetadata> createVault({
    required String name,
    required String iconName,
    required Color color,
  }) async {
    // Check if name already exists
    if (await vaultNameExists(name)) {
      throw VaultException('A vault with the name "$name" already exists');
    }

    final vault = VaultMetadata.create(
      name: name,
      iconName: iconName,
      color: color,
    );

    await VaultDbHelper.insertVault(vault);
    return vault;
  }

  @override
  Future<void> updateVault(VaultMetadata vault) async {
    // Check if name already exists (excluding current vault)
    if (await vaultNameExists(vault.name, excludeVaultId: vault.id)) {
      throw VaultException(
        'A vault with the name "${vault.name}" already exists',
      );
    }

    await VaultDbHelper.updateVault(vault);
  }

  @override
  Future<void> switchToVault(String vaultId) async {
    final vault = await getVaultById(vaultId);
    if (vault == null) {
      throw VaultException('Vault with ID $vaultId not found');
    }

    // Update last accessed time
    final updatedVault = vault.copyWith(lastAccessedAt: DateTime.now());
    await VaultDbHelper.updateVault(updatedVault);

    // Set as active vault
    await VaultDbHelper.setActiveVaultId(vaultId);
    _activeVaultId = vaultId;
  }

  @override
  Future<void> deleteVault(String vaultId) async {
    final vaults = await getVaults();
    if (vaults.length <= 1) {
      throw VaultException('Cannot delete the last remaining vault');
    }

    final vault = await getVaultById(vaultId);
    if (vault == null) {
      throw VaultException('Vault with ID $vaultId not found');
    }

    // If deleting active vault, switch to another vault
    if (_activeVaultId == vaultId) {
      final otherVault = vaults.firstWhere((v) => v.id != vaultId);
      await switchToVault(otherVault.id);
    }

    // Delete vault and all its data
    await VaultDbHelper.deleteVault(vaultId);
  }

  @override
  Future<void> updateVaultStatistics(
    String vaultId, {
    int? passwordCount,
    double? securityScore,
  }) async {
    final vault = await getVaultById(vaultId);
    if (vault == null) {
      throw VaultException('Vault with ID $vaultId not found');
    }

    final updatedVault = vault.copyWith(
      passwordCount: passwordCount ?? vault.passwordCount,
      securityScore: securityScore ?? vault.securityScore,
    );

    await VaultDbHelper.updateVault(updatedVault);
  }

  @override
  Future<VaultMetadata?> getVaultById(String vaultId) async {
    return await VaultDbHelper.getVaultById(vaultId);
  }

  @override
  Future<bool> vaultNameExists(String name, {String? excludeVaultId}) async {
    final vaults = await getVaults();
    return vaults.any(
      (vault) =>
          vault.name.toLowerCase() == name.toLowerCase() &&
          vault.id != excludeVaultId,
    );
  }
}

/// Exception thrown by vault operations
class VaultException implements Exception {
  final String message;

  const VaultException(this.message);

  @override
  String toString() => 'VaultException: $message';
}
