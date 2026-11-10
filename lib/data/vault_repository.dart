import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/data/vault_store.dart';

class VaultUnreadable implements Exception {
  const VaultUnreadable();
}

class VaultRepository {
  VaultRepository({required this.store, this.iterations = 120000});

  final VaultStore store;
  final int iterations;

  final AesGcm _aes = AesGcm.with256bits();
  SecretKey? _key;
  Uint8List? _salt;
  int? _openIterations;

  bool get isOpen => _key != null;

  Future<List<VaultItem>> open(String password) async {
    final raw = await store.read();
    if (raw == null || raw.trim().isEmpty) {
      _salt = _randomBytes(16);
      _openIterations = iterations;
      _key = await _derive(password, _salt!, iterations);
      await persist(const []);
      return [];
    }

    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map) throw const VaultUnreadable();
      final salt = base64Decode(envelope['salt'] as String);
      final fileIterations = envelope['iterations'] as int? ?? iterations;
      final key = await _derive(password, salt, fileIterations);
      final box = SecretBox(
        base64Decode(envelope['ciphertext'] as String),
        nonce: base64Decode(envelope['nonce'] as String),
        mac: Mac(base64Decode(envelope['mac'] as String)),
      );
      final clear = await _aes.decrypt(box, secretKey: key);
      final items = decodeVaultItems(utf8.decode(clear));
      _key = key;
      _salt = Uint8List.fromList(salt);
      _openIterations = fileIterations;
      return items;
    } catch (error) {
      _key = null;
      _salt = null;
      _openIterations = null;
      if (error is VaultUnreadable) rethrow;
      throw const VaultUnreadable();
    }
  }

  Future<void> persist(List<VaultItem> items) async {
    final key = _key;
    final salt = _salt;
    final rounds = _openIterations;
    if (key == null || salt == null || rounds == null) {
      throw StateError('The vault is locked.');
    }
    final box = await _aes.encrypt(
      utf8.encode(encodeVaultItems(items)),
      secretKey: key,
    );
    final envelope = jsonEncode({
      'version': 1,
      'kdf': 'pbkdf2-sha256',
      'iterations': rounds,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'ciphertext': base64Encode(box.cipherText),
    });
    await store.write(envelope);
  }

  void lock() {
    _key = null;
    _salt = null;
    _openIterations = null;
  }

  Future<void> deleteAll() async {
    lock();
    await store.delete();
  }

  Future<SecretKey> _derive(String password, List<int> salt, int rounds) {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    );
    return algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}
