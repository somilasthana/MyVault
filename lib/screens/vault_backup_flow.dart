import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/vault_backup.dart';
import 'package:myvault/state/vault_session.dart';
import 'package:myvault/widgets/vault_widgets.dart';

Future<void> backupVault(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) navigator.pop();
  final result = await showDialog<VaultBackupSave>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BackupPasswordDialog(),
  );
  if (result == null || !context.mounted) return;
  final message = switch (result) {
    VaultBackupSave.saved => 'Backup saved.',
    VaultBackupSave.cancelled => 'Drive save was cancelled.',
    _ => null,
  };
  if (message == null) return;
  _tell(context, message);
}

Future<void> restoreVault(BuildContext context) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) navigator.pop();
  final session = VaultScope.of(context);
  final Uint8List? bytes;
  try {
    bytes = await session.pickBackup();
  } catch (_) {
    if (!context.mounted) return;
    _tell(context, 'Could not open that file.');
    return;
  }
  if (bytes == null || !context.mounted) return;
  if (!looksLikeVaultBackup(bytes)) {
    _tell(context, 'This file is not an encrypted MyVault backup.');
    return;
  }
  final result = await showDialog<VaultBackupRestore>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RestorePasswordDialog(bytes: bytes!),
  );
  if (result != VaultBackupRestore.restored || !context.mounted) return;
  _tell(context, 'Backup restored.');
}

void _tell(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  var _hide = true;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your master password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await VaultScope.of(context).saveBackup(password);
    if (!mounted) return;
    switch (result) {
      case VaultBackupSave.wrongPassword:
        setState(() {
          _busy = false;
          _error = 'That master password does not match this phone.';
        });
      case VaultBackupSave.saved:
      case VaultBackupSave.cancelled:
        Navigator.pop(context, result);
      case VaultBackupSave.locked:
      case VaultBackupSave.failed:
        setState(() {
          _busy = false;
          _error = 'Could not save the backup.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backup'),
      content: SingleChildScrollView(
        child: VaultField(
          fieldKey: const Key('backup-password'),
          controller: _password,
          label: 'Master password',
          obscure: _hide,
          onToggleObscure: _busy ? null : () => setState(() => _hide = !_hide),
          error: _error,
          helper: 'This encrypts backup.json. The password is not in the file.',
          allowSuggestions: false,
          onSubmitted: _busy ? null : (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('backup-confirm'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Backup'),
        ),
      ],
    );
  }
}

class _RestorePasswordDialog extends StatefulWidget {
  const _RestorePasswordDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_RestorePasswordDialog> createState() => _RestorePasswordDialogState();
}

class _RestorePasswordDialogState extends State<_RestorePasswordDialog> {
  final _password = TextEditingController();
  var _hide = true;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final password = _password.text;
    if (password.isEmpty) {
      setState(() => _error = 'Enter your master password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await VaultScope.of(context)
        .restoreBackup(bytes: widget.bytes, masterPassword: password);
    if (!mounted) return;
    switch (result) {
      case VaultBackupRestore.wrongPassword:
        setState(() {
          _busy = false;
          _error = 'That master password does not open this backup.';
        });
      case VaultBackupRestore.notABackup:
        setState(() {
          _busy = false;
          _error = 'This file is not an encrypted MyVault backup.';
        });
      case VaultBackupRestore.restored:
        Navigator.pop(context, result);
      case VaultBackupRestore.locked:
      case VaultBackupRestore.failed:
        setState(() {
          _busy = false;
          _error = 'Could not restore this backup on the phone.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restore'),
      content: SingleChildScrollView(
        child: VaultField(
          fieldKey: const Key('restore-password'),
          controller: _password,
          label: 'Master password',
          obscure: _hide,
          onToggleObscure: _busy ? null : () => setState(() => _hide = !_hide),
          error: _error,
          helper: 'Use the master password that encrypted this backup.',
          allowSuggestions: false,
          onSubmitted: _busy ? null : (_) => _restore(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('restore-confirm'),
          onPressed: _busy ? null : _restore,
          child: Text(_busy ? 'Restoring…' : 'Restore'),
        ),
      ],
    );
  }
}
