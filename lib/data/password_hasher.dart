import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class PasswordHasher {
  const PasswordHasher({this.iterations = 120000});

  final int iterations;

  Future<({String salt, String hash})> hash(String password) async {
    final saltBytes = _randomBytes(16);
    final hashBytes = await _derive(
      password: password,
      salt: saltBytes,
      iterations: iterations,
    );
    return (salt: base64Encode(saltBytes), hash: base64Encode(hashBytes));
  }

  Future<bool> verify({
    required String password,
    required String salt,
    required String hash,
  }) async {
    final actual = await _derive(
      password: password,
      salt: base64Decode(salt),
      iterations: iterations,
    );
    return _constantTimeEquals(actual, base64Decode(hash));
  }
}

Future<List<int>> _derive({
  required String password,
  required List<int> salt,
  required int iterations,
}) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final derived = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return derived.extractBytes();
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
