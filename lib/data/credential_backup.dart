import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Writes the master email and password into a JSON file the user places
/// themselves, usually in a private Google Drive folder. The password is
/// plain text on purpose so they can read the file back later.
abstract class CredentialBackup {
  Future<bool> save({required String email, required String masterPassword});
}

class DriveCredentialBackup implements CredentialBackup {
  @override
  Future<bool> save({
    required String email,
    required String masterPassword,
  }) async {
    final bytes = Uint8List.fromList(
      utf8.encode(credentialsJson(email: email, masterPassword: masterPassword)),
    );
    final saved = await FilePicker.saveFile(
      fileName: 'myvault.json',
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save myvault.json to Google Drive',
    );
    return saved != null;
  }
}

String credentialsJson({
  required String email,
  required String masterPassword,
  DateTime? createdAt,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'version': 1,
    'kind': 'myvault-credentials',
    'email': email,
    'masterPassword': masterPassword,
    'createdAt': (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
  });
}
