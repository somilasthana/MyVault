import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/password_generator_dialog.dart';
import 'package:myvault/widgets/vault_kind_icon.dart';
import 'package:myvault/widgets/vault_widgets.dart';

class AssetFormScreen extends StatefulWidget {
  const AssetFormScreen({this.existing, super.key});

  final VaultItem? existing;

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _notes;
  var _hidePassword = true;
  var _leaving = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _username = TextEditingController(text: existing?.username ?? '');
    _password = TextEditingController(text: existing?.password ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    for (final controller in [_title, _username, _password, _notes]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final controller in [_title, _username, _password, _notes]) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _dirty {
    final existing = widget.existing;
    if (existing == null) {
      return _title.text.isNotEmpty ||
          _username.text.isNotEmpty ||
          _password.text.isNotEmpty ||
          _notes.text.isNotEmpty;
    }
    return _title.text != existing.title ||
        _username.text != existing.username ||
        _password.text != existing.password ||
        _notes.text != existing.notes;
  }

  Future<void> _requestLeave() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Would you like to save your changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (!mounted || save == null) return;
    if (!save) {
      _leaveToList();
      return;
    }
    await _saveAndLeave();
  }

  Future<void> _saveAndLeave() async {
    if (_saving) return;
    final block = assetSaveBlock(title: _title.text, password: _password.text);
    if (block == AssetSaveBlock.missingTitle) {
      await _message('Title is missing', 'You must add a title');
      return;
    }
    if (block == AssetSaveBlock.missingPassword) {
      await _message('Missing Info', 'You must add a password');
      return;
    }

    final now = DateTime.now().toUtc();
    final existing = widget.existing;
    final item = VaultItem(
      id: existing?.id ?? newVaultItemId(),
      type: VaultItemType.asset,
      title: _title.text.trim(),
      username: _username.text,
      password: _password.text,
      notes: _notes.text,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    _saving = true;
    try {
      await VaultScope.of(context).saveItem(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this asset on the phone.')),
      );
      return;
    } finally {
      _saving = false;
    }
    if (!mounted) return;
    _leaveToList();
  }

  void _leaveToList() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _message(String title, String body) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generate() async {
    final generated = await showPasswordGenerator(context);
    if (!mounted || generated == null) return;
    setState(() {
      _password.text = generated;
      _hidePassword = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showEye = _password.text.isNotEmpty;
    return PopScope(
      canPop: _leaving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _requestLeave();
      },
      child: AuthScaffold(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  StickerIconButton(
                    tooltip: 'Back',
                    icon: Icons.arrow_back_rounded,
                    onPressed: _requestLeave,
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('asset-save'),
                    onPressed: _saving ? null : _saveAndLeave,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: VaultColors.pink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: ListView(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const VaultKindIcon(type: VaultItemType.asset, size: 56),
                          const SizedBox(width: 12),
                          Expanded(child: _titleField()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _box(
                        label: 'Username',
                        child: TextField(
                          key: const Key('asset-username'),
                          controller: _username,
                          autocorrect: false,
                          cursorColor: VaultColors.pink,
                          style: _valueStyle,
                          decoration: _inputDecoration('Username'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _box(
                        label: 'Password',
                        child: TextField(
                          key: const Key('asset-password'),
                          controller: _password,
                          obscureText: _hidePassword,
                          obscuringCharacter: '*',
                          autocorrect: false,
                          enableSuggestions: false,
                          cursorColor: VaultColors.pink,
                          style: _valueStyle,
                          decoration: _inputDecoration('Password').copyWith(
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showEye)
                                  IconButton(
                                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                                    onPressed: () {
                                      setState(() => _hidePassword = !_hidePassword);
                                    },
                                    icon: Icon(
                                      _hidePassword
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                      color: VaultColors.ink,
                                    ),
                                  ),
                                IconButton(
                                  key: const Key('asset-generate'),
                                  tooltip: 'Generate password',
                                  onPressed: _generate,
                                  icon: const Icon(
                                    Icons.autorenew_rounded,
                                    color: VaultColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _box(
                        label: 'Notes',
                        child: TextField(
                          key: const Key('asset-notes'),
                          controller: _notes,
                          minLines: 4,
                          maxLines: 8,
                          cursorColor: VaultColors.pink,
                          style: _valueStyle,
                          decoration: _inputDecoration('Notes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleField() {
    return TextField(
      key: const Key('asset-title'),
      controller: _title,
      cursorColor: VaultColors.pink,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: VaultColors.ink),
      decoration: _inputDecoration('Title').copyWith(
        hintStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB89BC4),
        ),
      ),
    );
  }

  Widget _box({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: VaultColors.grape,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

const _valueStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w500,
  color: VaultColors.ink,
);

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB89BC4), fontSize: 16),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: _border(VaultColors.ink),
    focusedBorder: _border(VaultColors.pink),
  );
}

OutlineInputBorder _border(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: 2.5),
  );
}
