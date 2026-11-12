import 'package:flutter/foundation.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/data/credential_backup.dart';
import 'package:myvault/data/shared_asset.dart';
import 'package:myvault/data/shared_asset_gateway.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/data/vault_repository.dart';

class VaultSession extends ChangeNotifier {
  VaultSession({
    required this.accounts,
    required this.vaults,
    CredentialBackup? backup,
    SharedAssetGateway? sharing,
    this.shareIterations = defaultShareIterations,
  }) : _backup = backup ?? DriveCredentialBackup(),
       sharing = sharing ?? SystemSharedAssetGateway();

  final AccountRepository accounts;
  final CredentialBackup _backup;
  final SharedAssetGateway sharing;
  final int shareIterations;
  final VaultRepository vaults;

  bool busy = false;
  bool hasAccount = false;
  bool rememberEmail = true;
  bool rememberPassword = false;
  String? savedEmail;
  String? prefilledPassword;
  List<VaultItem> _items = const [];

  List<VaultItem> get items => List.unmodifiable(_items);

  Future<void> load() async {
    final snapshot = await accounts.read();
    hasAccount = snapshot.hasAccount;
    rememberEmail = snapshot.rememberEmail;
    rememberPassword = snapshot.rememberPassword;
    savedEmail = snapshot.email;
    prefilledPassword = snapshot.prefilledPassword;
    notifyListeners();
  }

  Future<AccountWriteResult> createAccount({
    required String email,
    required String masterPassword,
  }) async {
    return _guard(() async {
      final result = await accounts.createAccount(
        email: email,
        masterPassword: masterPassword,
        rememberPassword: rememberPassword,
      );
      if (result == AccountWriteResult.created) {
        await load();
        _setItems(await vaults.open(masterPassword));
      }
      return result;
    });
  }

  Future<LoginResult> login({
    required String email,
    required String masterPassword,
  }) {
    return _guard(() async {
      final result = await accounts.login(
        email: email,
        masterPassword: masterPassword,
        rememberPassword: rememberPassword,
      );
      if (result != LoginResult.success) return result;
      await load();
      try {
        _setItems(await vaults.open(masterPassword));
      } on VaultUnreadable {
        return LoginResult.unreadable;
      }
      return LoginResult.success;
    });
  }

  Future<void> saveItem(VaultItem item) async {
    final next = [..._items];
    final index = next.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    _sort(next);
    await vaults.persist(next);
    _items = next;
    notifyListeners();
  }

  Future<void> deleteItem(String id) async {
    final next = _items.where((entry) => entry.id != id).toList();
    await vaults.persist(next);
    _items = next;
    notifyListeners();
  }

  void lock() {
    vaults.lock();
    _items = const [];
    notifyListeners();
  }

  Future<bool> saveCredentials({
    required String email,
    required String masterPassword,
  }) {
    return _backup.save(email: email, masterPassword: masterPassword);
  }

  Future<void> setRememberEmail(bool value) async {
    await accounts.setRememberEmail(value);
    rememberEmail = value;
    notifyListeners();
  }

  Future<void> setRememberPassword(bool value) async {
    await accounts.setRememberPassword(value);
    rememberPassword = value;
    if (!value) prefilledPassword = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await vaults.deleteAll();
    _items = const [];
    await accounts.deleteAccount();
    await load();
  }

  void _setItems(List<VaultItem> items) {
    final next = [...items];
    _sort(next);
    _items = next;
  }

  void _sort(List<VaultItem> items) {
    items.sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      if (byTime != 0) return byTime;
      return a.id.compareTo(b.id);
    });
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
