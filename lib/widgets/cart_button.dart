import 'package:flutter/material.dart';

import '../screens/customer/cart_screen.dart';
import '../state/app_scope.dart';

/// Ícone de carrinho com contador, usado nos ecrãs do cliente.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = AppScope.of(context).cartItemCount;
    return IconButton(
      tooltip: 'Carrinho',
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CartScreen())),
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
