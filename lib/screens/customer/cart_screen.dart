import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'checkout_screen.dart';
import 'store_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponController = TextEditingController();
  bool _couponLoading = false;
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim();
    if (code.isEmpty) {
      setState(() => _couponError = 'Indique o código do cupão.');
      return;
    }
    setState(() {
      _couponLoading = true;
      _couponError = null;
    });
    try {
      final discount = await AppScope.of(context).applyCoupon(code);
      if (!mounted) return;
      showAppSnack(
        context,
        'Cupão aplicado: ${formatMoney(discount)} de desconto.',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _couponError = error.message);
    } finally {
      if (mounted) setState(() => _couponLoading = false);
    }
  }

  Future<void> _clearCart() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Esvaziar carrinho',
      message: 'Todos os itens serão removidos do carrinho.',
      confirmLabel: 'Esvaziar',
      destructive: true,
    );
    if (!confirmed) return;
    if (!mounted) return;
    AppScope.of(context).clearCart();
  }

  Future<void> _editNote(String productId, String? current) async {
    final state = AppScope.of(context);
    final note = await showTextPrompt(
      context,
      title: 'Nota do item',
      label: 'Observação para o parceiro',
      initialValue: current,
      hint: 'Ex.: sem pimenta, bem passado...',
      maxLines: 3,
      confirmLabel: 'Guardar nota',
    );
    if (note == null) return;
    state.setLineNote(productId, note);
  }

  void _continue() {
    final state = AppScope.of(context);
    if (state.isCartEmpty) return;
    if (state.isGuest) {
      state.exitGuestMode();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (!state.isSignedIn) {
      Navigator.of(context).pushNamed('/login');
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final empty = state.isCartEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrinho'),
        actions: [
          if (!empty)
            IconButton(
              tooltip: 'Esvaziar carrinho',
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: empty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'O carrinho está vazio',
                    message:
                        'Explore os parceiros de Nacala-Porto e adicione os '
                        'produtos que precisa.',
                    actionLabel: 'Ver estabelecimentos',
                    onAction: () => Navigator.of(context).pop(),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _StoreCard(
                    name: state.cartStore?.name ?? '',
                    imageUrl: state.cartStore?.imageUrl,
                    itemCount: state.cartItemCount,
                    onTap: () {
                      final id = state.cartStore?.id;
                      if (id == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoreScreen(establishmentId: id),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SectionTitle(
                    title: 'Itens',
                    subtitle: '${state.cartItemCount} unidade(s) no carrinho',
                  ),
                  const SizedBox(height: 10),
                  for (final line in state.cart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CartLineCard(
                        line: line,
                        onIncrement: () => state.increment(line.product.id),
                        onDecrement: () => state.decrement(line.product.id),
                        onRemove: () => state.removeLine(line.product.id),
                        onEditNote: () => _editNote(line.product.id, line.note),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!state.isGuest)
                    _CouponCard(
                      controller: _couponController,
                      loading: _couponLoading,
                      error: _couponError,
                      appliedCode: state.couponCode,
                      discountCents: state.couponDiscountCents,
                      onApply: _applyCoupon,
                      onRemove: () {
                        state.removeCoupon();
                        _couponController.clear();
                        setState(() => _couponError = null);
                      },
                    ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      children: [
                        PriceLine(
                          label: 'Subtotal',
                          cents: state.cartSubtotalCents,
                        ),
                        PriceLine(
                          label: 'Taxa de entrega',
                          cents: state.cartDeliveryFeeCents,
                        ),
                        if (state.couponDiscountCents > 0)
                          PriceLine(
                            label: 'Desconto (${state.couponCode})',
                            cents: -state.couponDiscountCents,
                            color: context.successColor,
                          ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(),
                        ),
                        PriceLine(
                          label: 'Total estimado',
                          cents: state.cartTotalCents,
                          strong: true,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: context.mutedColor,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'O total final é calculado pelo servidor ao '
                                'confirmar o pedido.',
                                style: TextStyle(
                                  color: context.mutedColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: empty
          ? null
          : Material(
              color: context.cardColor,
              elevation: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total',
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              formatMoney(state.cartTotalCents),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 166,
                        child: FilledButton.icon(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: Text(
                            state.isGuest
                                ? 'Entrar para pedir'
                                : 'Finalizar pedido',
                          ),
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

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.name,
    required this.imageUrl,
    required this.itemCount,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          NetworkThumb(
            imageUrl: imageUrl,
            icon: Icons.storefront_rounded,
            size: 50,
            radius: 13,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A sua encomenda',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '$itemCount ${itemCount == 1 ? 'unidade' : 'unidades'}',
                  style: TextStyle(color: context.mutedColor, fontSize: 10),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.mutedColor),
        ],
      ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({
    required this.line,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onEditNote,
  });

  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    final note = line.note;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkThumb(
                imageUrl: line.product.imageUrl,
                icon: Icons.restaurant_rounded,
                size: 64,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatMoney(line.product.priceCents)} / unidade',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remover item',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? AppColors.darkElevated
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 15,
                    color: context.mutedColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(color: context.mutedColor, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: onEditNote,
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: Text(note == null ? 'Adicionar nota' : 'Editar nota'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
              QuantityStepper(
                quantity: line.quantity,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  formatMoney(line.totalCents),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.controller,
    required this.loading,
    required this.error,
    required this.appliedCode,
    required this.discountCents,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final bool loading;
  final String? error;
  final String? appliedCode;
  final int discountCents;
  final VoidCallback onApply;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cupão', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          if (appliedCode != null)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_offer_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        appliedCode!,
                        style: const TextStyle(
                          color: AppColors.greenInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '−${formatMoney(discountCents)}',
                        style: const TextStyle(
                          color: AppColors.greenInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: onRemove, child: const Text('Remover')),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'Código do cupão',
                      isDense: true,
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: FilledButton.tonal(
                    onPressed: loading ? null : onApply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aplicar'),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
