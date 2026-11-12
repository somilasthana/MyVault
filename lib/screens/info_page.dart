import 'package:flutter/material.dart';
import 'package:myvault/data/vault_copy.dart';
import 'package:myvault/widgets/vault_widgets.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({required this.title, required this.paragraphs, super.key});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: StickerIconButton(
              tooltip: 'Back',
              icon: Icons.arrow_back_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          for (final paragraph in paragraphs) ...[
            Text(paragraph, style: const TextStyle(fontSize: 16, height: 1.4)),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

const helpPage = InfoPage(
  title: 'Ask for help',
  paragraphs: [
    'MyVault has no support team and no cloud account that can reset a password.',
    'The master password lives in your head. $neverShareAssetsNotice',
    'Deleting the account removes the account and every asset on this phone. A file already saved in Drive stays where you put it. A new install does not restore assets.',
  ],
);

const termsPage = InfoPage(
  title: 'Terms of service',
  paragraphs: [
    'MyVault is a personal vault that stays on your phone. You are responsible for the master password and for any myvault.json you save. $neverShareAssetsNotice',
    'There is no warranty. $neverShareAssetsNotice',
  ],
);

const privacyPage = InfoPage(
  title: 'Privacy policy',
  paragraphs: [
    'Nothing is sent to a MyVault server, because there is not one. Your email and a scrambled form of your master password are stored on this phone.',
    'If you choose Save to Drive, myvault.json is written to a Google Drive folder you pick. $neverShareAssetsNotice Assets are not in that file.',
    'Google Drive is your own storage. MyVault does not keep a copy.',
  ],
);
