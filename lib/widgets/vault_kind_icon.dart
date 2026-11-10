import 'package:flutter/material.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/theme/vault_theme.dart';

class VaultKindIcon extends StatelessWidget {
  const VaultKindIcon({required this.type, this.size = 48, super.key});

  final VaultItemType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final secret = type == VaultItemType.secret;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: secret ? VaultColors.lemon : VaultColors.blush,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: VaultColors.ink, width: 2.5),
      ),
      child: Icon(
        secret ? Icons.sticky_note_2_rounded : Icons.account_balance_wallet_rounded,
        color: VaultColors.ink,
        size: size * 0.5,
      ),
    );
  }
}
