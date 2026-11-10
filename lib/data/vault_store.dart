import 'dart:io';

abstract class VaultStore {
  Future<String?> read();
  Future<void> write(String contents);
  Future<void> delete();
}

class MemoryVaultStore implements VaultStore {
  String? contents;

  @override
  Future<void> delete() async {
    contents = null;
  }

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String contents) async {
    this.contents = contents;
  }
}

class FileVaultStore implements VaultStore {
  FileVaultStore(this.file);

  final File file;

  @override
  Future<void> delete() async {
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String?> read() async {
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String contents) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(contents, flush: true);
  }
}
