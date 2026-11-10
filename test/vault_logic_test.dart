import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/data/key_value_store.dart';
import 'package:myvault/data/password_generator.dart';
import 'package:myvault/data/password_hasher.dart';
import 'package:myvault/data/vault_item.dart';
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
    final bank = sample(title: 'HDFC Bank', username: 'somila', notes: 'locker');
    final mine = sample(id: 'b', title: 'myhdfc');
    final joined = sample(id: 'c', title: 'hdfcbank');
    final spaced = sample(id: 'd', title: 'hd fcoo');
    final noted = sample(id: 'e', title: 'Rent', username: 'hdfc-user', notes: 'pay hdfc');
    final dotted = sample(id: 'f', title: 'h.fc');

    expect(itemMatchesQuery(bank, 'hdfc'), isTrue);
    expect(itemMatchesQuery(mine, 'hdfc'), isTrue);
    expect(itemMatchesQuery(joined, 'hdfc'), isTrue);
    expect(itemMatchesQuery(spaced, 'hdfc'), isFalse);
    expect(itemMatchesQuery(noted, 'hdfc'), isTrue);
    expect(itemMatchesQuery(sample(title: 'Rent', username: 'hdfc-user'), 'hdfc'), isFalse);
    expect(itemMatchesQuery(bank, 'h.fc'), isFalse);
    expect(itemMatchesQuery(dotted, 'h.fc'), isTrue);
    expect(itemMatchesQuery(bank, '   '), isTrue);
  });

  test('visible rows keep duplicates and put the newest first', () {
    final older = sample(id: 'old', createdAt: DateTime.utc(2020));
    final newer = sample(id: 'new', title: 'HDFC', createdAt: DateTime.utc(2024));
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
    expect(
      assetSaveBlock(title: 'Rent', password: ' '),
      AssetSaveBlock.none,
    );
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
    await first.persist([
      sample(password: 'vault-secret-xyz', title: 'HDFC'),
    ]);
    final raw = await store.read();
    expect(raw, isNotNull);
    expect(raw, isNot(contains('vault-secret-xyz')));
    expect(raw, isNot(contains('sunshine-8')));
    first.lock();

    final second = VaultRepository(store: store, iterations: 1000);
    await expectLater(second.open('wrong-password'), throwsA(isA<VaultUnreadable>()));
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
    );
    await session.createAccount(email: 'somi@example.com', masterPassword: 'sunshine-8');
    expect(await store.read(), isNotNull);
    await session.saveItem(sample());
    expect(session.items, hasLength(1));

    await session.deleteAccount();
    expect(await store.read(), isNull);
    expect(session.items, isEmpty);
    expect(session.hasAccount, isFalse);
  });
}
