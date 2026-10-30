import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/quantity_stepper.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final place = state.cartPlace;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrinho'),
        actions: [
          if (!state.isCartEmpty)
            TextButton(
              onPressed: () {
                state.clearCart();
                Navigator.of(context).pop();
              },
              child: const Text('Limpar'),
            ),
        ],
      ),
      body: state.isCartEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'O carrinho está vazio',
                  subtitle:
                      'Escolha um restaurante, mercado ou loja para começar.',
                  action: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Explorar locais'),
                  ),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (place != null)
                  Row(
                    children: [
                      Icon(place.icon, size: 18, color: context.accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          place.name,
                          style: TextStyle(
                            color: context.inkColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${state.cartItemCount} itens',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                for (final line in state.cart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.product.name,
                                  style: TextStyle(
                                    color: context.inkColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  formatMoney(line.product.price),
                                  style: TextStyle(
                                    color: context.mutedColor,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatMoney(line.total),
                                  style: TextStyle(
                                    color: context.accentColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          QuantityStepper(
                            quantity: line.quantity,
                            onAdd: () => state.addProduct(place!, line.product),
                            onRemove: () =>
                                state.decrementProduct(line.product),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Subtotal',
                        value: formatMoney(state.subtotal),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Taxa de entrega',
                        value: formatMoney(state.deliveryFee),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: context.lineColor, height: 1),
                      ),
                      _SummaryRow(
                        label: 'Total',
                        value: formatMoney(state.total),
                        emphasized: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: state.isCartEmpty
          ? null
          : Material(
              color: context.cardColor,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CheckoutScreen(),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('Continuar'),
                        const Spacer(),
                        Text(formatMoney(state.total)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized ? context.inkColor : context.mutedColor,
              fontSize: emphasized ? 14 : 12,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.inkColor,
            fontSize: emphasized ? 15 : 12,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
