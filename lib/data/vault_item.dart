import 'dart:convert';
import 'dart:math';

import 'package:myvault/data/reminder_date.dart';

enum VaultItemType { asset, secret }

enum VaultFilter { all, assets, secrets }

enum AssetSaveBlock { none, missingTitle, missingPassword }

class VaultItem {
  const VaultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.username,
    required this.password,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.reminderDate,
  });

  final String id;
  final VaultItemType type;
  final String title;
  final String username;
  final String password;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Local calendar day `yyyy-MM-dd`, or null when the note has no reminder.
  final String? reminderDate;

  bool get hasUsername => username.trim().isNotEmpty;

  bool get hasNotes => notes.trim().isNotEmpty;

  Map<String, Object> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'username': username,
      'password': password,
      'notes': notes,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'reminderDate': ?reminderDate,
    };
  }

  static VaultItem fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      type: VaultItemType.values.byName(json['type'] as String),
      title: json['title'] as String,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      reminderDate: _reminderField(json['reminderDate']),
    );
  }
}

String? _reminderField(Object? value) {
  if (value is! String) return null;
  return parseReminderDate(value) == null ? null : value;
}

/// First non-empty line of a secure note, for the vault list.
String noteListLine(String notes) {
  for (final raw in notes.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isNotEmpty) return line;
  }
  return '';
}

String vaultListSubtitle(VaultItem item) {
  if (item.type == VaultItemType.secret) return noteListLine(item.notes);
  return item.username;
}

String newVaultItemId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

String encodeVaultItems(List<VaultItem> items) {
  return jsonEncode({
    'version': 1,
    'items': items.map((item) => item.toJson()).toList(),
  });
}

List<VaultItem> decodeVaultItems(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Vault file is not a record.');
  }
  final rawItems = decoded['items'];
  if (rawItems is! List) {
    throw const FormatException('Vault file has no item list.');
  }
  return [
    for (final raw in rawItems)
      if (raw is Map<String, dynamic>)
        VaultItem.fromJson(raw)
      else if (raw is Map)
        VaultItem.fromJson(raw.cast<String, dynamic>())
      else
        throw const FormatException('Vault item is not a record.'),
  ];
}

/// Literal phrase match. The query is not a pattern: a dot matches a dot.
/// The phrase must appear unbroken, so a space in the stored text stops a match.
bool itemMatchesQuery(VaultItem item, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return item.title.toLowerCase().contains(needle) ||
      item.notes.toLowerCase().contains(needle);
}

List<VaultItem> visibleVaultItems({
  required List<VaultItem> items,
  required VaultFilter filter,
  required String query,
}) {
  final visible = items.where((item) {
    final typeMatches = switch (filter) {
      VaultFilter.all => true,
      VaultFilter.assets => item.type == VaultItemType.asset,
      VaultFilter.secrets => item.type == VaultItemType.secret,
    };
    return typeMatches && itemMatchesQuery(item, query);
  }).toList();
  visible.sort((a, b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    if (byTime != 0) return byTime;
    return a.id.compareTo(b.id);
  });
  return visible;
}

enum NoteSaveBlock { none, missingTitle }

NoteSaveBlock noteSaveBlock({required String title}) {
  if (title.trim().isEmpty) return NoteSaveBlock.missingTitle;
  return NoteSaveBlock.none;
}

AssetSaveBlock assetSaveBlock({
  required String title,
  required String password,
}) {
  if (title.trim().isEmpty) return AssetSaveBlock.missingTitle;
  if (password.isEmpty) return AssetSaveBlock.missingPassword;
  return AssetSaveBlock.none;
}
