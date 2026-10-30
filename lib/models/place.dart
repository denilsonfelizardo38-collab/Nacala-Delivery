import 'package:flutter/material.dart';

/// Um restaurante, mercado, farmácia ou loja disponível na plataforma.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.icon,
    required this.tint,
    this.address = 'Nacala-Porto',
    this.isOpen = true,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double rating;
  final String deliveryTime;

  /// Taxa de entrega em meticais.
  final int deliveryFee;
  final IconData icon;
  final Color tint;
  final String address;
  final bool isOpen;
}

/// Um artigo do menu/ catálogo de um [Place].
class Product {
  const Product({
    required this.id,
    required this.placeId,
    required this.name,
    required this.description,
    required this.price,
  });

  final String id;
  final String placeId;
  final String name;
  final String description;

  /// Preço unitário em meticais.
  final int price;
}
