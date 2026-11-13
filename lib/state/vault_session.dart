import 'package:flutter/foundation.dart';
import 'package:myvault/data/account_repository.dart';
import 'package:myvault/data/credential_backup.dart';
import 'package:myvault/data/shared_asset.dart';
import 'package:myvault/data/shared_asset_gateway.dart';
import 'package:myvault/data/note_reminders.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/data/vault_repository.dart';

class VaultSession extends ChangeNotifier {
  VaultSession({
    required this.accounts,
    required this.vaults,
    required this.notes,
    NoteReminders? reminders,
    CredentialBackup? backup,
    SharedAssetGateway? sharing,
    this.shareIterations = defaultShareIterations,
  }) : reminders = reminders ?? const NoopNoteReminders(),
       _backup = backup ?? DriveCredentialBackup(),
       sharing = sharing ?? SystemSharedAssetGateway();

  final AccountRepository accounts;
  final CredentialBackup _backup;
  final SharedAssetGateway sharing;
  final int shareIterations;
  final VaultRepository vaults;
  final VaultRepository notes;
  final NoteReminders reminders;

  bool busy = false;
  bool hasAccount = false;
  bool rememberEmail = true;
  bool rememberPassword = false;
  String? savedEmail;
  String? prefilledPassword;
  List<VaultItem> _assets = const [];
  List<VaultItem> _notes = const [];

  List<VaultItem> get items {
    final next = [..._assets, ..._notes];
    _sort(next);
    return List.unmodifiable(next);
  }

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
        _assets = await vaults.open(masterPassword);
        _notes = await notes.open(masterPassword);
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
        final assetItems = await vaults.open(masterPassword);
        final noteItems = await notes.open(masterPassword);
        _assets = assetItems;
        _notes = noteItems;
        try {
          await reminders.sync(noteItems);
        } catch (_) {}
      } on VaultUnreadable {
        vaults.lock();
        notes.lock();
        _assets = const [];
        _notes = const [];
        return LoginResult.unreadable;
      }
      return LoginResult.success;
    });
  }

  Future<void> saveItem(VaultItem item) async {
    final secret = item.type == VaultItemType.secret;
    final current = secret ? _notes : _assets;
    final repo = secret ? notes : vaults;
    final next = [...current];
    final index = next.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      next[index] = item;
    } else {
      next.add(item);
    }
    await repo.persist(next);
    if (secret) {
      _notes = next;
    } else {
      _assets = next;
    }
    notifyListeners();
    if (!secret) return;
    try {
      await reminders.apply(item);
    } catch (_) {}
  }

  Future<void> deleteItem(String id) async {
    if (_notes.any((entry) => entry.id == id)) {
      final next = _notes.where((entry) => entry.id != id).toList();
      await notes.persist(next);
      _notes = next;
      try {
        await reminders.cancel(id);
      } catch (_) {}
    } else if (_assets.any((entry) => entry.id == id)) {
      final next = _assets.where((entry) => entry.id != id).toList();
      await vaults.persist(next);
      _assets = next;
    }
    notifyListeners();
  }

  void lock() {
    vaults.lock();
    notes.lock();
    _assets = const [];
    _notes = const [];
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
    try {
      await reminders.cancelAll();
    } catch (_) {}
    await vaults.deleteAll();
    await notes.deleteAll();
    _assets = const [];
    _notes = const [];
    await accounts.deleteAccount();
    await load();
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
