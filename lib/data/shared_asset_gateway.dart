import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Moves one encrypted asset file. The encryption key is never part of this.
abstract class SharedAssetGateway {
  Future<void> shareFile({required String fileName, required Uint8List bytes});

  /// Opens the system file picker. Returns null when the person cancels.
  /// The chosen file is left where it is.
  Future<Uint8List?> pickFile();
}

class SystemSharedAssetGateway implements SharedAssetGateway {
  @override
  Future<void> shareFile({required String fileName, required Uint8List bytes}) {
    return SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/octet-stream',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }

  @override
  Future<Uint8List?> pickFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose the encrypted asset in Google Drive',
      type: FileType.any,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}
