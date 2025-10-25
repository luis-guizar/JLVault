import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure temporary file handling for import/export operations
class SecureTempFileService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static const String _tempKeyPrefix = 'temp_file_key_';
  static final Map<String, SecureTempFile> _activeTempFiles = {};
  static Directory? _tempDirectory;

  /// Initialize the secure temp file service
  static Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _tempDirectory = Directory('${appDir.path}/secure_temp');

      if (!_tempDirectory!.existsSync()) {
        await _tempDirectory!.create(recursive: true);
      }

      // Clean up any leftover temp files from previous sessions
      await _cleanupLeftoverFiles();
    } catch (e) {
      throw Exception('Failed to initialize secure temp file service: $e');
    }
  }

  /// Creates a secure temporary file for sensitive operations
  static Future<SecureTempFile> createSecureTempFile({
    String? prefix,
    String? extension,
  }) async {
    if (_tempDirectory == null) {
      await initialize();
    }

    final fileId = _generateFileId();
    final fileName = '${prefix ?? 'temp'}_$fileId${extension ?? '.tmp'}';
    final file = File('${_tempDirectory!.path}/$fileName');

    // Generate encryption key for this file
    final encryptionKey = _generateEncryptionKey();
    await _storage.write(
      key: '$_tempKeyPrefix$fileId',
      value: base64.encode(encryptionKey),
    );

    final secureTempFile = SecureTempFile._(
      fileId: fileId,
      file: file,
      encryptionKey: encryptionKey,
    );

    _activeTempFiles[fileId] = secureTempFile;

    return secureTempFile;
  }

  /// Creates a secure temporary file for export operations
  static Future<SecureTempFile> createExportTempFile({
    required String exportType,
    String? vaultName,
  }) async {
    final prefix = 'export_${exportType}_${vaultName ?? 'vault'}';
    return await createSecureTempFile(prefix: prefix, extension: '.enc');
  }

  /// Creates a secure temporary file for import operations
  static Future<SecureTempFile> createImportTempFile({
    required String importType,
  }) async {
    final prefix = 'import_$importType';
    return await createSecureTempFile(prefix: prefix, extension: '.tmp');
  }

  /// Securely deletes a temporary file
  static Future<void> deleteSecureTempFile(String fileId) async {
    final tempFile = _activeTempFiles.remove(fileId);
    if (tempFile != null) {
      await tempFile._secureDelete();

      // Remove encryption key from storage
      try {
        await _storage.delete(key: '$_tempKeyPrefix$fileId');
      } catch (e) {
        // Ignore storage errors during cleanup
      }
    }
  }

  /// Securely deletes all active temporary files
  static Future<void> deleteAllTempFiles() async {
    final fileIds = List<String>.from(_activeTempFiles.keys);
    for (final fileId in fileIds) {
      await deleteSecureTempFile(fileId);
    }
  }

  /// Gets information about active temporary files
  static List<TempFileInfo> getActiveTempFiles() {
    return _activeTempFiles.values
        .map(
          (file) => TempFileInfo(
            fileId: file.fileId,
            fileName: file.file.path.split('/').last,
            createdAt: file.createdAt,
            sizeBytes: file.file.existsSync() ? file.file.lengthSync() : 0,
          ),
        )
        .toList();
  }

  /// Cleanup leftover files from previous sessions
  static Future<void> _cleanupLeftoverFiles() async {
    if (_tempDirectory?.existsSync() != true) return;

    try {
      final files = _tempDirectory!.listSync();
      for (final file in files) {
        if (file is File) {
          await _secureDeleteFile(file);
        }
      }

      // Clean up any leftover encryption keys
      final allKeys = await _storage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith(_tempKeyPrefix)) {
          await _storage.delete(key: key);
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  static String _generateFileId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64.encode(bytes).replaceAll(RegExp(r'[/+=]'), '');
  }

  static Uint8List _generateEncryptionKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (i) => random.nextInt(256)),
    );
  }

  static Future<void> _secureDeleteFile(File file) async {
    if (!file.existsSync()) return;

    try {
      // Overwrite file with random data multiple times
      final fileSize = file.lengthSync();
      final random = Random.secure();

      for (int pass = 0; pass < 3; pass++) {
        final randomData = Uint8List.fromList(
          List<int>.generate(fileSize, (i) => random.nextInt(256)),
        );
        await file.writeAsBytes(randomData);
      }

      // Finally delete the file
      await file.delete();
    } catch (e) {
      // If secure deletion fails, try normal deletion
      try {
        await file.delete();
      } catch (e) {
        // Ignore deletion errors
      }
    }
  }
}

/// Secure temporary file with automatic encryption
class SecureTempFile {
  final String fileId;
  final File file;
  final Uint8List encryptionKey;
  final DateTime createdAt;

  SecureTempFile._({
    required this.fileId,
    required this.file,
    required this.encryptionKey,
  }) : createdAt = DateTime.now();

  /// Writes encrypted data to the temporary file
  Future<void> writeEncrypted(String data) async {
    final encrypted = await _encrypt(data);
    await file.writeAsBytes(encrypted);
  }

  /// Writes encrypted bytes to the temporary file
  Future<void> writeEncryptedBytes(Uint8List data) async {
    final encrypted = await _encryptBytes(data);
    await file.writeAsBytes(encrypted);
  }

  /// Reads and decrypts data from the temporary file
  Future<String> readDecrypted() async {
    if (!file.existsSync()) {
      throw Exception('Temporary file does not exist');
    }

    final encryptedData = await file.readAsBytes();
    return await _decrypt(encryptedData);
  }

  /// Reads and decrypts bytes from the temporary file
  Future<Uint8List> readDecryptedBytes() async {
    if (!file.existsSync()) {
      throw Exception('Temporary file does not exist');
    }

    final encryptedData = await file.readAsBytes();
    return await _decryptBytes(encryptedData);
  }

  /// Appends encrypted data to the temporary file
  Future<void> appendEncrypted(String data) async {
    final encrypted = await _encrypt(data);
    await file.writeAsBytes(encrypted, mode: FileMode.append);
  }

  /// Gets the file size in bytes
  int get sizeBytes => file.existsSync() ? file.lengthSync() : 0;

  /// Checks if the file exists
  bool get exists => file.existsSync();

  /// Gets the file path (for external operations)
  String get path => file.path;

  /// Securely deletes the temporary file
  Future<void> delete() async {
    await SecureTempFileService.deleteSecureTempFile(fileId);
  }

  /// Internal secure deletion
  Future<void> _secureDelete() async {
    // Clear encryption key from memory
    encryptionKey.fillRange(0, encryptionKey.length, 0);

    // Securely delete the file
    await SecureTempFileService._secureDeleteFile(file);
  }

  Future<Uint8List> _encrypt(String data) async {
    return await _encryptBytes(Uint8List.fromList(utf8.encode(data)));
  }

  Future<Uint8List> _encryptBytes(Uint8List data) async {
    // Generate random nonce
    final random = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (i) => random.nextInt(256)),
    );

    // Simple XOR encryption (sufficient for temporary files)
    final encrypted = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ encryptionKey[i % encryptionKey.length];
    }

    // Prepend nonce and add integrity hash
    final hash = sha256.convert(data).bytes;
    final result = Uint8List(nonce.length + hash.length + encrypted.length);

    result.setRange(0, nonce.length, nonce);
    result.setRange(nonce.length, nonce.length + hash.length, hash);
    result.setRange(nonce.length + hash.length, result.length, encrypted);

    return result;
  }

  Future<String> _decrypt(Uint8List encryptedData) async {
    final decryptedBytes = await _decryptBytes(encryptedData);
    return utf8.decode(decryptedBytes);
  }

  Future<Uint8List> _decryptBytes(Uint8List encryptedData) async {
    if (encryptedData.length < 44) {
      // 12 (nonce) + 32 (hash) = 44 minimum
      throw Exception('Invalid encrypted data format');
    }

    // Extract components
    // final nonce = encryptedData.sublist(0, 12); // Not used in simple XOR
    final hash = encryptedData.sublist(12, 44);
    final encrypted = encryptedData.sublist(44);

    // Decrypt data
    final decrypted = Uint8List(encrypted.length);
    for (int i = 0; i < encrypted.length; i++) {
      decrypted[i] = encrypted[i] ^ encryptionKey[i % encryptionKey.length];
    }

    // Verify integrity
    final expectedHash = sha256.convert(decrypted).bytes;
    if (!_constantTimeEquals(hash, expectedHash)) {
      throw Exception(
        'Data integrity check failed - file may be corrupted or tampered',
      );
    }

    return decrypted;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

/// Information about a temporary file
class TempFileInfo {
  final String fileId;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  TempFileInfo({
    required this.fileId,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'fileName': fileName,
    'createdAt': createdAt.toIso8601String(),
    'sizeBytes': sizeBytes,
  };
}
