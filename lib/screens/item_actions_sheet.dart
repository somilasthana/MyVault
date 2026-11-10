import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/screens/asset_form_screen.dart';
import 'package:myvault/screens/asset_view_screen.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/vault_kind_icon.dart';
import 'package:myvault/widgets/vault_widgets.dart';

Future<void> showItemActions(BuildContext context, VaultItem item) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      side: BorderSide(color: VaultColors.ink, width: 3),
    ),
    builder: (context) => ItemActionsSheet(item: item),
  );
}

class ItemActionsSheet extends StatefulWidget {
  const ItemActionsSheet({required this.item, super.key});

  final VaultItem item;

  @override
  State<ItemActionsSheet> createState() => _ItemActionsSheetState();
}

class _ItemActionsSheetState extends State<ItemActionsSheet> {
  var _showPassword = false;

  VaultItem get item => widget.item;

  void _open(Widget screen) {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete this item?'),
          content: const Text('This removes it from this phone permanently.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Yes',
                style: TextStyle(color: VaultColors.pinkDeep, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await VaultScope.of(context).deleteItem(item.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                VaultKindIcon(type: item.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (_showPassword)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: VaultColors.lemon,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: VaultColors.ink, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    item.password,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          _Action(
            icon: Icons.open_in_new_rounded,
            label: 'View',
            onTap: () => _open(AssetViewScreen(itemId: item.id)),
          ),
          _Action(
            icon: Icons.edit_rounded,
            label: 'Edit',
            onTap: () => _open(AssetFormScreen(existing: item)),
          ),
          _Action(
            icon: _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            label: _showPassword ? 'Hide password' : 'Show password',
            onTap: () => setState(() => _showPassword = !_showPassword),
          ),
          _Action(
            icon: Icons.copy_rounded,
            label: 'Copy password',
            onTap: () => copyVaultValue(context, item.password, 'Password copied'),
          ),
          _Action(
            icon: Icons.copy_rounded,
            label: 'Copy username',
            enabled: item.hasUsername,
            onTap: item.hasUsername
                ? () => copyVaultValue(context, item.username, 'Username copied')
                : null,
          ),
          _Action(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            danger: true,
            onTap: _delete,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? const Color(0xFFCBB8D6)
        : danger
        ? VaultColors.pinkDeep
        : VaultColors.ink;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
