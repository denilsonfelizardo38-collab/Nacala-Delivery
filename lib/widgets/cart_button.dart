import 'package:flutter/material.dart';

import '../state/app_scope.dart';

/// Ícone de carrinho com contador, usado nos ecrãs do cliente.
class CartButton extends StatelessWidget {
  const CartButton({super.key, this.color});

  /// Cor do ícone; por omissão usa o `foregroundColor` do tema (o típico
  /// cinza escuro em app bars claras). Passa `Colors.white` ao integrar em
  /// superfícies laranja/escuras.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final count = AppScope.of(context).cartItemCount;
    return IconButton(
      tooltip: 'Carrinho',
      onPressed: () => Navigator.of(context).pushNamed('/cart'),
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: Icon(Icons.shopping_bag_outlined, color: color),
      ),
    );
  }
}
