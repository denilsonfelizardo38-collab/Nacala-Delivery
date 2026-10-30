import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../theme/app_theme.dart';

class CartButton extends StatelessWidget {
  const CartButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = AppScope.of(context).cartItemCount;
    return IconButton(
      onPressed: onTap,
      tooltip: 'Carrinho',
      style: IconButton.styleFrom(
        backgroundColor: context.cardColor,
        foregroundColor: context.inkColor,
        minimumSize: const Size(44, 44),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
