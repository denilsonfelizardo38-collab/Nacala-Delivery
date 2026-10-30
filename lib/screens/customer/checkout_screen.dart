import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/section_heading.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final TextEditingController _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  PaymentMethod _payment = PaymentMethod.mpesa;
  bool _submitting = false;
  bool _addressLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_addressLoaded) {
      _addressController.text = AppScope.of(context).address;
      _addressLoaded = true;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final state = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final address = _addressController.text.trim();
    if (address.length < 5) {
      _warn('Indique uma morada de entrega válida.');
      return;
    }
    final phone = digitsOnly(_phoneController.text);
    if (_payment.requiresPhone && phone.length < 9) {
      _warn('Indique um número de telemóvel com 9 dígitos.');
      return;
    }

    setState(() => _submitting = true);
    final order = await state.placeOrder(
      address: address,
      payment: _payment,
      phone: _payment.requiresPhone ? phone : null,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (!mounted) return;

    state.selectTab(1);
    navigator.popUntil((route) => route.isFirst);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Pedido ${order.id} confirmado!')));
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar pedido')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const SectionHeading(title: 'Morada de entrega'),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Bairro, rua, casa e ponto de referência',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeading(title: 'Pagamento'),
          const SizedBox(height: 10),
          for (final method in PaymentMethod.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _PaymentTile(
                method: method,
                selected: _payment == method,
                onTap: () => setState(() => _payment = method),
              ),
            ),
          if (_payment.requiresPhone) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Número ${_payment.label}',
                prefixIcon: const Icon(Icons.phone_iphone_rounded),
                prefixText: '+258 ',
              ),
            ),
          ],
          const SizedBox(height: 22),
          const SectionHeading(title: 'Notas para o parceiro'),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Ex.: entregar na portaria, sem cebola…',
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _Line(
                  label:
                      '${state.cartItemCount} itens · ${state.cartPlace?.name ?? ''}',
                  value: formatMoney(state.subtotal),
                ),
                const SizedBox(height: 8),
                _Line(
                  label: 'Taxa de entrega',
                  value: formatMoney(state.deliveryFee),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: context.lineColor, height: 1),
                ),
                _Line(
                  label: 'Total a pagar',
                  value: formatMoney(state.total),
                  emphasized: true,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        color: context.cardColor,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: FilledButton(
              onPressed: _submitting ? null : _confirm,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Confirmar pedido · ${formatMoney(state.total)}'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Material(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? accent : context.lineColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(method.icon, size: 20, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: TextStyle(
                        color: context.inkColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.hint,
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? accent : context.mutedColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
