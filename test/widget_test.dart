import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/data/credential_backup.dart';
import 'package:myvault/data/key_value_store.dart';
import 'package:myvault/data/password_hasher.dart';
import 'package:myvault/data/shared_asset.dart';
import 'package:myvault/data/shared_asset_gateway.dart';
import 'package:myvault/data/vault_copy.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/data/note_reminders.dart';
import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/data/vault_backup_gateway.dart';
import 'package:myvault/data/vault_repository.dart';
import 'package:myvault/data/vault_store.dart';
import 'package:myvault/state/vault_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('password hash matches only the same password', () async {
    const hasher = PasswordHasher(iterations: 1000);
    final digest = await hasher.hash('sunshine-8');
    expect(
      await hasher.verify(
        password: 'sunshine-8',
        salt: digest.salt,
        hash: digest.hash,
      ),
      isTrue,
    );
    expect(
      await hasher.verify(
        password: 'sunshine-9',
        salt: digest.salt,
        hash: digest.hash,
      ),
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

  testWidgets('login offers create and delete, and hides import', (
    tester,
  ) async {
    await _pumpVault(tester);
    expect(find.text('MyVault'), findsOneWidget);
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Not using MyVault yet? '), findsOneWidget);
    expect(find.textContaining('Import'), findsNothing);
    expect(find.text('Forgot master password?'), findsNothing);
  });

  testWidgets('options keep vault switches and drop offline and diagnostics', (
    tester,
  ) async {
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
    expect(find.textContaining('plain text'), findsNothing);
    expect(find.textContaining(neverShareAssetsNotice), findsOneWidget);
  });

  testWidgets('create account stores locally and can skip drive', (
    tester,
  ) async {
    final backup = _RecordingBackup();
    await _pumpVault(tester, backup: backup);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text("Let's enable your vault journey"), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('create-email')),
      'not-an-email',
    );
    await tester.enterText(find.byKey(const Key('create-password')), 'short');
    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pump();
    expect(find.text('Enter an email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('create-email')),
      'Somi@Example.com',
    );
    await tester.enterText(
      find.byKey(const Key('create-password')),
      'sunshine-8',
    );
    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Save your master credentials?'), findsOneWidget);
    expect(backup.calls, 0);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('My Asset Vault'), findsOneWidget);
    expect(find.text('My Items (0)'), findsOneWidget);
    expect(
      find.textContaining('Remember your master password.'),
      findsOneWidget,
    );
    expect(backup.calls, 0);

    await _logOut(tester);
    expect(find.text('somi@example.com'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not match'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login-password')),
      'sunshine-8',
    );
    await tester.tap(find.byKey(const Key('login-button')));
    await tester.pumpAndSettle();
    expect(find.text('My Asset Vault'), findsOneWidget);
  });

  testWidgets('save to drive writes myvault credentials', (tester) async {
    final backup = _RecordingBackup();
    await _pumpVault(tester, backup: backup);
    await _createAccount(tester);

    expect(find.textContaining(neverShareAssetsNotice), findsOneWidget);
    await tester.tap(find.text('Save to Drive'));
    await tester.pumpAndSettle();

    expect(backup.calls, 1);
    expect(backup.email, 'somi@example.com');
    expect(backup.password, 'sunshine-8');
    expect(find.text(neverShareAssetsNotice), findsOneWidget);
  });

  testWidgets('a second account is refused until delete', (tester) async {
    await _pumpVault(tester);
    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await _logOut(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('create-email')),
      'other@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('create-password')),
      'sunshine-8',
    );
    await tester.tap(find.byKey(const Key('create-button')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('This phone already has a vault'),
      findsOneWidget,
    );

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'somi@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'sunshine-8',
    );
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

    final passwordField = tester.widget<TextField>(
      find.byKey(const Key('login-password')),
    );
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

    await tester.enterText(
      find.byKey(const Key('asset-title')),
      'Test Account',
    );
    await tester.tap(find.byKey(const Key('asset-save')));
    await tester.pumpAndSettle();
    expect(find.text('Missing Info'), findsOneWidget);
    expect(find.text('You must add a password'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('asset-username')),
      'somila@gmail.com',
    );
    await tester.enterText(
      find.byKey(const Key('asset-password')),
      'password-1',
    );
    await tester.enterText(
      find.byKey(const Key('asset-notes')),
      'locker hdfc code',
    );
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
    expect(find.text('No secure notes yet'), findsOneWidget);
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
    await tester.enterText(
      find.byKey(const Key('asset-title')),
      'Updated Account',
    );
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

  testWidgets('export shares ciphertext and import adds another asset', (
    tester,
  ) async {
    final session = await _pumpVault(tester);
    final sharing = session.sharing as _MemorySharing;
    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await _saveAsset(tester);

    await tester.tap(find.text('Test Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final keyField = tester.widget<TextField>(
      find.byKey(const Key('export-key')),
    );
    expect(keyField.obscureText, isTrue);
    expect(keyField.obscuringCharacter, '*');
    await tester.enterText(find.byKey(const Key('export-key')), 'short');
    await tester.tap(find.byKey(const Key('export-share')));
    await tester.pump();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Create Encrypt Key to share this asset'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('export-key')), 'share-key-1');
    await tester.tap(find.byKey(const Key('export-share')));
    await tester.pumpAndSettle();

    expect(find.text('Export'), findsNothing);
    expect(find.text('My Items (1)'), findsOneWidget);
    expect(sharing.sharedName, 'Test Account.mvasset');
    final shared = utf8.decode(sharing.sharedBytes!);
    expect(shared, contains('"kind": "myvault-shared-item"'));
    expect(shared, isNot(contains('password-1')));
    expect(shared, isNot(contains('locker hdfc code')));
    expect(shared, isNot(contains('share-key-1')));

    sharing.nextFile = sharing.sharedBytes;
    await tester.tap(find.byKey(const Key('import-asset')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Make sure the shared file is in Google Drive and you have the encryption key.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-key')), 'wrong-key-1');
    await tester.tap(find.byKey(const Key('import-add')));
    await tester.pumpAndSettle();
    expect(find.text('That key did not open this file.'), findsOneWidget);
    expect(find.text('Enter the key'), findsOneWidget);
    expect(find.text('My Items (1)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('import-key')), 'share-key-1');
    await tester.tap(find.byKey(const Key('import-add')));
    await tester.pumpAndSettle();
    expect(find.text('locker hdfc code'), findsOneWidget);
    expect(find.text('somila@gmail.com'), findsWidgets);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('My Items (2)'), findsOneWidget);
    expect(find.text('Test Account'), findsNWidgets(2));

    final secret = VaultItem(
      id: 'note',
      type: VaultItemType.secret,
      title: 'Diary',
      username: '',
      password: '',
      notes: 'quiet',
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    sharing.nextFile = await sealSharedItem(
      item: secret,
      key: 'share-key-1',
      iterations: 1000,
    );
    await tester.tap(find.byKey(const Key('import-asset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import-key')), 'share-key-1');
    await tester.tap(find.byKey(const Key('import-add')));
    await tester.pumpAndSettle();
    expect(find.text('quiet'), findsOneWidget);
    expect(find.text('Diary'), findsWidgets);
    expect(find.text('Show password'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('My Items (3)'), findsOneWidget);
    expect(find.text('Diary'), findsOneWidget);
  });

  testWidgets('a secure note saves, searches, and reminds on a chosen day', (
    tester,
  ) async {
    await _pumpVault(tester);
    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await _saveAsset(tester);

    await tester.tap(find.byKey(const Key('vault-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Secure Note'));
    await tester.pumpAndSettle();

    expect(find.text('Notification'), findsOneWidget);
    expect(find.textContaining('10:00 AM local time'), findsOneWidget);
    expect(find.text('Folder'), findsNothing);
    expect(find.textContaining('Attachments'), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(const Key('note-body'))).minLines,
      4,
    );
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-save')));
    await tester.pumpAndSettle();
    expect(find.text('Missing Information'), findsOneWidget);
    expect(find.text('Title is mandatory.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('note-body')),
      'change locker details',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Missing Information'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-body')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('note-body')), '');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vault-new')), findsOneWidget);

    await tester.tap(find.byKey(const Key('vault-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Secure Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'Bank errand');
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'change locker details\nsecond line',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Do you want to save?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Bank errand'), findsNothing);

    await tester.tap(find.byKey(const Key('vault-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Secure Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('note-title')), 'Bank errand');
    await tester.enterText(
      find.byKey(const Key('note-body')),
      'change locker details\nsecond line',
    );

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    await tester.tap(find.byKey(const Key('note-reminder')));
    await tester.pumpAndSettle();
    expect(find.text(reminderMonthTitle(start)), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder-next-month')));
    await tester.pumpAndSettle();
    expect(
      find.text(reminderMonthTitle(DateTime(start.year, start.month + 1))),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reminder-prev-month')));
    await tester.pumpAndSettle();
    if (start.day > 1) {
      final past = tester.widget<InkWell>(
        find.byKey(
          Key(
            'reminder-day-${reminderDateKey(DateTime(start.year, start.month, 1))}',
          ),
        ),
      );
      expect(past.onTap, isNull);
    }
    expect(
      tester
          .widget<InkWell>(
            find.byKey(Key('reminder-day-${reminderDateKey(start)}')),
          )
          .onTap,
      isNotNull,
    );
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-month')), findsNothing);
    expect(
      tester.widget<Switch>(find.byKey(const Key('note-reminder'))).value,
      isFalse,
    );

    final future = _futureReminderDay(start);
    await tester.tap(find.byKey(const Key('note-reminder')));
    await tester.pumpAndSettle();
    if (future.month != start.month || future.year != start.year) {
      await tester.tap(find.byKey(const Key('reminder-next-month')));
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.byKey(Key('reminder-day-${reminderDateKey(future)}')),
    );
    await tester.pumpAndSettle();
    expect(find.text(reminderTriggerLine(future)), findsOneWidget);
    expect(
      tester.widget<Switch>(find.byKey(const Key('note-reminder'))).value,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('note-reminder-line')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text(reminderTriggerLine(future)), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-save')));
    await tester.pumpAndSettle();
    expect(find.text('Bank errand'), findsOneWidget);
    expect(find.text('change locker details'), findsOneWidget);
    expect(find.text('second line'), findsNothing);
    expect(find.text('My Items (2)'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-assets')), 'second');
    await tester.pump();
    expect(find.text('Bank errand'), findsOneWidget);
    expect(find.text('Test Account'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('filter-secret')));
    await tester.pump();
    expect(find.text('Bank errand'), findsOneWidget);
    expect(find.text('Test Account'), findsNothing);
    await tester.tap(find.byKey(const Key('filter-assets')));
    await tester.pump();
    expect(find.text('Test Account'), findsOneWidget);
    expect(find.text('Bank errand'), findsNothing);
    await tester.tap(find.byKey(const Key('filter-all')));
    await tester.pump();

    await tester.tap(find.text('Bank errand'));
    await tester.pumpAndSettle();
    expect(find.text('Show password'), findsNothing);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text('Create Encrypt Key to share this asset'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.textContaining('second line'), findsOneWidget);
    expect(find.text(reminderTriggerLine(future)), findsOneWidget);
    expect(find.text('Password'), findsNothing);
  });

  testWidgets('a refused notification permission turns the reminder off', (
    tester,
  ) async {
    await _pumpVault(tester, reminders: MemoryNoteReminders(allow: false));
    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vault-new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Secure Note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('note-reminder')));
    await tester.pumpAndSettle();
    expect(
      find.text('Notifications are off in phone settings.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reminder-month')), findsNothing);
    expect(
      tester.widget<Switch>(find.byKey(const Key('note-reminder'))).value,
      isFalse,
    );
  });

  testWidgets('backup and restore run from the menu', (tester) async {
    final files = MemoryVaultBackupGateway();
    final reminders = MemoryNoteReminders(
      clock: () => DateTime(2026, 11, 13, 15),
    );
    final session = await _pumpVault(
      tester,
      backupFiles: files,
      reminders: reminders,
    );
    await _createAccount(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await session.saveItem(
      VaultItem(
        id: 'asset-1',
        type: VaultItemType.asset,
        title: 'HDFC Card',
        username: 'somi',
        password: 'vault-secret-xyz',
        notes: 'locker code',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await session.saveItem(
      VaultItem(
        id: 'note-1',
        type: VaultItemType.secret,
        title: 'Locker note',
        username: '',
        password: '',
        notes: 'papers',
        reminderDate: '2026-11-20',
        createdAt: DateTime.utc(2026, 11, 2),
        updatedAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-vault')), findsOneWidget);
    expect(find.byKey(const Key('restore-vault')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-vault')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('backup-password')), 'nope');
    await tester.tap(find.byKey(const Key('backup-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('That master password does not match this phone.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('backup-password')),
      'sunshine-8',
    );
    await tester.tap(find.byKey(const Key('backup-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Backup saved.'), findsOneWidget);
    expect(files.saved, isNotNull);

    await session.deleteItem('asset-1');
    await session.saveItem(
      VaultItem(
        id: 'local-1',
        type: VaultItemType.asset,
        title: 'Phone only',
        username: 'me',
        password: 'local-secret',
        notes: '',
        createdAt: DateTime.utc(2026, 6, 1),
        updatedAt: DateTime.utc(2026, 6, 1),
      ),
    );
    await tester.pump();
    expect(find.text('HDFC Card'), findsNothing);

    files.nextPick = files.saved;
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-vault')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('restore-password')),
      'sunshine-8',
    );
    await tester.tap(find.byKey(const Key('restore-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Backup restored.'), findsOneWidget);
    expect(find.text('HDFC Card'), findsOneWidget);
    expect(find.text('Phone only'), findsOneWidget);
    expect(find.text('Locker note'), findsOneWidget);
    expect(reminders.scheduled['note-1'], DateTime(2026, 11, 20, 10));

    files.nextPick = Uint8List.fromList(
      utf8.encode('{"version":1,"kind":"myvault-credentials"}'),
    );
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-vault')));
    await tester.pumpAndSettle();
    expect(
      find.text('This file is not an encrypted MyVault backup.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('restore-password')), findsNothing);
  });
}

Future<VaultSession> _pumpVault(
  WidgetTester tester, {
  CredentialBackup? backup,
  SharedAssetGateway? sharing,
  NoteReminders? reminders,
  VaultBackupGateway? backupFiles,
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
    sharing: sharing ?? _MemorySharing(),
    shareIterations: 1000,
    backupFiles: backupFiles,
    vaults: VaultRepository(store: MemoryVaultStore(), iterations: 1000),
    notes: VaultRepository(store: MemoryVaultStore(), iterations: 1000),
    reminders: reminders,
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
  await tester.enterText(
    find.byKey(const Key('create-email')),
    'Somi@Example.com',
  );
  await tester.enterText(
    find.byKey(const Key('create-password')),
    'sunshine-8',
  );
  await tester.tap(find.byKey(const Key('create-button')));
  await tester.pumpAndSettle();
}

Future<void> _saveAsset(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('vault-new')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('+ Add Asset Item'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('asset-title')), 'Test Account');
  await tester.enterText(
    find.byKey(const Key('asset-username')),
    'somila@gmail.com',
  );
  await tester.enterText(find.byKey(const Key('asset-password')), 'password-1');
  await tester.enterText(
    find.byKey(const Key('asset-notes')),
    'locker hdfc code',
  );
  await tester.tap(find.byKey(const Key('asset-save')));
  await tester.pumpAndSettle();
}

DateTime _futureReminderDay(DateTime today) {
  final last = DateTime(today.year, today.month + 1, 0).day;
  if (today.day < last) return DateTime(today.year, today.month, last);
  return DateTime(today.year, today.month + 1, 1);
}

class _MemorySharing implements SharedAssetGateway {
  Uint8List? sharedBytes;
  String? sharedName;
  Uint8List? nextFile;

  @override
  Future<Uint8List?> pickFile() async => nextFile;

  @override
  Future<void> shareFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    sharedName = fileName;
    sharedBytes = bytes;
  }
}

class _RecordingBackup implements CredentialBackup {
  int calls = 0;
  String? email;
  String? password;

  @override
  Future<bool> save({
    required String email,
    required String masterPassword,
  }) async {
    calls += 1;
    this.email = email;
    password = masterPassword;
    return true;
  }
}
