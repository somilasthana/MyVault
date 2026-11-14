import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/shared_asset.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/screens/asset_view_screen.dart';
import 'package:myvault/widgets/vault_widgets.dart';

Future<void> exportVaultItem(BuildContext context, VaultItem item) async {
  final navigator = Navigator.of(context);
  final host = navigator.overlay?.context;
  final sealed = await showDialog<SealedShare>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ExportKeyDialog(item: item),
  );
  if (sealed == null || host == null || !host.mounted) return;
  if (context.mounted) navigator.pop();
  final session = VaultScope.of(host);
  try {
    await session.sharing.shareFile(
      fileName: sealed.fileName,
      bytes: sealed.bytes,
    );
  } catch (_) {
    if (!host.mounted) return;
    ScaffoldMessenger.of(host).showSnackBar(
      const SnackBar(content: Text('Could not open the share sheet.')),
    );
  }
}

Future<void> importVaultItem(BuildContext context) async {
  final ready = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Import'),
        content: const Text(
          'Make sure the shared file is in Google Drive and you have the encryption key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
  if (ready != true || !context.mounted) return;

  final session = VaultScope.of(context);
  final Uint8List? bytes;
  try {
    bytes = await session.sharing.pickFile();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open that file.')));
    return;
  }
  if (bytes == null || !context.mounted) return;

  final item = await showDialog<VaultItem>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ImportKeyDialog(bytes: bytes!),
  );
  if (item == null || !context.mounted) return;
  try {
    await session.saveItem(item);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item.type == VaultItemType.secret
              ? 'Could not save this secure note on the phone.'
              : 'Could not save this asset on the phone.',
        ),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AssetViewScreen(itemId: item.id)),
  );
}

class _ExportKeyDialog extends StatefulWidget {
  const _ExportKeyDialog({required this.item});

  final VaultItem item;

  @override
  State<_ExportKeyDialog> createState() => _ExportKeyDialogState();
}

class _ExportKeyDialogState extends State<_ExportKeyDialog> {
  final _key = TextEditingController();
  var _hide = true;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final key = _key.text;
    if (key.length < shareKeyMinLength) {
      setState(() => _error = 'Use at least $shareKeyMinLength characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await sealSharedItem(
        item: widget.item,
        key: key,
        iterations: VaultScope.of(context).shareIterations,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        SealedShare(
          fileName: sharedItemFileName(widget.item.title),
          bytes: bytes,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not encrypt this asset.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Encrypt Key to share this asset'),
      content: SingleChildScrollView(
        child: VaultField(
          fieldKey: const Key('export-key'),
          controller: _key,
          label: 'Encrypt key',
          obscure: _hide,
          onToggleObscure: _busy ? null : () => setState(() => _hide = !_hide),
          error: _error,
          helper:
              'At least $shareKeyMinLength characters. This key is not written into the file. Send the key separately.',
          allowSuggestions: false,
          showTooltip: 'Show key',
          hideTooltip: 'Hide key',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('export-share'),
          onPressed: _busy ? null : _share,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Share'),
        ),
      ],
    );
  }
}

class _ImportKeyDialog extends StatefulWidget {
  const _ImportKeyDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImportKeyDialog> createState() => _ImportKeyDialogState();
}

class _ImportKeyDialogState extends State<_ImportKeyDialog> {
  final _key = TextEditingController();
  var _hide = true;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final key = _key.text;
    if (key.length < shareKeyMinLength) {
      setState(() => _error = 'Use at least $shareKeyMinLength characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final opened = await openSharedItem(bytes: widget.bytes, key: key);
    if (!mounted) return;
    if (opened is SharedAssetContents) {
      final now = DateTime.now().toUtc();
      Navigator.pop(
        context,
        VaultItem(
          id: newVaultItemId(),
          type: VaultItemType.asset,
          title: opened.title,
          username: opened.username,
          password: opened.password,
          notes: opened.notes,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }
    if (opened is SharedSecretContents) {
      final now = DateTime.now().toUtc();
      Navigator.pop(
        context,
        VaultItem(
          id: newVaultItemId(),
          type: VaultItemType.secret,
          title: opened.title,
          username: '',
          password: '',
          notes: opened.notes,
          reminderDate: opened.reminderDate,
          createdAt: now,
          updatedAt: now,
        ),
      );
      return;
    }
    setState(() {
      _busy = false;
      _error = switch (opened) {
        SharedItemUnreadable(:final wrongKey) =>
          wrongKey
              ? 'That key did not open this file.'
              : 'This file is not an encrypted MyVault asset.',
        SharedAssetContents() ||
        SharedSecretContents() => 'Could not read this asset.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter the key'),
      content: SingleChildScrollView(
        child: VaultField(
          fieldKey: const Key('import-key'),
          controller: _key,
          label: 'Encrypt key',
          obscure: _hide,
          onToggleObscure: _busy ? null : () => setState(() => _hide = !_hide),
          error: _error,
          helper: 'Use the key that was created when this asset was exported.',
          allowSuggestions: false,
          showTooltip: 'Show key',
          hideTooltip: 'Hide key',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('import-add'),
          onPressed: _busy ? null : _add,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
