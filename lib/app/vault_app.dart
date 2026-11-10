import 'package:flutter/material.dart';
import 'package:myvault/screens/login_screen.dart';
import 'package:myvault/state/vault_session.dart';
import 'package:myvault/theme/vault_theme.dart';

class VaultScope extends InheritedNotifier<VaultSession> {
  const VaultScope({required VaultSession session, required super.child, super.key})
    : super(notifier: session);

  static VaultSession of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VaultScope>();
    assert(scope != null, 'VaultScope is missing above this widget.');
    return scope!.notifier!;
  }
}

class VaultApp extends StatelessWidget {
  const VaultApp({required this.session, super.key});

  final VaultSession session;

  @override
  Widget build(BuildContext context) {
    return VaultScope(
      session: session,
      child: MaterialApp(
        title: 'MyVault',
        debugShowCheckedModeBanner: false,
        theme: buildVaultTheme(),
        home: const LoginScreen(),
      ),
    );
  }
}
