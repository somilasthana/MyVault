import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/data/key_value_store.dart';
import 'package:myvault/data/system_note_reminders.dart';
import 'package:myvault/data/vault_repository.dart';
import 'package:myvault/data/vault_store.dart';
import 'package:myvault/state/vault_session.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final reminders = SystemNoteReminders();
  try {
    await reminders.init();
  } catch (_) {}
  final directory = await getApplicationDocumentsDirectory();
  final separator = Platform.pathSeparator;
  final session = VaultSession(
    accounts: AccountRepository(SecureKeyValueStore()),
    vaults: VaultRepository(
      store: FileVaultStore(File('${directory.path}${separator}vault.dat')),
    ),
    notes: VaultRepository(
      store: FileVaultStore(File('${directory.path}${separator}notes.dat')),
    ),
    reminders: reminders,
  );
  await session.load();
  runApp(VaultApp(session: session));
}
