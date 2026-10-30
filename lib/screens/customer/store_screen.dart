import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/place.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../utils/feedback.dart';
import '../../utils/formatters.dart';
import '../../widgets/quantity_stepper.dart';
import 'cart_screen.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key, required this.place});

  final Place place;

  void _add(BuildContext context, Product product) {
    final state = AppScope.of(context);
    final replaced = state.addProduct(place, product);
    if (replaced) {
      showMessage(
        context,
        'Carrinho reiniciado: os pedidos são de um local por vez.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final products = productsFor(place.id);
    final hasCart = !state.isCartEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(place.name),
        actions: [
          IconButton(
            tooltip: 'Carrinho',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const CartScreen())),
            icon: Badge(
              isLabelVisible: hasCart,
              label: Text('${state.cartItemCount}'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: place.tint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        place.icon,
                        color: context.accentColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: TextStyle(
                              color: context.inkColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            place.address,
                            style: TextStyle(
                              color: context.mutedColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      icon: Icons.star_rounded,
                      label: formatRating(place.rating),
                    ),
                    _InfoPill(
                      icon: Icons.schedule_rounded,
                      label: place.deliveryTime,
                    ),
                    _InfoPill(
                      icon: Icons.delivery_dining_rounded,
                      label: formatMoney(place.deliveryFee),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Menu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${products.length} artigos disponíveis',
            style: TextStyle(color: context.mutedColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final product in products)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProductTile(
                product: product,
                quantity: state.quantityOf(product),
                onAdd: () => _add(context, product),
                onRemove: () => state.decrementProduct(product),
              ),
            ),
        ],
      ),
      bottomNavigationBar: hasCart ? _CartBar(state: state) : null,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.accentColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: context.inkColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  product.name,
                  style: TextStyle(
                    color: context.inkColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.description,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
                const SizedBox(height: 7),
                Text(
                  formatMoney(product.price),
                  style: TextStyle(
                    color: context.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          QuantityStepper(
            quantity: quantity,
            onAdd: onAdd,
            onRemove: onRemove,
            addLabel: 'Adicionar ${product.name}',
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const CartScreen())),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Ver carrinho · ${state.cartItemCount} itens',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Text(formatMoney(state.total)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
