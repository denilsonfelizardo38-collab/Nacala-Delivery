import 'package:flutter/material.dart';

import 'cart_line.dart';
import 'place.dart';

enum OrderStatus {
  received('Pedido recebido', 'O parceiro vai confirmar o seu pedido.'),
  preparing('A preparar', 'O seu pedido está a ser preparado.'),
  onTheWay('Em entrega', 'O estafeta está a caminho.'),
  delivered('Entregue', 'Bom apetite! O pedido foi entregue.');

  const OrderStatus(this.label, this.description);

  final String label;
  final String description;

  int get step => index;
}

enum PaymentMethod {
  mpesa('M-Pesa', 'Pagamento por telemóvel'),
  emola('e-Mola', 'Pagamento por telemóvel'),
  cash('Dinheiro na entrega', 'Pague ao estafeta');

  const PaymentMethod(this.label, this.hint);

  final String label;
  final String hint;

  bool get requiresPhone =>
      this == PaymentMethod.mpesa || this == PaymentMethod.emola;

  IconData get icon => switch (this) {
    PaymentMethod.mpesa || PaymentMethod.emola => Icons.phone_android_rounded,
    PaymentMethod.cash => Icons.payments_rounded,
  };
}

/// Um pedido confirmado pelo cliente.
class Order {
  const Order({
    required this.id,
    required this.place,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.address,
    required this.payment,
    required this.createdAt,
    this.status = OrderStatus.received,
    this.phone,
    this.note,
  });

  final String id;
  final Place place;
  final List<CartLine> lines;
  final int subtotal;
  final int deliveryFee;
  final String address;
  final PaymentMethod payment;
  final DateTime createdAt;
  final OrderStatus status;
  final String? phone;
  final String? note;

  int get total => subtotal + deliveryFee;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  Order copyWith({OrderStatus? status}) => Order(
    id: id,
    place: place,
    lines: lines,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    address: address,
    payment: payment,
    createdAt: createdAt,
    status: status ?? this.status,
    phone: phone,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'placeId': place.id,
    'items': [
      for (final line in lines)
        {'productId': line.product.id, 'quantity': line.quantity},
    ],
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'address': address,
    'payment': payment.name,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'phone': phone,
    'note': note,
  };

  /// Reconstrói o pedido a partir do JSON guardado localmente.
  /// Devolve `null` se o local ou algum produto já não existir no catálogo.
  static Order? fromJson(
    Map<String, dynamic> json, {
    required Map<String, Place> places,
    required Map<String, Product> products,
  }) {
    final place = places[json['placeId']];
    if (place == null) return null;

    final lines = <CartLine>[];
    for (final raw in (json['items'] as List? ?? const [])) {
      final item = raw as Map<String, dynamic>;
      final product = products[item['productId']];
      if (product == null) continue;
      lines.add(
        CartLine(product: product, quantity: (item['quantity'] as num).toInt()),
      );
    }
    if (lines.isEmpty) return null;

    return Order(
      id: json['id'] as String,
      place: place,
      lines: lines,
      subtotal: (json['subtotal'] as num).toInt(),
      deliveryFee: (json['deliveryFee'] as num).toInt(),
      address: json['address'] as String? ?? '',
      payment: PaymentMethod.values.firstWhere(
        (method) => method.name == json['payment'],
        orElse: () => PaymentMethod.cash,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: OrderStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => OrderStatus.received,
      ),
      phone: json['phone'] as String?,
      note: json['note'] as String?,
    );
  }
}
