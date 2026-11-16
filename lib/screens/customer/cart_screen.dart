import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

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
    // Sem sessão (convidado ou recém-sair): escolher tipo de conta para
    // entrar — o carrinho fica guardado localmente até à login.
    if (!state.isSignedIn) {
      Navigator.of(context).pushNamed('/roles', arguments: 'login');
      return;
    }
    Navigator.of(context).pushNamed('/checkout');
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final empty = state.isCartEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // `page-head` do referencial: voltar, "Carrinho" em display
            // e o nome da loja em mutado por baixo.
            JbPageHeader(
              title: 'Carrinho',
              subtitle: empty ? null : state.cartStore?.name,
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              trailing: empty
                  ? null
                  : Material(
                      color: AppColors.darkCard,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Esvaziar carrinho',
                        onPressed: _clearCart,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: context.inkColor,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: empty
                ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  // `.empty` do referencial: marca circular vermelha,
                  // título display e acção principal.
                  child: EmptyState(
                    icon: Icons.shopping_bag_outlined,
                    title: 'O carrinho está vazio',
                    message:
                        'Explore os parceiros de Nacala-Porto e adicione '
                        'os produtos que precisa.',
                    actionLabel: 'Ver estabelecimentos',
                    onAction: () => Navigator.of(context).pop(),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
                children: [
                  _StoreCard(
                    name: state.cartStore?.name ?? '',
                    imageUrl: state.cartStore?.imageUrl,
                    itemCount: state.cartItemCount,
                    onTap: () {
                      final id = state.cartStore?.id;
                      if (id == null) return;
                      Navigator.of(context).pushNamed('/store', arguments: id);
                    },
                  ),
                  JbSectionHeader(
                    title: 'Os teus artigos',
                    count: state.cartItemCount,
                    margin: const EdgeInsets.only(top: 16, bottom: 6),
                  ),
                  // `.cart-items` do referencial: um único cartão com as
                  // linhas `.citem` (imagem, nome/preço, stepper).
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(13, 2, 13, 2),
                    radius: 18,
                    child: Column(
                      children: [
                        for (final (index, line) in state.cart.indexed)
                          _CartLineCard(
                            line: line,
                            divider: index < state.cart.length - 1,
                            onIncrement: () => state.increment(line.product.id),
                            onDecrement: () => state.decrement(line.product.id),
                            onRemove: () => state.removeLine(line.product.id),
                            onEditNote: () =>
                                _editNote(line.product.id, line.note),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
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
                  const SizedBox(height: 20),
                  // `.totals` do referencial: bloco simples com linha de
                  // topo, linhas label/valor e total em display.
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.darkElevated),
                      ),
                    ),
                    child: Column(
                      children: [
                        PriceLine(
                          label: 'Subtotal',
                          cents: state.cartSubtotalCents,
                        ),
                        const SizedBox(height: 8),
                        PriceLine(
                          label: 'Taxa de entrega',
                          cents: state.cartDeliveryFeeCents,
                        ),
                        if (state.couponDiscountCents > 0) ...[
                          const SizedBox(height: 8),
                          PriceLine(
                            label: 'Desconto (${state.couponCode})',
                            cents: -state.couponDiscountCents,
                            color: context.successColor,
                          ),
                        ],
                        const SizedBox(height: 12),
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
                            borderRadius: BorderRadius.circular(10),
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
          ],
        ),
      ),
      bottomNavigationBar: empty
          ? null
          : Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  // `.btn.primary.block.big`: acção e total no mesmo
                  // botão vermelho de largura total.
                  child: FilledButton(
                    onPressed: _continue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.isGuest
                                ? 'Entrar para pedir'
                                : 'Finalizar pedido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          formatMoney(state.cartTotalCents),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
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
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '$itemCount ${itemCount == 1 ? 'unidade' : 'unidades'}',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
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
    this.divider = false,
  });

  final CartLine line;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onEditNote;

  /// Desenha a linha divisória de 1 px por baixo (`.citem` separadas).
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final note = line.note;
    // `.citem` do referencial: imagem de 56 px, nome + preço e stepper.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      decoration: BoxDecoration(
        border: divider
            ? const Border(
                bottom: BorderSide(color: AppColors.darkElevated),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NetworkThumb(
                imageUrl: line.product.imageUrl,
                icon: Icons.restaurant_rounded,
                size: 56,
                radius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
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
              const SizedBox(width: 8),
              QuantityStepper(
                quantity: line.quantity,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.darkElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      note,
                      style: TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              TextButton.icon(
                onPressed: onEditNote,
                icon: const Icon(Icons.edit_note_rounded, size: 17),
                label: Text(note == null ? 'Adicionar nota' : 'Editar nota'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remover item',
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
              const SizedBox(width: 2),
              Text(
                formatMoney(line.totalCents),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Cupão de desconto',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
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
                      borderRadius: BorderRadius.circular(10),
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
                              fontWeight: FontWeight.w700,
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
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: context.lineColor),
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
                      backgroundColor: context.isDarkMode
                          ? AppColors.darkElevated
                          : AppColors.ink,
                      foregroundColor: context.isDarkMode
                          ? AppColors.darkInk
                          : Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: loading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.isDarkMode
                                  ? AppColors.darkInk
                                  : Colors.white,
                            ),
                          )
                        : const Text(
                            'Aplicar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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
