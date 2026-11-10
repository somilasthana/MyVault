import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myvault/data/password_generator.dart';
import 'package:myvault/theme/vault_theme.dart';

Future<String?> showPasswordGenerator(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const PasswordGeneratorDialog(),
  );
}

class PasswordGeneratorDialog extends StatefulWidget {
  const PasswordGeneratorDialog({super.key});

  @override
  State<PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  var _length = passwordLengthMin;
  var _style = PasswordStyle.easyRead;
  var _copied = false;
  late String _password = _fresh();

  String _fresh() => generatePassword(length: _length, style: _style);

  void _regenerate() {
    setState(() {
      _password = _fresh();
      _copied = false;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _password));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final strength = ratePassword(_password);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: VaultColors.ink, width: 3),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: VaultColors.lemon,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          _password,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: VaultColors.ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              strengthLabel(strength),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _strengthColor(strength),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              key: const Key('generator-refresh'),
                              tooltip: 'New password',
                              onPressed: _regenerate,
                              icon: const Icon(Icons.autorenew_rounded, color: VaultColors.ink),
                            ),
                            IconButton(
                              key: const Key('generator-copy'),
                              tooltip: 'Copy password',
                              onPressed: _copy,
                              icon: const Icon(Icons.copy_rounded, color: VaultColors.ink),
                            ),
                          ],
                        ),
                        if (_copied)
                          const Text(
                            'Copied',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Password length: $_length characters',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Slider(
                        min: passwordLengthMin.toDouble(),
                        max: passwordLengthMax.toDouble(),
                        divisions: passwordLengthMax - passwordLengthMin,
                        value: _length.toDouble(),
                        label: '$_length',
                        activeColor: VaultColors.pink,
                        onChanged: (value) {
                          final next = value.round();
                          if (next == _length) return;
                          setState(() => _length = next);
                          _regenerate();
                        },
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Text(
                          'Choose a password type',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      RadioGroup<PasswordStyle>(
                        groupValue: _style,
                        onChanged: _chooseStyle,
                        child: const Column(
                          children: [
                            _StyleTile(
                              value: PasswordStyle.all,
                              title: 'Allow all characters',
                              subtitle: 'Any character combination',
                            ),
                            _StyleTile(
                              value: PasswordStyle.easyRead,
                              title: 'Easy to read',
                              subtitle: 'Avoid ambiguous characters, like 0, O, l, I',
                            ),
                            _StyleTile(
                              value: PasswordStyle.easySay,
                              title: 'Easy to say',
                              subtitle: 'Just lowercase and uppercase characters',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const Key('generator-cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        key: const Key('generator-use'),
                        onPressed: () => Navigator.pop(context, _password),
                        child: const Text('Use'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _chooseStyle(PasswordStyle? style) {
    if (style == null || style == _style) return;
    setState(() => _style = style);
    _regenerate();
  }

  Color _strengthColor(PasswordStrength strength) {
    return switch (strength) {
      PasswordStrength.poor => VaultColors.pinkDeep,
      PasswordStrength.average => const Color(0xFF8A5A00),
      PasswordStrength.excellent => const Color(0xFF1B7F4E),
    };
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.value,
    required this.title,
    required this.subtitle,
  });

  final PasswordStyle value;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<PasswordStyle>(
      value: value,
      activeColor: VaultColors.pink,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
