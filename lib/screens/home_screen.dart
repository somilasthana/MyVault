import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/screens/asset_form_screen.dart';
import 'package:myvault/screens/item_actions_sheet.dart';
import 'package:myvault/screens/login_screen.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/vault_kind_icon.dart';
import 'package:myvault/widgets/vault_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({this.notice, super.key});

  final String? notice;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _search = TextEditingController();
  var _filter = VaultFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _logOut() {
    VaultScope.of(context).lock();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _onNew(String choice) {
    if (choice == 'secret') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Secure notes are coming in the next phase.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AssetFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = VaultScope.of(context);
    final visible = visibleVaultItems(
      items: session.items,
      filter: _filter,
      query: _search.text,
    );
    return AuthScaffold(
      scaffoldKey: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: VaultColors.cream,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: VaultColors.ink, width: 3),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Menu',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              ListTile(
                key: const Key('log-out'),
                leading: const Icon(Icons.logout_rounded, color: VaultColors.ink),
                title: const Text(
                  'Log out',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                onTap: _logOut,
              ),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StickerIconButton(
                  tooltip: 'Open menu',
                  icon: Icons.menu_rounded,
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'My Asset Vault',
                    maxLines: 2,
                    style: TextStyle(fontSize: 26, height: 1.05, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _NewButton(onSelected: _onNew),
              ],
            ),
            if (widget.notice != null) ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FBFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: VaultColors.ink, width: 2.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    widget.notice!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('search-assets'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              cursorColor: VaultColors.pink,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search my assets',
                hintStyle: const TextStyle(color: Color(0xFFB89BC4)),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search_rounded, color: VaultColors.ink),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, color: VaultColors.ink),
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                enabledBorder: _searchBorder(VaultColors.ink),
                focusedBorder: _searchBorder(VaultColors.pink),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _FilterChip(
                  chipKey: const Key('filter-all'),
                  label: 'All Items',
                  icon: Icons.apps_rounded,
                  selected: _filter == VaultFilter.all,
                  onTap: () => setState(() => _filter = VaultFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  chipKey: const Key('filter-assets'),
                  label: 'Assets',
                  icon: Icons.account_balance_wallet_rounded,
                  selected: _filter == VaultFilter.assets,
                  onTap: () => setState(() => _filter = VaultFilter.assets),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  chipKey: const Key('filter-secret'),
                  label: 'Secret',
                  icon: Icons.sticky_note_2_rounded,
                  selected: _filter == VaultFilter.secrets,
                  onTap: () => setState(() => _filter = VaultFilter.secrets),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: const BorderSide(color: VaultColors.ink, width: 3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        'My Items (${visible.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: visible.isEmpty
                          ? _EmptyList(message: _emptyMessage(session.items, visible))
                          : ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                itemCount: visible.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF3D7E6),
                                ),
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  return InkWell(
                                    key: ValueKey(item.id),
                                    onTap: () => showItemActions(context, item),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          VaultKindIcon(type: item.type, size: 44),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                Text(
                                                  item.username.isEmpty ? ' ' : item.username,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF6E5684),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyMessage(List<VaultItem> all, List<VaultItem> visible) {
    if (visible.isNotEmpty) return '';
    if (_filter == VaultFilter.secrets && _search.text.trim().isEmpty) {
      return 'No secret notes yet';
    }
    if (all.isEmpty && _search.text.trim().isEmpty) return 'The shelves are empty';
    return 'Nothing matches';
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          textStyle: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: VaultColors.ink,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: VaultColors.ink, width: 2.5),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        key: const Key('vault-new'),
        tooltip: 'New',
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'asset', child: Text('+ Add Asset Item')),
          PopupMenuItem(value: 'secret', child: Text('+ Add Secure Note')),
        ],
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VaultColors.pink,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VaultColors.ink, width: 2.5),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'New',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.expand_more_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.chipKey,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Key chipKey;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : VaultColors.ink;
    return Expanded(
      child: Material(
        color: selected ? VaultColors.pink : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: VaultColors.ink, width: 2),
        ),
        child: InkWell(
          key: chipKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final shelves = message == 'The shelves are empty';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✦', style: TextStyle(fontSize: 28, color: VaultColors.pink)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (shelves) ...[
              const SizedBox(height: 6),
              const Text(
                'Add an asset with New.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFF6E5684)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

OutlineInputBorder _searchBorder(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: 2.5),
  );
}
