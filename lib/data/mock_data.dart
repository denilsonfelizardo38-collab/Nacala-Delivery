import 'package:flutter/material.dart';

import '../models/partner.dart';
import '../models/place.dart';

/// Catálogo demonstrativo. Substituir por dados da API quando o backend
/// estiver disponível (ver `DeliveryRepository`).
const mockPlaces = <Place>[
  Place(
    id: 'cantinho-da-baia',
    name: 'Cantinho da Baía',
    category: 'Restaurante',
    description: 'Frango grelhado · Mariscos',
    rating: 4.8,
    deliveryTime: '25–35 min',
    deliveryFee: 80,
    icon: Icons.dinner_dining_rounded,
    tint: Color(0xFFFFEEE2),
    address: 'Av. Marginal, Nacala-Porto',
  ),
  Place(
    id: 'mercado-central',
    name: 'Mercado Central',
    category: 'Mercado',
    description: 'Frescos · Mercearia · Bebidas',
    rating: 4.7,
    deliveryTime: '20–30 min',
    deliveryFee: 60,
    icon: Icons.shopping_basket_rounded,
    tint: Color(0xFFE7F5EC),
    address: 'Bairro Central, Nacala-Porto',
  ),
  Place(
    id: 'farmacia-nacala',
    name: 'Farmácia Nacala',
    category: 'Farmácia',
    description: 'Cuidados de saúde e bem-estar',
    rating: 4.9,
    deliveryTime: '20–30 min',
    deliveryFee: 70,
    icon: Icons.local_pharmacy_rounded,
    tint: Color(0xFFEAF3FF),
    address: 'Rua da Saúde, Nacala-Porto',
  ),
  Place(
    id: 'loja-do-bairro',
    name: 'Loja do Bairro',
    category: 'Loja',
    description: 'Casa · Acessórios · Utilidades',
    rating: 4.6,
    deliveryTime: '30–45 min',
    deliveryFee: 90,
    icon: Icons.storefront_rounded,
    tint: Color(0xFFFFF3D9),
    address: 'Bairro Triângulo, Nacala-Porto',
  ),
];

const mockProducts = <Product>[
  // Cantinho da Baía
  Product(
    id: 'cb-frango',
    placeId: 'cantinho-da-baia',
    name: 'Frango grelhado',
    description: 'Com batata e salada',
    price: 450,
  ),
  Product(
    id: 'cb-caril',
    placeId: 'cantinho-da-baia',
    name: 'Caril de camarão',
    description: 'Com arroz de coco',
    price: 620,
  ),
  Product(
    id: 'cb-matapa',
    placeId: 'cantinho-da-baia',
    name: 'Matapa com arroz',
    description: 'Receita tradicional',
    price: 380,
  ),
  Product(
    id: 'cb-familia',
    placeId: 'cantinho-da-baia',
    name: 'Menu família',
    description: 'Frango, matapa, arroz e salada',
    price: 1200,
  ),
  Product(
    id: 'cb-sumo',
    placeId: 'cantinho-da-baia',
    name: 'Sumo de manga',
    description: 'Natural, 500 ml',
    price: 120,
  ),
  // Mercado Central
  Product(
    id: 'mc-fruta',
    placeId: 'mercado-central',
    name: 'Cesta de fruta',
    description: 'Banana, manga e papaia',
    price: 350,
  ),
  Product(
    id: 'mc-legumes',
    placeId: 'mercado-central',
    name: 'Legumes frescos',
    description: 'Tomate, cebola e couve',
    price: 180,
  ),
  Product(
    id: 'mc-arroz',
    placeId: 'mercado-central',
    name: 'Arroz 5 kg',
    description: 'Grão longo',
    price: 420,
  ),
  Product(
    id: 'mc-oleo',
    placeId: 'mercado-central',
    name: 'Óleo alimentar 2 L',
    description: 'Para cozinhar',
    price: 260,
  ),
  // Farmácia Nacala
  Product(
    id: 'fn-paracetamol',
    placeId: 'farmacia-nacala',
    name: 'Paracetamol',
    description: 'Caixa de 20 comprimidos',
    price: 120,
  ),
  Product(
    id: 'fn-soro',
    placeId: 'farmacia-nacala',
    name: 'Soro de reidratação',
    description: '3 saquetas',
    price: 90,
  ),
  Product(
    id: 'fn-mascaras',
    placeId: 'farmacia-nacala',
    name: 'Máscaras faciais',
    description: 'Pacote de 10',
    price: 150,
  ),
  Product(
    id: 'fn-protector',
    placeId: 'farmacia-nacala',
    name: 'Protetor solar',
    description: 'FPS 30, 100 ml',
    price: 480,
  ),
  // Loja do Bairro
  Product(
    id: 'lb-pilhas',
    placeId: 'loja-do-bairro',
    name: 'Pilhas AA',
    description: 'Pacote de 4',
    price: 180,
  ),
  Product(
    id: 'lb-lampada',
    placeId: 'loja-do-bairro',
    name: 'Lâmpada LED',
    description: '9 W, luz branca',
    price: 220,
  ),
  Product(
    id: 'lb-cabo',
    placeId: 'loja-do-bairro',
    name: 'Cabo USB-C',
    description: '1,5 m, carregamento rápido',
    price: 350,
  ),
  Product(
    id: 'lb-caderno',
    placeId: 'loja-do-bairro',
    name: 'Caderno A5',
    description: '80 folhas pautadas',
    price: 120,
  ),
];

const mockPartners = <Partner>[
  Partner(
    initials: 'CB',
    name: 'Cantinho da Baía',
    type: 'Restaurante · Nacala-Porto',
    tint: Color(0xFFFFEEE2),
  ),
  Partner(
    initials: 'MC',
    name: 'Mercado Central',
    type: 'Mercearia · Nacala-Porto',
    tint: Color(0xFFE7F5EC),
  ),
  Partner(
    initials: 'FN',
    name: 'Farmácia Nacala',
    type: 'Farmácia · Nacala-Porto',
    tint: Color(0xFFEAF3FF),
    pending: true,
  ),
];

final Map<String, Place> placesById = {
  for (final place in mockPlaces) place.id: place,
};

final Map<String, Product> productsById = {
  for (final product in mockProducts) product.id: product,
};

List<Product> productsFor(String placeId) =>
    mockProducts.where((product) => product.placeId == placeId).toList();

/// Filtro de categorias mostrado na página inicial.
class CategoryFilter {
  const CategoryFilter(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

const categoryFilters = <CategoryFilter>[
  CategoryFilter('Todos', 'Todos', Icons.grid_view_rounded),
  CategoryFilter('Restaurantes', 'Restaurante', Icons.restaurant_rounded),
  CategoryFilter('Mercados', 'Mercado', Icons.shopping_basket_rounded),
  CategoryFilter('Farmácias', 'Farmácia', Icons.local_pharmacy_rounded),
  CategoryFilter('Lojas', 'Loja', Icons.storefront_rounded),
];
