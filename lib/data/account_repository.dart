import 'package:myvault/data/key_value_store.dart';
import 'package:myvault/data/password_hasher.dart';

enum AccountWriteResult { created, alreadyExists }

enum LoginResult { success, noAccount, mismatch, unreadable }

class AccountSnapshot {
  const AccountSnapshot({
    required this.hasAccount,
    required this.rememberEmail,
    required this.rememberPassword,
    this.email,
    this.prefilledPassword,
  });

  final bool hasAccount;
  final bool rememberEmail;
  final bool rememberPassword;
  final String? email;
  final String? prefilledPassword;
}

class AccountRepository {
  AccountRepository(this._store, {PasswordHasher? hasher})
    : _hasher = hasher ?? const PasswordHasher();

  final KeyValueStore _store;
  final PasswordHasher _hasher;

  static const emailKey = 'vault.email';
  static const saltKey = 'vault.salt';
  static const hashKey = 'vault.hash';
  static const rememberedPasswordKey = 'vault.remembered-password';
  static const rememberEmailKey = 'vault.remember-email';
  static const rememberPasswordKey = 'vault.remember-password';

  Future<AccountSnapshot> read() async {
    final email = await _store.read(emailKey);
    final hash = await _store.read(hashKey);
    final rememberEmail = (await _store.read(rememberEmailKey)) != 'false';
    final rememberPassword = (await _store.read(rememberPasswordKey)) == 'true';
    final prefilledPassword = rememberPassword
        ? await _store.read(rememberedPasswordKey)
        : null;

    return AccountSnapshot(
      hasAccount: email != null && hash != null,
      email: email,
      rememberEmail: rememberEmail,
      rememberPassword: rememberPassword,
      prefilledPassword: prefilledPassword,
    );
  }

  Future<AccountWriteResult> createAccount({
    required String email,
    required String masterPassword,
    required bool rememberPassword,
  }) async {
    final snapshot = await read();
    if (snapshot.hasAccount) return AccountWriteResult.alreadyExists;

    final digest = await _hasher.hash(masterPassword);
    await _store.write(emailKey, email.trim().toLowerCase());
    await _store.write(saltKey, digest.salt);
    await _store.write(hashKey, digest.hash);
    await _rememberPassword(
      remember: rememberPassword,
      masterPassword: masterPassword,
    );
    return AccountWriteResult.created;
  }

  Future<LoginResult> login({
    required String email,
    required String masterPassword,
    required bool rememberPassword,
  }) async {
    final storedEmail = await _store.read(emailKey);
    final salt = await _store.read(saltKey);
    final hash = await _store.read(hashKey);
    if (storedEmail == null || salt == null || hash == null) {
      return LoginResult.noAccount;
    }
    final emailMatches = storedEmail == email.trim().toLowerCase();
    final passwordMatches = emailMatches &&
        await _hasher.verify(password: masterPassword, salt: salt, hash: hash);
    if (!passwordMatches) return LoginResult.mismatch;

    await _rememberPassword(
      remember: rememberPassword,
      masterPassword: masterPassword,
    );
    return LoginResult.success;
  }

  Future<void> setRememberEmail(bool value) {
    return _store.write(rememberEmailKey, value ? 'true' : 'false');
  }

  Future<void> setRememberPassword(bool value) async {
    await _store.write(rememberPasswordKey, value ? 'true' : 'false');
    if (!value) await _store.delete(rememberedPasswordKey);
  }

  Future<void> deleteAccount() async {
    await _store.delete(emailKey);
    await _store.delete(saltKey);
    await _store.delete(hashKey);
    await _store.delete(rememberedPasswordKey);
  }

  Future<void> _rememberPassword({
    required bool remember,
    required String masterPassword,
  }) async {
    if (remember) {
      await _store.write(rememberedPasswordKey, masterPassword);
    } else {
      await _store.delete(rememberedPasswordKey);
    }
  }
}
