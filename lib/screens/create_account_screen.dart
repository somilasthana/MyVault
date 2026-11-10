import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/screens/home_screen.dart';
import 'package:myvault/screens/login_screen.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/vault_widgets.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _hidePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final session = VaultScope.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    final emailError = validateEmail(email);
    final passwordError = password.length < 8
        ? 'Use at least 8 characters.'
        : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;

    final result = await session.createAccount(
      email: email,
      masterPassword: password,
    );
    if (!mounted) return;
    if (result == AccountWriteResult.alreadyExists) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('A vault is already here'),
            content: const Text(
              'This phone already has a vault. Delete that account from the login screen before creating another.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save your master credentials?'),
          content: const Text(
            'You will store your master credentials on Google Drive. myvault.json will be saved in a folder you choose.\n\nThe file contains your master password in plain text. Do not share this master password with anyone.\n\nA new install starts from scratch and ignores an older myvault.json. Saving again into the same place replaces the old file. Assets are not stored in that file.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save to Drive'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    var notice =
        'Vault created on this phone. Remember your master password.';
    if (save == true) {
      try {
        final saved = await session.saveCredentials(
          email: email.trim().toLowerCase(),
          masterPassword: password,
        );
        notice = saved
            ? 'myvault.json saved. Do not share this master password with anyone.'
            : 'Drive save was cancelled. The account is on this phone. Remember your master password.';
      } catch (_) {
        notice =
            'Could not open the save dialog. The account is on this phone. Remember your master password.';
      }
    }
    if (!mounted) return;
    openHome(context, notice: notice);
  }

  @override
  Widget build(BuildContext context) {
    final session = VaultScope.of(context);
    return AuthScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: StickerIconButton(
                tooltip: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              "Let's enable your vault journey",
              style: TextStyle(
                fontSize: 34,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: VaultColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This account lives on the phone. Assets stay on this phone. There is no cloud login.',
              style: TextStyle(fontSize: 16, color: Color(0xFF6E5684)),
            ),
            const SizedBox(height: 28),
            VaultField(
              fieldKey: const Key('create-email'),
              controller: _email,
              label: 'Enter your email address',
              error: _emailError,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 18),
            VaultField(
              fieldKey: const Key('create-password'),
              controller: _password,
              label: 'Enter your master password',
              obscure: _hidePassword,
              error: _passwordError,
              helper: 'At least 8 characters. Stars hide it, and you keep it in your head.',
              onToggleObscure: () => setState(() => _hidePassword = !_hidePassword),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 28),
            StickerButton(
              key: const Key('create-button'),
              label: 'Create my account',
              busy: session.busy,
              onPressed: _create,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: session.busy ? null : () => Navigator.of(context).pop(),
              child: const Text(
                'Log in instead',
                style: TextStyle(
                  color: VaultColors.grape,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openHome(BuildContext context, {String? notice}) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => HomeScreen(notice: notice)),
    (_) => false,
  );
}
