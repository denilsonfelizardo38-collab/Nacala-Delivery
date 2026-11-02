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

const _brandOrange = Color(0xFFFF7900);
const _brandBlack = Color(0xFF151515);

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
    if (!confirmed || !mounted) return;
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final empty = state.isCartEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: _brandBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O meu carrinho',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            SizedBox(height: 2),
            Text(
              'NACALA DELIVERY',
              style: TextStyle(
                color: _brandOrange,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
        actions: [
          if (!empty)
            IconButton(
              tooltip: 'Esvaziar carrinho',
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: empty
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            color: _brandOrange.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: _brandOrange,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'O carrinho está vazio',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explore os parceiros de Nacala-Porto e adicione '
                          'os produtos que precisa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.mutedColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.storefront_rounded),
                            label: const Text('Ver estabelecimentos'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _brandOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
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
                  const SizedBox(height: 24),
                  SectionTitle(
                    title: 'Os teus artigos',
                    subtitle: '${state.cartItemCount} unidade(s) no carrinho',
                  ),
                  const SizedBox(height: 12),
                  for (final line in state.cart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CartLineCard(
                        line: line,
                        onIncrement: () => state.increment(line.product.id),
                        onDecrement: () => state.decrement(line.product.id),
                        onRemove: () => state.removeLine(line.product.id),
                        onEditNote: () =>
                            _editNote(line.product.id, line.note),
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
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        PriceLine(
                          label: 'Subtotal',
                          cents: state.cartSubtotalCents,
                        ),
                        const SizedBox(height: 10),
                        PriceLine(
                          label: 'Taxa de entrega',
                          cents: state.cartDeliveryFeeCents,
                        ),
                        if (state.couponDiscountCents > 0) ...[
                          const SizedBox(height: 10),
                          PriceLine(
                            label: 'Desconto (${state.couponCode})',
                            cents: -state.couponDiscountCents,
                            color: context.successColor,
                          ),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(height: 1),
                        ),
                        PriceLine(
                          label: 'Total estimado',
                          cents: state.cartTotalCents,
                          strong: true,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: context.isDarkMode
                                ? AppColors.darkElevated
                                : AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: context.mutedColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'O total final é calculado pelo servidor '
                                  'ao confirmar o pedido.',
                                  style: TextStyle(
                                    color: context.mutedColor,
                                    fontSize: 11,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.10),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'TOTAL A PAGAR',
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              formatMoney(state.cartTotalCents),
                              style: const TextStyle(
                                color: _brandOrange,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 178,
                        child: FilledButton.icon(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandOrange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: Text(
                            state.isGuest
                                ? 'Entrar para pedir'
                                : 'Finalizar pedido',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
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
      padding: const EdgeInsets.all(15),
      radius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _brandOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: NetworkThumb(
              imageUrl: imageUrl,
              icon: Icons.storefront_rounded,
              size: 54,
              radius: 13,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A TUA ENCOMENDA',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '$itemCount ${itemCount == 1 ? 'unidade' : 'unidades'}',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _brandOrange),
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
      padding: const EdgeInsets.all(13),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkThumb(
                imageUrl: line.product.imageUrl,
                icon: Icons.restaurant_rounded,
                size: 68,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${formatMoney(line.product.priceCents)} / unidade',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remover item',
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.danger.withValues(alpha: 0.08),
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? AppColors.darkElevated
                    : AppColors.bg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: _brandOrange,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 12,
                      ),
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
            runSpacing: 6,
            children: [
              TextButton.icon(
                onPressed: onEditNote,
                icon: const Icon(Icons.edit_note_rounded, size: 17),
                label: Text(note == null ? 'Adicionar nota' : 'Editar nota'),
                style: TextButton.styleFrom(
                  foregroundColor: _brandOrange,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
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
                  style: const TextStyle(
                    color: _brandBlack,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
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
      padding: const EdgeInsets.all(17),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: _brandOrange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Cupão de desconto',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (appliedCode != null)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '$appliedCode · −${formatMoney(discountCents)}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.greenInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRemove,
                  child: const Text(
                    'Remover',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Introduz o código',
                      isDense: true,
                      filled: true,
                      fillColor: context.isDarkMode
                          ? AppColors.darkElevated
                          : AppColors.bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.lineColor,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 104,
                  child: FilledButton(
                    onPressed: loading ? null : onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandBlack,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Aplicar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
