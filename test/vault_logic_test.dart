import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/data/key_value_store.dart';
import 'package:myvault/data/password_generator.dart';
import 'package:myvault/data/shared_asset.dart';
import 'package:myvault/data/password_hasher.dart';
import 'package:myvault/data/vault_backup.dart';
import 'package:myvault/data/vault_backup_gateway.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/data/note_reminders.dart';
import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/data/vault_repository.dart';
import 'package:myvault/data/vault_store.dart';
import 'package:myvault/state/vault_session.dart';

void main() {
  VaultItem sample({
    String id = 'a',
    String title = 'HDFC',
    String username = 'person',
    String notes = '',
    String password = 'secret',
    DateTime? createdAt,
  }) {
    final when = createdAt ?? DateTime.utc(2026, 1, 1);
    return VaultItem(
      id: id,
      type: VaultItemType.asset,
      title: title,
      username: username,
      password: password,
      notes: notes,
      createdAt: when,
      updatedAt: when,
    );
  }

  test('search matches title and notes as a literal phrase', () {
    final bank = sample(
      title: 'HDFC Bank',
      username: 'somila',
      notes: 'locker',
    );
    final mine = sample(id: 'b', title: 'myhdfc');
    final joined = sample(id: 'c', title: 'hdfcbank');
    final spaced = sample(id: 'd', title: 'hd fcoo');
    final noted = sample(
      id: 'e',
      title: 'Rent',
      username: 'hdfc-user',
      notes: 'pay hdfc',
    );
    final dotted = sample(id: 'f', title: 'h.fc');

    expect(itemMatchesQuery(bank, 'hdfc'), isTrue);
    expect(itemMatchesQuery(mine, 'hdfc'), isTrue);
    expect(itemMatchesQuery(joined, 'hdfc'), isTrue);
    expect(itemMatchesQuery(spaced, 'hdfc'), isFalse);
    expect(itemMatchesQuery(noted, 'hdfc'), isTrue);
    expect(
      itemMatchesQuery(sample(title: 'Rent', username: 'hdfc-user'), 'hdfc'),
      isFalse,
    );
    expect(itemMatchesQuery(bank, 'h.fc'), isFalse);
    expect(itemMatchesQuery(dotted, 'h.fc'), isTrue);
    expect(itemMatchesQuery(bank, '   '), isTrue);
  });

  test('visible rows keep duplicates and put the newest first', () {
    final older = sample(id: 'old', createdAt: DateTime.utc(2020));
    final newer = sample(
      id: 'new',
      title: 'HDFC',
      createdAt: DateTime.utc(2024),
    );
    final secret = VaultItem(
      id: 'note',
      type: VaultItemType.secret,
      title: 'Diary',
      username: '',
      password: '',
      notes: 'quiet',
      createdAt: DateTime.utc(2025),
      updatedAt: DateTime.utc(2025),
    );
    final visible = visibleVaultItems(
      items: [older, secret, newer],
      filter: VaultFilter.assets,
      query: 'hdfc',
    );
    expect(visible.map((item) => item.id), ['new', 'old']);
    expect(
      visibleVaultItems(
        items: [older, secret],
        filter: VaultFilter.secrets,
        query: '',
      ).single.id,
      'note',
    );
  });

  test('a save needs a title before it needs a password', () {
    expect(
      assetSaveBlock(title: '   ', password: ''),
      AssetSaveBlock.missingTitle,
    );
    expect(
      assetSaveBlock(title: 'Rent', password: ''),
      AssetSaveBlock.missingPassword,
    );
    expect(assetSaveBlock(title: 'Rent', password: ' '), AssetSaveBlock.none);
  });

  test('generated passwords stay inside the chosen alphabet', () {
    final spoken = generatePassword(
      length: 16,
      style: PasswordStyle.easySay,
      random: Random(2),
    );
    final readable = generatePassword(
      length: 32,
      style: PasswordStyle.easyRead,
      random: Random(3),
    );
    final mixed = generatePassword(
      length: 12,
      style: PasswordStyle.all,
      random: Random(4),
    );

    expect(spoken.length, 16);
    expect(RegExp(r'^[A-Za-z]+$').hasMatch(spoken), isTrue);
    expect(spoken.contains(' '), isFalse);
    expect(ratePassword(spoken), PasswordStrength.average);

    expect(RegExp('[0OolI1 ]').hasMatch(readable), isFalse);
    expect(readable.length, 32);

    expect(mixed.length, 12);
    expect(mixed.contains(' '), isFalse);
    expect(ratePassword(mixed), PasswordStrength.excellent);
    expect(ratePassword('short'), PasswordStrength.poor);
    expect(ratePassword('abcdefgh'), PasswordStrength.poor);
    expect(ratePassword('Abcdefgh'), PasswordStrength.average);
    expect(ratePassword('Abcdefghij1!'), PasswordStrength.excellent);
  });

  test('the vault file hides the password and opens again', () async {
    final store = MemoryVaultStore();
    final first = VaultRepository(store: store, iterations: 1000);
    final saved = await first.open('sunshine-8');
    expect(saved, isEmpty);
    await first.persist([sample(password: 'vault-secret-xyz', title: 'HDFC')]);
    final raw = await store.read();
    expect(raw, isNotNull);
    expect(raw, isNot(contains('vault-secret-xyz')));
    expect(raw, isNot(contains('sunshine-8')));
    first.lock();

    final second = VaultRepository(store: store, iterations: 1000);
    await expectLater(
      second.open('wrong-password'),
      throwsA(isA<VaultUnreadable>()),
    );
    final opened = await second.open('sunshine-8');
    expect(opened.single.title, 'HDFC');
    expect(opened.single.password, 'vault-secret-xyz');
  });

  test('deleting the account removes the encrypted vault', () async {
    final store = MemoryVaultStore();
    final session = VaultSession(
      accounts: AccountRepository(
        MemoryKeyValueStore(),
        hasher: const PasswordHasher(iterations: 1000),
      ),
      vaults: VaultRepository(store: store, iterations: 1000),
      notes: VaultRepository(store: MemoryVaultStore(), iterations: 1000),
    );
    await session.createAccount(
      email: 'somi@example.com',
      masterPassword: 'sunshine-8',
    );
    expect(await store.read(), isNotNull);
    await session.saveItem(sample());
    expect(session.items, hasLength(1));

    await session.deleteAccount();
    expect(await store.read(), isNull);
    expect(session.items, isEmpty);
    expect(session.hasAccount, isFalse);
  });

  test('a shared asset stays unreadable without the same key', () async {
    final item = sample(
      title: 'Test Account',
      username: 'somila@gmail.com',
      password: 'password-1',
      notes: 'locker hdfc code',
    );
    final first = await sealSharedItem(
      item: item,
      key: 'share-key-1',
      iterations: 1000,
    );
    final second = await sealSharedItem(
      item: item,
      key: 'share-key-1',
      iterations: 1000,
    );
    expect(first, isNot(equals(second)));
    final text = utf8.decode(first);
    expect(text, contains('"kind": "myvault-shared-item"'));
    expect(text, isNot(contains('password-1')));
    expect(text, isNot(contains('locker hdfc code')));
    expect(text, isNot(contains('share-key-1')));

    final opened = await openSharedItem(bytes: first, key: 'share-key-1');
    expect(opened, isA<SharedAssetContents>());
    final contents = opened as SharedAssetContents;
    expect(contents.title, 'Test Account');
    expect(contents.username, 'somila@gmail.com');
    expect(contents.password, 'password-1');
    expect(contents.notes, 'locker hdfc code');

    final wrong = await openSharedItem(bytes: first, key: 'share-key-2');
    expect((wrong as SharedItemUnreadable).wrongKey, isTrue);
    final junk = await openSharedItem(
      bytes: Uint8List.fromList(utf8.encode('not a vault file')),
      key: 'share-key-1',
    );
    expect((junk as SharedItemUnreadable).wrongKey, isFalse);

    final secret = VaultItem(
      id: 'note',
      type: VaultItemType.secret,
      title: 'Diary',
      username: '',
      password: '',
      notes: 'quiet',
      reminderDate: '2026-12-01',
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    final sealedSecret = await sealSharedItem(
      item: secret,
      key: 'share-key-1',
      iterations: 1000,
    );
    final openedSecret = await openSharedItem(
      bytes: sealedSecret,
      key: 'share-key-1',
    );
    expect(openedSecret, isA<SharedSecretContents>());
    final secretContents = openedSecret as SharedSecretContents;
    expect(secretContents.title, 'Diary');
    expect(secretContents.notes, 'quiet');
    expect(secretContents.reminderDate, '2026-12-01');
    expect(utf8.decode(sealedSecret), isNot(contains('quiet')));
    expect(sharedItemFileName('A/B:C'), 'A B C.mvasset');
    await expectLater(
      sealSharedItem(item: item, key: 'short', iterations: 1000),
      throwsArgumentError,
    );
  });

  test('secure notes live in their own file and remind at 10:00', () async {
    final assetStore = MemoryVaultStore();
    final noteStore = MemoryVaultStore();
    final accounts = AccountRepository(
      MemoryKeyValueStore(),
      hasher: const PasswordHasher(iterations: 1000),
    );
    final reminders = MemoryNoteReminders(
      clock: () => DateTime(2026, 11, 13, 15),
    );
    final session = VaultSession(
      accounts: accounts,
      vaults: VaultRepository(store: assetStore, iterations: 1000),
      notes: VaultRepository(store: noteStore, iterations: 1000),
      reminders: reminders,
    );
    await session.createAccount(
      email: 'somi@example.com',
      masterPassword: 'sunshine-8',
    );
    await session.saveItem(sample(id: 'asset', title: 'HDFC'));
    await session.saveItem(
      VaultItem(
        id: 'today',
        type: VaultItemType.secret,
        title: 'Locker',
        username: '',
        password: '',
        notes: 'change locker\nsecond line',
        reminderDate: '2026-11-13',
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await session.saveItem(
      VaultItem(
        id: 'later',
        type: VaultItemType.secret,
        title: 'Tax',
        username: '',
        password: '',
        notes: 'papers',
        reminderDate: '2026-11-20',
        createdAt: DateTime.utc(2026, 11, 2),
        updatedAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await session.saveItem(
      VaultItem(
        id: 'past',
        type: VaultItemType.secret,
        title: 'Old',
        username: '',
        password: '',
        notes: 'done',
        reminderDate: '2026-11-01',
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
    );

    expect(reminders.shown, ['today']);
    expect(reminders.scheduled['later'], DateTime(2026, 11, 20, 10));
    expect(reminders.scheduled.containsKey('past'), isFalse);
    expect(reminders.scheduled.containsKey('today'), isFalse);
    expect(noteListLine('change locker\nsecond line'), 'change locker');
    expect(
      visibleVaultItems(
        items: session.items,
        filter: VaultFilter.secrets,
        query: 'second',
      ).single.id,
      'today',
    );
    expect(
      visibleVaultItems(
        items: session.items,
        filter: VaultFilter.assets,
        query: 'locker',
      ),
      isEmpty,
    );

    final assets = await VaultRepository(
      store: assetStore,
      iterations: 1000,
    ).open('sunshine-8');
    final notes = await VaultRepository(
      store: noteStore,
      iterations: 1000,
    ).open('sunshine-8');
    expect(assets.map((item) => item.id), ['asset']);
    expect(notes.map((item) => item.id).toSet(), {'today', 'later', 'past'});
    expect(await assetStore.read(), isNot(contains('change locker')));
    expect(await noteStore.read(), isNot(contains('change locker')));

    final morning = MemoryNoteReminders(clock: () => DateTime(2026, 11, 13, 9));
    await morning.apply(notes.firstWhere((item) => item.id == 'today'));
    expect(morning.shown, isEmpty);
    expect(morning.scheduled['today'], DateTime(2026, 11, 13, 10));

    await session.deleteItem('later');
    expect(reminders.scheduled.containsKey('later'), isFalse);

    final nextReminders = MemoryNoteReminders(
      clock: () => DateTime(2026, 11, 13, 15),
    );
    final next = VaultSession(
      accounts: accounts,
      vaults: VaultRepository(store: assetStore, iterations: 1000),
      notes: VaultRepository(store: noteStore, iterations: 1000),
      reminders: nextReminders,
    );
    expect(
      await next.login(email: 'somi@example.com', masterPassword: 'sunshine-8'),
      LoginResult.success,
    );
    expect(nextReminders.shown, isEmpty);
    expect(nextReminders.scheduled.containsKey('today'), isFalse);
    expect(next.items.map((item) => item.type), contains(VaultItemType.secret));

    await noteStore.write('not a vault');
    final broken = VaultSession(
      accounts: accounts,
      vaults: VaultRepository(store: assetStore, iterations: 1000),
      notes: VaultRepository(store: noteStore, iterations: 1000),
    );
    expect(
      await broken.login(
        email: 'somi@example.com',
        masterPassword: 'sunshine-8',
      ),
      LoginResult.unreadable,
    );
    expect(broken.items, isEmpty);

    final legacy = decodeVaultItems(
      '{"version":1,"items":[{"id":"a","type":"asset","title":"HDFC","username":"u","password":"p","notes":"","createdAt":"2026-01-01T00:00:00.000Z","updatedAt":"2026-01-01T00:00:00.000Z"}]}',
    );
    expect(legacy.single.reminderDate, isNull);
    expect(formatReminderDate(DateTime(2026, 11, 20)), '20/11/2026');
    expect(
      reminderNotificationId('today') == reminderNotificationId('later'),
      isFalse,
    );
  });

  test('backup merges by id and restores future reminders', () async {
    final files = MemoryVaultBackupGateway();
    final reminders = MemoryNoteReminders(
      clock: () => DateTime(2026, 11, 13, 15),
    );
    final session = VaultSession(
      accounts: AccountRepository(
        MemoryKeyValueStore(),
        hasher: const PasswordHasher(iterations: 1000),
      ),
      vaults: VaultRepository(store: MemoryVaultStore(), iterations: 1000),
      notes: VaultRepository(store: MemoryVaultStore(), iterations: 1000),
      reminders: reminders,
      backupFiles: files,
    );
    await session.createAccount(
      email: 'somi@example.com',
      masterPassword: 'sunshine-8',
    );
    await session.saveItem(
      sample(id: 'asset', title: 'HDFC', password: 'vault-secret-xyz'),
    );
    await session.saveItem(
      VaultItem(
        id: 'later',
        type: VaultItemType.secret,
        title: 'Tax',
        username: '',
        password: '',
        notes: 'papers',
        reminderDate: '2026-11-20',
        createdAt: DateTime.utc(2026, 11, 2),
        updatedAt: DateTime.utc(2026, 11, 2),
      ),
    );
    await session.saveItem(
      VaultItem(
        id: 'past',
        type: VaultItemType.secret,
        title: 'Old',
        username: '',
        password: '',
        notes: 'done',
        reminderDate: '2026-11-01',
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
    );

    expect(
      await session.saveBackup('wrong-password'),
      VaultBackupSave.wrongPassword,
    );
    expect(files.saved, isNull);

    expect(await session.saveBackup('sunshine-8'), VaultBackupSave.saved);
    final saved = files.saved;
    expect(saved, isNotNull);
    final text = utf8.decode(saved!);
    expect(text, contains('"kind": "myvault-backup"'));
    expect(text, isNot(contains('vault-secret-xyz')));
    expect(text, isNot(contains('papers')));
    expect(text, isNot(contains('sunshine-8')));
    expect(looksLikeVaultBackup(saved), isTrue);
    expect(
      looksLikeVaultBackup(
        Uint8List.fromList(utf8.encode('{"kind":"myvault-credentials"}')),
      ),
      isFalse,
    );

    final again = await sealVaultBackup(
      assets: session.items
          .where((item) => item.type == VaultItemType.asset)
          .toList(),
      notes: session.items
          .where((item) => item.type == VaultItemType.secret)
          .toList(),
      password: 'sunshine-8',
      iterations: 1000,
    );
    expect(again, isNot(equals(saved)));

    await session.saveItem(sample(id: 'asset', title: 'Changed locally'));
    await session.saveItem(sample(id: 'local', title: 'Phone only'));
    await session.deleteItem('later');
    expect(session.items.map((item) => item.id), isNot(contains('later')));

    files.acceptSave = false;
    expect(await session.saveBackup('sunshine-8'), VaultBackupSave.cancelled);

    expect(
      await session.restoreBackup(
        bytes: saved,
        masterPassword: 'wrong-password',
      ),
      VaultBackupRestore.wrongPassword,
    );
    expect(session.items.map((item) => item.id), contains('local'));
    expect(session.items.map((item) => item.id), isNot(contains('later')));

    expect(
      await session.restoreBackup(
        bytes: Uint8List.fromList(utf8.encode('not a vault file')),
        masterPassword: 'sunshine-8',
      ),
      VaultBackupRestore.notABackup,
    );

    expect(
      await session.restoreBackup(bytes: saved, masterPassword: 'sunshine-8'),
      VaultBackupRestore.restored,
    );
    expect(
      await session.restoreBackup(bytes: saved, masterPassword: 'sunshine-8'),
      VaultBackupRestore.restored,
    );

    final ids = session.items.map((item) => item.id).toList();
    expect(ids.where((id) => id == 'asset'), hasLength(1));
    expect(ids.where((id) => id == 'later'), hasLength(1));
    expect(ids, contains('local'));
    expect(ids, contains('past'));
    expect(
      session.items.firstWhere((item) => item.id == 'asset').title,
      'HDFC',
    );
    expect(
      session.items.firstWhere((item) => item.id == 'later').reminderDate,
      '2026-11-20',
    );
    expect(reminders.scheduled['later'], DateTime(2026, 11, 20, 10));
    expect(reminders.scheduled.containsKey('past'), isFalse);
    expect(reminders.shown, isEmpty);
  });
}
