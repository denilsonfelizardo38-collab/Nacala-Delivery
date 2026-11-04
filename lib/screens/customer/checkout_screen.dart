import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/address_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/location_picker.dart';
import 'tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _coupon = TextEditingController();
  bool _initialized = false;
  String? _selectedAddressId;
  String _payment = 'cash';
  bool _submitting = false;
  bool _couponLoading = false;
  String? _error;
  String? _couponError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final state = AppScope.of(context);
    _phone.text = state.user?.phone ?? '';
    _selectedAddressId = state.defaultAddress?.id;
    _coupon.text = state.couponCode ?? '';
  }

  @override
  void dispose() {
    _phone.dispose();
    _note.dispose();
    _coupon.dispose();
    super.dispose();
  }

  Address? _address(AppState state) {
    for (final address in state.addresses) {
      if (address.id == _selectedAddressId) return address;
    }
    return state.defaultAddress;
  }

  void _leaveGuestMode() {
    AppScope.of(context).exitGuestMode();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _addAddress() async {
    final input = await showAddressDialog(context);
    if (input == null || !mounted) return;
    final state = AppScope.of(context);
    try {
      final address = await state.addAddress(
        label: input.label,
        line: input.line,
        reference: input.reference,
        isDefault: input.isDefault,
        latitude: input.latitude,
        longitude: input.longitude,
      );
      if (!mounted) return;
      setState(() => _selectedAddressId = address.id);
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _markDeliveryPoint(Address address) async {
    final latitude = address.latitude;
    final longitude = address.longitude;
    final point = await showLocationPicker(
      context,
      initialLocation: latitude == null || longitude == null
          ? null
          : LatLng(latitude, longitude),
    );
    if (point == null || !mounted) return;
    try {
      await AppScope.of(context).updateAddress(
        address.id,
        label: address.label,
        line: address.line,
        reference: address.reference,
        isDefault: address.isDefault,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (mounted) {
        setState(() => _error = null);
        showAppSnack(context, 'Ponto de entrega guardado.');
      }
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
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

  Future<void> _submit() async {
    final state = AppScope.of(context);
    final address = _address(state);
    final phone = digitsOnly(_phone.text);
    if (address == null) {
      setState(() => _error = 'Adicione uma morada de entrega para continuar.');
      return;
    }
    if (!address.hasLocation) {
      setState(
        () => _error = 'Marque o ponto de entrega no mapa para continuar.',
      );
      return;
    }
    if (!RegExp(r'^8[2-7][0-9]{7}$').hasMatch(phone)) {
      setState(
        () => _error = 'Indique um número de telemóvel moçambicano válido.',
      );
      return;
    }
    final paymentLabel = switch (_payment) {
      'mpesa' => 'M-Pesa',
      'emola' => 'e-Mola',
      _ => 'Dinheiro na entrega',
    };
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirmar pedido',
      message:
          '${state.cartItemCount} item(ns) · '
          '${formatMoney(state.cartTotalCents)} · $paymentLabel.\n\n'
          'Ao confirmar, o pedido é enviado ao estabelecimento.',
      confirmLabel: 'Confirmar pedido',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final order = await state.placeOrder(
        address: address,
        phone: phone,
        paymentMethod: _payment,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => TrackingScreen(orderId: order.id)),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.isGuest) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finalizar pedido')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Entra para fazer o pedido',
              message:
                  'O carrinho fica guardado. Entra ou cria uma conta para '
                  'adicionar morada e confirmar a entrega.',
              actionLabel: 'Entrar ou criar conta',
              onAction: _leaveGuestMode,
            ),
          ),
        ),
      );
    }
    if (state.isCartEmpty && !_submitting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finalizar pedido')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Carrinho vazio',
              message: 'Adicione produtos antes de finalizar o pedido.',
              actionLabel: 'Voltar',
              onAction: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finalizar pedido'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  NetworkThumb(
                    imageUrl: state.cartStore?.imageUrl,
                    icon: Icons.delivery_dining_outlined,
                    size: 48,
                    radius: 13,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.cartStore?.name ?? 'O seu pedido',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${state.cartItemCount} '
                          '${state.cartItemCount == 1 ? 'unidade' : 'unidades'}'
                          ' · entrega em Nacala-Porto',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatMoney(state.cartTotalCents),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const SectionTitle(
              title: 'Entrega',
              subtitle: 'Onde devemos entregar o seu pedido?',
            ),
            const SizedBox(height: 10),
            if (state.addresses.isEmpty)
              AppCard(
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      color: context.mutedColor,
                      size: 26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ainda não tem moradas guardadas.',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Adicionar morada'),
                    ),
                  ],
                ),
              )
            else ...[
              for (final address in state.addresses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AddressOption(
                    address: address,
                    selected: address.id == _selectedAddressId,
                    onTap: () =>
                        setState(() => _selectedAddressId = address.id),
                  ),
                ),
              if (_address(state) case final selected?
                  when !selected.hasLocation) ...[
                OutlinedButton.icon(
                  onPressed: () => _markDeliveryPoint(selected),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Marcar ponto de entrega no mapa'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryPressed,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextButton.icon(
                onPressed: _addAddress,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Adicionar outra morada'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
            const SizedBox(height: 20),
            const SectionTitle(
              title: 'Contacto',
              subtitle: 'O estafeta liga para este número',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telemóvel',
                hintText: '84 123 4567',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle(title: 'Cupão de desconto'),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _coupon,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Digite o cupão',
                            isDense: true,
                            prefixIcon: const Icon(
                              Icons.local_offer_outlined,
                              color: AppColors.primary,
                            ),
                            suffixIcon: state.couponCode == null
                                ? null
                                : IconButton(
                                    tooltip: 'Remover cupão',
                                    onPressed: () {
                                      state.removeCoupon();
                                      _coupon.clear();
                                      setState(() => _couponError = null);
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                          ),
                          onSubmitted: (_) => _applyCoupon(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 92,
                        child: FilledButton(
                          onPressed: _couponLoading ? null : _applyCoupon,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: _couponLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  state.couponCode == null
                                      ? 'Aplicar'
                                      : 'Atualizar',
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (state.couponCode != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${state.couponCode} aplicado · '
                      '${formatMoney(state.couponDiscountCents)} de desconto',
                      style: TextStyle(
                        color: context.successColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_couponError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _couponError!,
                      style: TextStyle(
                        color: context.dangerColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle(
              title: 'Pagamento',
              subtitle: 'Escolha como pretende pagar',
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              value: 'mpesa',
              selected: _payment == 'mpesa',
              icon: Icons.phone_android_rounded,
              title: 'M-Pesa',
              subtitle: 'Pagamento móvel · integração pendente',
              onTap: () => setState(() => _payment = 'mpesa'),
            ),
            const SizedBox(height: 8),
            _PaymentOption(
              value: 'emola',
              selected: _payment == 'emola',
              icon: Icons.account_balance_wallet_outlined,
              title: 'e-Mola',
              subtitle: 'Pagamento móvel · integração pendente',
              onTap: () => setState(() => _payment = 'emola'),
            ),
            const SizedBox(height: 8),
            _PaymentOption(
              value: 'cash',
              selected: _payment == 'cash',
              icon: Icons.payments_outlined,
              title: 'Dinheiro na entrega',
              subtitle: 'Pague ao estafeta quando receber',
              onTap: () => setState(() => _payment = 'cash'),
            ),
            if (_payment != 'cash') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primaryPressed,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A cobrança automática M-Pesa/e-Mola ainda não está '
                        'ativa. O pedido será registado com pagamento pendente '
                        'de integração; não será cobrado automaticamente.',
                        style: TextStyle(
                          color: AppColors.primaryPressed,
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            const SectionTitle(title: 'Nota para o parceiro'),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ex.: tocar à campainha, sem cebola...',
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle(title: 'Resumo do pedido'),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  for (final line in state.cart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${line.quantity}',
                              style: const TextStyle(
                                color: AppColors.primaryPressed,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              line.product.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatMoney(line.totalCents),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 20),
                  PriceLine(label: 'Subtotal', cents: state.cartSubtotalCents),
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
                  const Divider(height: 20),
                  PriceLine(
                    label: 'Total',
                    cents: state.cartTotalCents,
                    strong: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 15,
                        color: context.mutedColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Preços e totais são confirmados pelo servidor no '
                          'momento da criação do pedido.',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.dangerColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.dangerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: context.dangerColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: context.dangerColor,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        color: context.cardColor,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.08),
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
                        'Total a confirmar',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        formatMoney(state.cartTotalCents),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.45,
                      ),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Confirmar pedido',
                            style: TextStyle(fontWeight: FontWeight.w700),
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

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final Address address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.primary : null,
      color: selected ? AppColors.primarySoft : null,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            size: 20,
            color: selected ? AppColors.primary : context.mutedColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        address.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Predefinida',
                          style: TextStyle(
                            color: AppColors.primaryPressed,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address.fullLine,
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.value,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: selected ? AppColors.primary : null,
      color: selected ? AppColors.primarySoft : null,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color: selected ? Colors.white : AppColors.primaryPressed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            size: 20,
            color: selected ? AppColors.primary : context.mutedColor,
          ),
        ],
      ),
    );
  }
}
