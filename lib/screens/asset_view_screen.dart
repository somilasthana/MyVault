import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/screens/asset_form_screen.dart';
import 'package:myvault/screens/secure_note_form_screen.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/vault_kind_icon.dart';
import 'package:myvault/widgets/vault_widgets.dart';

class AssetViewScreen extends StatefulWidget {
  const AssetViewScreen({required this.itemId, super.key});

  final String itemId;

  @override
  State<AssetViewScreen> createState() => _AssetViewScreenState();
}

class _AssetViewScreenState extends State<AssetViewScreen> {
  var _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final session = VaultScope.of(context);
    final item = session.items
        .where((entry) => entry.id == widget.itemId)
        .firstOrNull;
    if (item == null) {
      return const AuthScaffold(child: SizedBox.shrink());
    }

    final passwordText = _showPassword
        ? item.password
        : '*' * item.password.length;
    return AuthScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StickerIconButton(
                  tooltip: 'Back',
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                StickerIconButton(
                  tooltip: 'Edit',
                  icon: Icons.edit_rounded,
                  onPressed: () {
                    final secret = item.type == VaultItemType.secret;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => secret
                            ? SecureNoteFormScreen(existing: item)
                            : AssetFormScreen(existing: item),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: ListView(
                  children: [
                    Row(
                      children: [
                        VaultKindIcon(type: item.type, size: 56),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (item.type == VaultItemType.secret) ...[
                      _DetailCard(
                        label: 'Note',
                        value: item.notes,
                        copyTooltip: 'Copy note',
                        onCopy: item.hasNotes
                            ? () => copyVaultValue(
                                context,
                                item.notes,
                                'Note copied',
                              )
                            : null,
                      ),
                      if (parseReminderDate(item.reminderDate) != null) ...[
                        const SizedBox(height: 12),
                        _DetailCard(
                          label: 'Reminder',
                          value: reminderTriggerLine(
                            parseReminderDate(item.reminderDate)!,
                          ),
                          copyTooltip: '',
                          onCopy: null,
                          showCopy: false,
                        ),
                      ],
                    ] else ...[
                      _DetailCard(
                        label: 'Username',
                        value: item.username,
                        copyTooltip: 'Copy username',
                        onCopy: item.hasUsername
                            ? () => copyVaultValue(
                                context,
                                item.username,
                                'Username copied',
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _DetailCard(
                        label: 'Password',
                        value: passwordText,
                        copyTooltip: 'Copy password',
                        onCopy: () => copyVaultValue(
                          context,
                          item.password,
                          'Password copied',
                        ),
                        trailing: IconButton(
                          tooltip: _showPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: VaultColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DetailCard(
                        label: 'Notes',
                        value: item.notes,
                        copyTooltip: 'Copy notes',
                        onCopy: item.hasNotes
                            ? () => copyVaultValue(
                                context,
                                item.notes,
                                'Notes copied',
                              )
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.label,
    required this.value,
    required this.copyTooltip,
    required this.onCopy,
    this.trailing,
    this.showCopy = true,
  });

  final String label;
  final String value;
  final String copyTooltip;
  final VoidCallback? onCopy;
  final Widget? trailing;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    final enabled = onCopy != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VaultColors.ink, width: 2.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: VaultColors.grape,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? ' ' : value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (showCopy)
              IconButton(
                tooltip: enabled ? copyTooltip : null,
                onPressed: onCopy,
                icon: Icon(
                  Icons.copy_rounded,
                  color: enabled ? VaultColors.grape : const Color(0xFFCBB8D6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
