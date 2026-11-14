import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:myvault/data/vault_backup.dart';

/// Moves one encrypted backup file. The master password is never part of this.
abstract class VaultBackupGateway {
  /// Opens the system save dialog. Returns false when the person cancels.
  /// Replacing an existing backup.json is left to that dialog.
  Future<bool> save(Uint8List bytes);

  /// Opens the system file picker. Returns null when the person cancels.
  Future<Uint8List?> pick();
}

class DriveVaultBackupGateway implements VaultBackupGateway {
  @override
  Future<bool> save(Uint8List bytes) async {
    final saved = await FilePicker.saveFile(
      fileName: backupFileName,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save backup.json to Google Drive',
    );
    return saved != null;
  }

  @override
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose backup.json in Google Drive',
      type: FileType.any,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}

class MemoryVaultBackupGateway implements VaultBackupGateway {
  Uint8List? saved;
  Uint8List? nextPick;
  var acceptSave = true;

  @override
  Future<bool> save(Uint8List bytes) async {
    if (!acceptSave) return false;
    saved = Uint8List.fromList(bytes);
    return true;
  }

  @override
  Future<Uint8List?> pick() async => nextPick;
}
