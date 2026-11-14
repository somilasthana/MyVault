import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/data/vault_item.dart';

const shareKeyMinLength = 8;
const defaultShareIterations = 120000;

const _kind = 'myvault-shared-item';
const _kdf = 'pbkdf2-hmac-sha256';
const _maxIterations = 400000;

class SealedShare {
  const SealedShare({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

sealed class SharedItemOpen {
  const SharedItemOpen();
}

class SharedAssetContents extends SharedItemOpen {
  const SharedAssetContents({
    required this.title,
    required this.username,
    required this.password,
    required this.notes,
  });

  final String title;
  final String username;
  final String password;
  final String notes;
}

class SharedSecretContents extends SharedItemOpen {
  const SharedSecretContents({
    required this.title,
    required this.notes,
    this.reminderDate,
  });

  final String title;
  final String notes;
  final String? reminderDate;
}

class SharedItemUnreadable extends SharedItemOpen {
  const SharedItemUnreadable({required this.wrongKey});

  /// True when the file is a vault asset envelope and the key does not match.
  final bool wrongKey;
}

String sharedItemFileName(String title) {
  final cleaned = title
      .replaceAll(RegExp(r'[<>:"/\\|?*\u0000-\u001F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final base = cleaned.isEmpty ? 'asset' : cleaned;
  final shortened = base.length > 80 ? base.substring(0, 80).trim() : base;
  return '$shortened.mvasset';
}

/// Encrypts one item. The key is not written into the file.
Future<Uint8List> sealSharedItem({
  required VaultItem item,
  required String key,
  int iterations = defaultShareIterations,
}) async {
  if (key.length < shareKeyMinLength) {
    throw ArgumentError.value(
      key.length,
      'key',
      'Use at least $shareKeyMinLength characters.',
    );
  }
  if (iterations < 1 || iterations > _maxIterations) {
    throw ArgumentError.value(iterations, 'iterations');
  }

  final salt = _randomBytes(16);
  final secretKey = await _derive(key: key, salt: salt, iterations: iterations);
  final inner = jsonEncode({
    'version': 1,
    'type': item.type.name,
    'title': item.title,
    'username': item.username,
    'password': item.password,
    'notes': item.notes,
    if (item.reminderDate != null) 'reminderDate': item.reminderDate,
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

Future<SharedItemOpen> openSharedItem({
  required Uint8List bytes,
  required String key,
}) async {
  final envelope = _envelope(bytes);
  if (envelope == null) return const SharedItemUnreadable(wrongKey: false);
  try {
    final secretKey = await _derive(
      key: key,
      salt: envelope.salt,
      iterations: envelope.iterations,
    );
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        envelope.cipherText,
        nonce: envelope.nonce,
        mac: Mac(envelope.mac),
      ),
      secretKey: secretKey,
    );
    return _contents(clear);
  } on SecretBoxAuthenticationError {
    return const SharedItemUnreadable(wrongKey: true);
  } on FormatException {
    return const SharedItemUnreadable(wrongKey: false);
  }
}

Future<SecretKey> _derive({
  required String key,
  required List<int> salt,
  required int iterations,
}) {
  return Pbkdf2.hmacSha256(
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: key, nonce: salt);
}

SharedItemOpen _contents(List<int> clear) {
  final decoded = jsonDecode(utf8.decode(clear));
  if (decoded is! Map) throw const FormatException('inner');
  final map = Map<String, dynamic>.from(decoded);
  if (map['version'] != 1) throw const FormatException('version');
  final type = map['type'];
  if (type == VaultItemType.secret.name) return _secret(map);
  if (type != VaultItemType.asset.name) throw const FormatException('type');
  final title = map['title'];
  final username = map['username'];
  final password = map['password'];
  final notes = map['notes'];
  if (title is! String || title.trim().isEmpty) {
    throw const FormatException('title');
  }
  if (username is! String || password is! String || notes is! String) {
    throw const FormatException('fields');
  }
  if (password.isEmpty) throw const FormatException('password');
  return SharedAssetContents(
    title: title,
    username: username,
    password: password,
    notes: notes,
  );
}

SharedSecretContents _secret(Map<String, dynamic> map) {
  final title = map['title'];
  final notes = map['notes'];
  if (title is! String || title.trim().isEmpty) {
    throw const FormatException('title');
  }
  if (notes is! String) throw const FormatException('notes');
  final reminder = map['reminderDate'];
  if (reminder != null && reminder is! String) {
    throw const FormatException('reminder');
  }
  final reminderDate = reminder is String && parseReminderDate(reminder) != null
      ? reminder
      : null;
  return SharedSecretContents(
    title: title,
    notes: notes,
    reminderDate: reminderDate,
  );
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
