import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/screens/info_page.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/vault_widgets.dart';

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = VaultScope.of(context);
    return AuthScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              StickerIconButton(
                tooltip: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Options before login',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionLabel('Vault Configurations'),
          _SwitchCard(
            fieldKey: const Key('remember-email'),
            title: 'Remember email',
            subtitle: 'Shows your email the next time you open MyVault.',
            value: session.rememberEmail,
            onChanged: session.setRememberEmail,
          ),
          const SizedBox(height: 12),
          _SwitchCard(
            fieldKey: const Key('remember-password'),
            title: 'Remember master password',
            subtitle: 'Fills the password on this phone after you log in once.',
            value: session.rememberPassword,
            onChanged: session.setRememberPassword,
          ),
          const SizedBox(height: 22),
          const SectionLabel('Help & legal'),
          _LinkCard(
            title: 'Ask for help',
            onTap: () => _open(context, helpPage),
          ),
          _LinkCard(
            title: 'Terms of service',
            onTap: () => _open(context, termsPage),
          ),
          _LinkCard(
            title: 'Privacy policy',
            onTap: () => _open(context, privacyPage),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, InfoPage page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.fieldKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key fieldKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: VaultColors.ink, width: 2.5),
      ),
      child: SwitchListTile(
        key: fieldKey,
        value: value,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: VaultColors.ink, width: 2.5),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right_rounded, color: VaultColors.ink),
          onTap: onTap,
        ),
      ),
    );
  }
}
