import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:myvault/data/vault_item.dart';

const backupFileName = 'backup.json';
const defaultBackupIterations = 120000;

const _kind = 'myvault-backup';
const _kdf = 'pbkdf2-sha256';
const _maxIterations = 400000;

class VaultBackup {
  const VaultBackup({required this.assets, required this.notes});

  final List<VaultItem> assets;
  final List<VaultItem> notes;
}

sealed class OpenedBackup {
  const OpenedBackup();
}

class OpenedVaultBackup extends OpenedBackup {
  const OpenedVaultBackup(this.backup);

  final VaultBackup backup;
}

class RejectedBackup extends OpenedBackup {
  const RejectedBackup({required this.wrongPassword});

  /// True when the file is a backup envelope and the password does not match.
  final bool wrongPassword;
}

/// True when the bytes are a MyVault backup envelope. The password is not checked.
bool looksLikeVaultBackup(Uint8List bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return false;
    return decoded['version'] == 1 && decoded['kind'] == _kind;
  } catch (_) {
    return false;
  }
}

/// Encrypts assets and secure notes. The password is not written into the file.
Future<Uint8List> sealVaultBackup({
  required List<VaultItem> assets,
  required List<VaultItem> notes,
  required String password,
  int iterations = defaultBackupIterations,
}) async {
  if (iterations < 1 || iterations > _maxIterations) {
    throw ArgumentError.value(iterations, 'iterations');
  }
  final salt = _randomBytes(16);
  final secretKey = await _derive(password, salt, iterations);
  final inner = jsonEncode({
    'version': 1,
    'assets': assets.map((item) => item.toJson()).toList(),
    'notes': notes.map((item) => item.toJson()).toList(),
  });
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(inner),
    secretKey: secretKey,
  );
  final envelope = {
    'version': 1,
    'kind': _kind,
    'kdf': _kdf,
    'iterations': iterations,
    'salt': base64Encode(salt),
    'nonce': base64Encode(box.nonce),
    'mac': base64Encode(box.mac.bytes),
    'ciphertext': base64Encode(box.cipherText),
  };
  return Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(envelope)),
  );
}

Future<OpenedBackup> openVaultBackup({
  required Uint8List bytes,
  required String password,
}) async {
  final envelope = _envelope(bytes);
  if (envelope == null) return const RejectedBackup(wrongPassword: false);
  try {
    final secretKey = await _derive(
      password,
      envelope.salt,
      envelope.iterations,
    );
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        envelope.cipherText,
        nonce: envelope.nonce,
        mac: Mac(envelope.mac),
      ),
      secretKey: secretKey,
    );
    return OpenedVaultBackup(_payload(clear));
  } on SecretBoxAuthenticationError {
    return const RejectedBackup(wrongPassword: true);
  } catch (_) {
    return const RejectedBackup(wrongPassword: false);
  }
}

/// Backup rows replace the same id. Rows that exist only on the phone stay.
List<VaultItem> mergeVaultItems({
  required List<VaultItem> current,
  required List<VaultItem> incoming,
}) {
  final next = [...current];
  for (final item in incoming) {
    final index = next.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
  }
  return next;
}

Future<SecretKey> _derive(String password, List<int> salt, int iterations) {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  return algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
}

VaultBackup _payload(List<int> clear) {
  final decoded = jsonDecode(utf8.decode(clear));
  if (decoded is! Map) throw const FormatException('inner');
  final map = Map<String, dynamic>.from(decoded);
  if (map['version'] != 1) throw const FormatException('version');
  final assets = _items(map['assets'], VaultItemType.asset);
  final notes = _items(map['notes'], VaultItemType.secret);
  final ids = <String>{};
  for (final item in [...assets, ...notes]) {
    if (!ids.add(item.id)) throw const FormatException('id');
  }
  return VaultBackup(assets: assets, notes: notes);
}

List<VaultItem> _items(Object? raw, VaultItemType type) {
  if (raw is! List) throw const FormatException('items');
  return [for (final entry in raw) _item(entry, type)];
}

VaultItem _item(Object? raw, VaultItemType type) {
  if (raw is! Map) throw const FormatException('item');
  final json = raw is Map<String, dynamic> ? raw : raw.cast<String, dynamic>();
  final item = VaultItem.fromJson(json);
  if (item.type != type ||
      item.id.trim().isEmpty ||
      item.title.trim().isEmpty) {
    throw const FormatException('item');
  }
  return item;
}

class _Envelope {
  const _Envelope({
    required this.iterations,
    required this.salt,
    required this.nonce,
    required this.mac,
    required this.cipherText,
  });

  final int iterations;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List mac;
  final Uint8List cipherText;
}

_Envelope? _envelope(Uint8List bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded);
    if (map['version'] != 1 || map['kind'] != _kind || map['kdf'] != _kdf) {
      return null;
    }
    final iterations = map['iterations'];
    if (iterations is! int || iterations < 1 || iterations > _maxIterations) {
      return null;
    }
    final salt = _fixedBytes(map['salt'], 16);
    final nonce = _fixedBytes(map['nonce'], 12);
    final mac = _fixedBytes(map['mac'], 16);
    final cipherText = _bytes(map['ciphertext']);
    if (salt == null ||
        nonce == null ||
        mac == null ||
        cipherText == null ||
        cipherText.isEmpty) {
      return null;
    }
    return _Envelope(
      iterations: iterations,
      salt: salt,
      nonce: nonce,
      mac: mac,
      cipherText: cipherText,
    );
  } on FormatException {
    return null;
  }
}

Uint8List? _fixedBytes(Object? value, int length) {
  final bytes = _bytes(value);
  if (bytes == null || bytes.length != length) return null;
  return bytes;
}

Uint8List? _bytes(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
