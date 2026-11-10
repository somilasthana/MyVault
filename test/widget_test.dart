import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/data/credential_backup.dart';
import 'package:myvault/data/key_value_store.dart';
import 'package:myvault/data/password_hasher.dart';
import 'package:myvault/data/vault_repository.dart';
import 'package:myvault/data/vault_store.dart';
import 'package:myvault/state/vault_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('password hash matches only the same password', () async {
    const hasher = PasswordHasher(iterations: 1000);
    final digest = await hasher.hash('sunshine-8');
    expect(
      await hasher.verify(password: 'sunshine-8', salt: digest.salt, hash: digest.hash),
      isTrue,
    );
    expect(
      await hasher.verify(password: 'sunshine-9', salt: digest.salt, hash: digest.hash),
      isFalse,
    );
  });

  test('credentials json keeps the master password readable', () {
    final json = credentialsJson(
      email: 'somi@example.com',
      masterPassword: 'sunshine-8',
      createdAt: DateTime.utc(2026, 11, 9),
    );
    expect(json, contains('"email": "somi@example.com"'));
    expect(json, contains('"masterPassword": "sunshine-8"'));
    expect(json, contains('"kind": "myvault-credentials"'));
  });

  testWidgets('login offers create and delete, and hides import', (tester) async {
    await _pumpVault(tester);
    expect(find.text('MyVault'), findsOneWidget);
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Not using MyVault yet? '), findsOneWidget);
    expect(find.textContaining('Import'), findsNothing);
    expect(find.text('Forgot master password?'), findsNothing);
  });

  testWidgets('options keep vault switches and drop offline and diagnostics', (tester) async {
    await _pumpVault(tester);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Options before login'), findsOneWidget);
    expect(find.text('Vault Configurations'), findsOneWidget);
    expect(find.text('Remember email'), findsOneWidget);
    expect(find.text('Remember master password'), findsOneWidget);
    expect(find.text('Help & legal'), findsOneWidget);
    expect(find.text('Ask for help'), findsOneWidget);
    expect(find.text('Terms of service'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Offline mode'), findsNothing);
    expect(find.textContaining('Diagnostic'), findsNothing);

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.textContaining('plain text'), findsOneWidget);
  });

  testWidgets('create account stores locally and can skip drive', (tester) async {
    final backup = _RecordingBackup();
    await _pumpVault(tester, backup: backup);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text("Let's enable your vault journey"), findsOneWidget);

    await tester.enterText(find.byKey(const Key('create-email')), 'not-an-email');
    await tester.enterText(find.byKey(const Key('create-password')), 'short');
    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pump();
    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('create-email')), 'Somi@Example.com');
    await tester.enterText(find.byKey(const Key('create-password')), 'sunshine-8');
    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Save your master credentials?'), findsOneWidget);
    expect(backup.calls, 0);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('My Asset Vault'), findsOneWidget);
    expect(find.text('My Items (0)'), findsOneWidget);
    expect(find.textContaining('Remember your master password.'), findsOneWidget);
    expect(backup.calls, 0);

    await _logOut(tester);
    expect(find.text('somi@example.com'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login-password')), 'wrong-password');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not match'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login-password')), 'sunshine-8');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(find.text('My Asset Vault'), findsOneWidget);
  });

  testWidgets('save to drive writes myvault credentials', (tester) async {
    final backup = _RecordingBackup();
    await _pumpVault(tester, backup: backup);
    await _createAccount(tester);

    await tester.tap(find.text('Save to Drive'));
    await tester.pumpAndSettle();

    expect(backup.calls, 1);
    expect(backup.email, 'somi@example.com');
    expect(backup.password, 'sunshine-8');
    expect(find.textContaining('myvault.json saved'), findsOneWidget);
  });

  testWidgets('a second account is refused until delete', (tester) async {
    await _pumpVault(tester);
    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await _logOut(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('create-email')), 'other@example.com');
    await tester.enterText(find.byKey(const Key('create-password')), 'sunshine-8');
    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('This phone already has a vault'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login-email')), 'somi@example.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'sunshine-8');
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not have a vault'), findsOneWidget);
  });

  testWidgets('remember master password fills it after login', (tester) async {
    await _pumpVault(tester);
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remember-password')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await _logOut(tester);

    final passwordField = tester.widget<TextField>(find.byKey(const Key('login-password')));
    expect(passwordField.controller?.text, 'sunshine-8');
  });

  testWidgets('assets can be saved, searched, and deleted', (tester) async {
    await _pumpVault(tester);
    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vault-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Asset Item'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('asset-title')), 'Temp');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Would you like to save your changes?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Temp'), findsNothing);
    expect(find.text('My Asset Vault'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vault-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Asset Item'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('asset-save')));
    await tester.pumpAndSettle();
    expect(find.text('Title is missing'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('asset-title')), 'Test Account');
    await tester.tap(find.byKey(const Key('asset-save')));
    await tester.pumpAndSettle();
    expect(find.text('Missing Info'), findsOneWidget);
    expect(find.text('You must add a password'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('asset-username')), 'somila@gmail.com');
    await tester.enterText(find.byKey(const Key('asset-password')), 'password-1');
    await tester.enterText(find.byKey(const Key('asset-notes')), 'locker hdfc code');
    await tester.tap(find.byKey(const Key('asset-save')));
    await tester.pumpAndSettle();

    expect(find.text('Test Account'), findsOneWidget);
    expect(find.text('somila@gmail.com'), findsOneWidget);
    expect(find.text('My Items (1)'), findsOneWidget);
    expect(find.text('locker hdfc code'), findsNothing);

    await tester.enterText(find.byKey(const Key('search-assets')), 'hdfc');
    await tester.pump();
    expect(find.text('Test Account'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search-assets')), 'somila');
    await tester.pump();
    expect(find.text('Nothing matches'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search-assets')), 'hd f');
    await tester.pump();
    expect(find.text('Nothing matches'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('filter-secret')));
    await tester.pump();
    expect(find.text('No secret notes yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-all')));
    await tester.pump();

    await tester.tap(find.text('Test Account'));
    await tester.pumpAndSettle();
    expect(find.text('password-1'), findsNothing);
    await tester.tap(find.text('Show password'));
    await tester.pump();
    expect(find.text('password-1'), findsOneWidget);
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.text('locker hdfc code'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('asset-title')), 'Updated Account');
    await tester.tap(find.byKey(const Key('asset-save')));
    await tester.pumpAndSettle();
    expect(find.text('Updated Account'), findsOneWidget);
    expect(find.text('Test Account'), findsNothing);

    await tester.tap(find.text('Updated Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Updated Account'), findsNothing);
    expect(find.text('My Items (0)'), findsOneWidget);
  });
}

Future<VaultSession> _pumpVault(
  WidgetTester tester, {
  CredentialBackup? backup,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final session = VaultSession(
    accounts: AccountRepository(
      MemoryKeyValueStore(),
      hasher: const PasswordHasher(iterations: 1000),
    ),
    backup: backup ?? _RecordingBackup(),
    vaults: VaultRepository(store: MemoryVaultStore(), iterations: 1000),
  );
  await session.load();
  await tester.pumpWidget(VaultApp(session: session));
  await tester.pumpAndSettle();
  return session;
}

Future<void> _logOut(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Open menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('log-out')));
  await tester.pumpAndSettle();
}

Future<void> _createAccount(WidgetTester tester) async {
  await tester.tap(find.text('Create an account'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('create-email')), 'Somi@Example.com');
  await tester.enterText(find.byKey(const Key('create-password')), 'sunshine-8');
  await tester.tap(find.byKey(const Key('create-button')));
  await tester.pumpAndSettle();
}

class _RecordingBackup implements CredentialBackup {
  int calls = 0;
  String? email;
  String? password;

  @override
  Future<bool> save({required String email, required String masterPassword}) async {
    calls += 1;
    this.email = email;
    password = masterPassword;
    return true;
  }
}
