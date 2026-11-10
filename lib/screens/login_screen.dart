import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/screens/create_account_screen.dart';
import 'package:myvault/screens/options_screen.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/vault_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _seeded = false;
  var _hidePassword = true;
  String? _emailError;
  String? _passwordError;
  String? _formError;
  String? _banner;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    _applyRememberedValues();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _applyRememberedValues() {
    final session = VaultScope.of(context);
    _email.text = session.rememberEmail ? (session.savedEmail ?? '') : '';
    _password.text = session.rememberPassword
        ? (session.prefilledPassword ?? '')
        : '';
  }

  Future<void> _openOptions() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const OptionsScreen()),
    );
    if (!mounted) return;
    setState(_applyRememberedValues);
  }

  Future<void> _login() async {
    final session = VaultScope.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    final emailError = validateEmail(email);
    final passwordError = password.isEmpty ? 'Enter your master password.' : null;
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _formError = null;
      _banner = null;
    });
    if (emailError != null || passwordError != null) return;

    final result = await session.login(email: email, masterPassword: password);
    if (!mounted) return;
    switch (result) {
      case LoginResult.success:
        openHome(context);
      case LoginResult.noAccount:
        setState(() {
          _formError = 'Create an account first. This phone does not have a vault yet.';
        });
      case LoginResult.mismatch:
        setState(() {
          _formError = 'That email or master password does not match this phone.';
        });
      case LoginResult.unreadable:
        setState(() {
          _formError = 'The vault on this phone could not be opened.';
        });
    }
  }

  Future<void> _deleteAccount() async {
    final session = VaultScope.of(context);
    if (!session.hasAccount) {
      setState(() => _banner = 'There is no vault account on this phone yet.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this account?'),
          content: const Text(
            'This removes the account and every asset stored on this phone. That cannot be undone. myvault.json stays in the folder where you saved it until you delete that file yourself.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await session.deleteAccount();
    if (!mounted) return;
    setState(() {
      _email.clear();
      _password.clear();
      _formError = null;
      _emailError = null;
      _passwordError = null;
      _banner = 'Account deleted from this phone.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = VaultScope.of(context);
    return AuthScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: StickerIconButton(
                        tooltip: 'Options',
                        icon: Icons.more_horiz_rounded,
                        onPressed: _openOptions,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(child: VaultMascot()),
                    const SizedBox(height: 12),
                    const Text(
                      'MyVault',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 52,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: VaultColors.pink,
                        shadows: [
                          Shadow(color: VaultColors.cyan, offset: Offset(4, 4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Secrets stay on this phone',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: VaultColors.grape,
                      ),
                    ),
                    const SizedBox(height: 28),
                    VaultField(
                      fieldKey: const Key('login-email'),
                      controller: _email,
                      label: 'Enter email address',
                      error: _emailError,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                    ),
                    const SizedBox(height: 18),
                    VaultField(
                      fieldKey: const Key('login-password'),
                      controller: _password,
                      label: 'Master password',
                      obscure: _hidePassword,
                      error: _passwordError,
                      onToggleObscure: () {
                        setState(() => _hidePassword = !_hidePassword);
                      },
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      autofillHints: const [AutofillHints.password],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: session.busy ? null : _deleteAccount,
                        child: const Text(
                          'Delete account?',
                          style: TextStyle(
                            color: VaultColors.grape,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (_banner != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _banner!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (_formError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _formError!,
                          style: const TextStyle(
                            color: VaultColors.pinkDeep,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const Spacer(),
                    StickerButton(
                      key: const Key('login-button'),
                      label: 'Log in',
                      busy: session.busy,
                      onPressed: _login,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Not using MyVault yet? ',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextButton(
                          onPressed: session.busy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const CreateAccountScreen(),
                                    ),
                                  );
                                },
                          child: const Text(
                            'Create an account',
                            style: TextStyle(
                              color: VaultColors.pink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String? validateEmail(String email) {
  final value = email.trim().toLowerCase();
  final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  if (valid) return null;
  return 'Enter an email address.';
}
