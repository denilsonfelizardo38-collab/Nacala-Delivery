/// Modelos da API Nacala. Todos os valores monetários são inteiros em
/// centavos de metical (MZN).
library;

int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

String _str(dynamic value) => value is String ? value : '';

DateTime _date(dynamic value) =>
    DateTime.tryParse(_str(value)) ?? DateTime.fromMillisecondsSinceEpoch(0);

double? _doubleOrNull(dynamic value) => value is num ? value.toDouble() : null;

DateTime? _dateOrNull(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

class UserAccount {
  const UserAccount({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
  });

  final String id;
  final String role;
  final String name;
  final String email;
  final String phone;

  bool get isCustomer => role == 'customer';
  bool get isPartner => role == 'partner';
  bool get isDelivery => role == 'delivery';
  bool get isAdmin => role == 'admin';

  String get roleLabel => switch (role) {
    'customer' => 'Cliente',
    'partner' => 'Parceiro',
    'delivery' => 'Estafeta',
    'admin' => 'Administrador',
    _ => role,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    id: _str(json['id']),
    role: _str(json['role']),
    name: _str(json['name']),
    email: _str(json['email']),
    phone: _str(json['phone']),
  );
}

class AuthResult {
  const AuthResult({required this.token, required this.user});
  final String token;
  final UserAccount user;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    token: _str(json['token']),
    user: UserAccount.fromJson(
      (json['user'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    required this.icon,
    this.establishmentCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String icon;
  final int establishmentCount;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: _str(json['id']),
    name: _str(json['name']),
    slug: _str(json['slug']),
    icon: _str(json['icon']),
    establishmentCount: _int(json['establishment_count']),
  );
}

class Establishment {
  const Establishment({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.address,
    required this.phone,
    required this.deliveryFeeCents,
    required this.prepMinutes,
    required this.opensAt,
    required this.closesAt,
    required this.isOpen,
    required this.rating,
    required this.reviewCount,
    required this.productCount,
    required this.categoryId,
    required this.categoryName,
    required this.categorySlug,
    this.imageUrl,
    this.isApproved = true,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String address;
  final String phone;
  final int deliveryFeeCents;
  final int prepMinutes;
  final String opensAt;
  final String closesAt;
  final bool isOpen;
  final double rating;
  final int reviewCount;
  final int productCount;
  final String categoryId;
  final String categoryName;
  final String categorySlug;
  final String? imageUrl;
  final bool isApproved;

  factory Establishment.fromJson(Map<String, dynamic> json) => Establishment(
    id: _str(json['id']),
    name: _str(json['name']),
    slug: _str(json['slug']),
    description: _str(json['description']),
    address: _str(json['address']),
    phone: _str(json['phone']),
    deliveryFeeCents: _int(json['delivery_fee_cents']),
    prepMinutes: _int(json['prep_minutes']),
    opensAt: _str(json['opens_at']),
    closesAt: _str(json['closes_at']),
    isOpen: json['is_open'] == true,
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    reviewCount: _int(json['review_count']),
    productCount: _int(json['product_count']),
    categoryId: _str(json['category_id']),
    categoryName: _str(json['category_name']),
    categorySlug: _str(json['category_slug']),
    imageUrl: json['image_url'] as String?,
    isApproved: json['is_approved'] != false,
  );
}

class Product {
  const Product({
    required this.id,
    required this.establishmentId,
    required this.name,
    required this.description,
    required this.priceCents,
    required this.category,
    required this.isAvailable,
    this.stock,
    this.imageUrl,
    this.establishmentName,
  });

  final String id;
  final String establishmentId;
  final String name;
  final String description;
  final int priceCents;
  final String category;
  final bool isAvailable;
  final int? stock;
  final String? imageUrl;
  final String? establishmentName;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: _str(json['id']),
    establishmentId: _str(json['establishment_id']),
    name: _str(json['name']),
    description: _str(json['description']),
    priceCents: _int(json['price_cents']),
    category: _str(json['category']),
    isAvailable: json['is_available'] == true,
    stock: json['stock'] == null ? null : _int(json['stock']),
    imageUrl: json['image_url'] as String?,
    establishmentName: json['establishment_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'establishment_id': establishmentId,
    'name': name,
    'description': description,
    'price_cents': priceCents,
    'category': category,
    'is_available': isAvailable,
    'stock': stock,
    'image_url': imageUrl,
    'establishment_name': establishmentName,
  };
}

class EstablishmentDetail {
  const EstablishmentDetail({
    required this.establishment,
    required this.products,
    required this.reviews,
  });

  final Establishment establishment;
  final List<Product> products;
  final List<Review> reviews;
}

class Review {
  const Review({
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.customerName,
  });

  final int rating;
  final String comment;
  final DateTime createdAt;
  final String customerName;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    rating: _int(json['rating']),
    comment: _str(json['comment']),
    createdAt: _date(json['created_at']),
    customerName: _str(json['customer_name']),
  );
}

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.line,
    required this.city,
    this.reference,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String line;
  final String city;
  final String? reference;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  String get fullLine =>
      reference == null || reference!.isEmpty ? line : '$line · $reference';
  bool get hasLocation => latitude != null && longitude != null;

  factory Address.fromJson(Map<String, dynamic> json) => Address(
    id: _str(json['id']),
    label: _str(json['label']),
    line: _str(json['line']),
    city: _str(json['city']),
    reference: json['reference'] as String?,
    isDefault: json['is_default'] == true,
    latitude: _doubleOrNull(json['latitude']),
    longitude: _doubleOrNull(json['longitude']),
  );
}

/// Identificação mínima do estabelecimento a que o carrinho pertence.
class CartStore {
  const CartStore({
    required this.id,
    required this.name,
    required this.deliveryFeeCents,
  });

  final String id;
  final String name;
  final int deliveryFeeCents;

  factory CartStore.fromEstablishment(Establishment establishment) => CartStore(
    id: establishment.id,
    name: establishment.name,
    deliveryFeeCents: establishment.deliveryFeeCents,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'delivery_fee_cents': deliveryFeeCents,
  };

  factory CartStore.fromJson(Map<String, dynamic> json) => CartStore(
    id: _str(json['id']),
    name: _str(json['name']),
    deliveryFeeCents: _int(json['delivery_fee_cents']),
  );
}

class CartLine {
  CartLine({required this.product, this.quantity = 1, this.note});

  final Product product;
  int quantity;
  String? note;

  int get totalCents => product.priceCents * quantity;

  Map<String, dynamic> toJson() => {
    'product': product.toJson(),
    'quantity': quantity,
    'note': note,
  };

  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
    product: Product.fromJson(
      (json['product'] as Map<String, dynamic>?) ?? const {},
    ),
    quantity: _int(json['quantity']),
    note: json['note'] as String?,
  );
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPriceCents,
    required this.quantity,
    required this.lineTotalCents,
    this.note,
  });

  final String productId;
  final String name;
  final int unitPriceCents;
  final int quantity;
  final int lineTotalCents;
  final String? note;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: _str(json['product_id']),
    name: _str(json['name']),
    unitPriceCents: _int(json['unit_price_cents']),
    quantity: _int(json['quantity']),
    lineTotalCents: _int(json['line_total_cents']),
    note: json['note'] as String?,
  );
}

class OrderEvent {
  const OrderEvent({required this.status, required this.createdAt, this.note});

  final String status;
  final DateTime createdAt;
  final String? note;

  factory OrderEvent.fromJson(Map<String, dynamic> json) => OrderEvent(
    status: _str(json['status']),
    createdAt: _date(json['created_at']),
    note: json['note'] as String?,
  );
}

class DeliveryInfo {
  const DeliveryInfo({
    required this.status,
    this.courierName,
    this.courierPhone,
    this.latitude,
    this.longitude,
    this.departedAt,
    this.locationUpdatedAt,
  });

  final String status;
  final String? courierName;
  final String? courierPhone;
  final double? latitude;
  final double? longitude;
  final DateTime? departedAt;
  final DateTime? locationUpdatedAt;

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) => DeliveryInfo(
    status: _str(json['status']),
    courierName: json['courier_name'] as String?,
    courierPhone: json['courier_phone'] as String?,
    latitude: _doubleOrNull(json['latitude']),
    longitude: _doubleOrNull(json['longitude']),
    departedAt: _dateOrNull(json['departed_at']),
    locationUpdatedAt: _dateOrNull(json['location_updated_at']),
  );
}

class MiniEstablishment {
  const MiniEstablishment({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
  });

  final String id;
  final String name;
  final String address;
  final String phone;

  factory MiniEstablishment.fromJson(Map<String, dynamic> json) =>
      MiniEstablishment(
        id: _str(json['id']),
        name: _str(json['name']),
        address: _str(json['address']),
        phone: _str(json['phone']),
      );
}

class Order {
  const Order({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.subtotalCents,
    required this.deliveryFeeCents,
    required this.discountCents,
    required this.totalCents,
    required this.addressLabel,
    required this.addressLine,
    required this.phone,
    required this.createdAt,
    required this.establishment,
    required this.items,
    required this.events,
    this.couponCode,
    this.note,
    this.rejectionReason,
    this.cancellationReason,
    this.customerName,
    this.customerPhone,
    this.delivery,
    this.addressLatitude,
    this.addressLongitude,
  });

  final String id;
  final String number;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final int subtotalCents;
  final int deliveryFeeCents;
  final int discountCents;
  final int totalCents;
  final String addressLabel;
  final String addressLine;
  final String phone;
  final DateTime createdAt;
  final MiniEstablishment establishment;
  final List<OrderItem> items;
  final List<OrderEvent> events;
  final String? couponCode;
  final String? note;
  final String? rejectionReason;
  final String? cancellationReason;
  final String? customerName;
  final String? customerPhone;
  final DeliveryInfo? delivery;
  final double? addressLatitude;
  final double? addressLongitude;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isFinal =>
      const ['delivered', 'cancelled', 'rejected'].contains(status);
  bool get canCancel => const ['pending', 'confirmed'].contains(status);
  bool get canReview => status == 'delivered';

  String get statusLabel => switch (status) {
    'pending' => 'Pedido recebido',
    'confirmed' => 'Confirmado',
    'preparing' => 'A preparar',
    'ready' => 'Pronto para recolha',
    'on_the_way' => 'Em entrega',
    'delivered' => 'Entregue',
    'cancelled' => 'Cancelado',
    'rejected' => 'Rejeitado',
    _ => status,
  };

  String get statusDescription => switch (status) {
    'pending' => 'O parceiro vai confirmar o seu pedido.',
    'confirmed' => 'O parceiro aceitou o seu pedido.',
    'preparing' => 'O seu pedido está a ser preparado.',
    'ready' => 'O pedido está pronto para recolha pelo estafeta.',
    'on_the_way' => 'O estafeta está a caminho.',
    'delivered' => 'Pedido entregue. Bom apetite!',
    'cancelled' => 'O pedido foi cancelado.',
    'rejected' => 'O parceiro não pôde aceitar o pedido.',
    _ => '',
  };

  String get paymentLabel => switch (paymentMethod) {
    'mpesa' => 'M-Pesa',
    'emola' => 'e-Mola',
    'cash' => 'Dinheiro na entrega',
    _ => paymentMethod,
  };

  String get paymentStatusLabel => switch (paymentStatus) {
    'pending_integration' => 'Integração de pagamento pendente',
    'cash_on_delivery' => 'Pagar na entrega',
    _ => paymentStatus,
  };

  /// Índice do passo atual na linha temporal (0..5).
  int get step {
    const flow = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'on_the_way',
      'delivered',
    ];
    final index = flow.indexOf(status);
    return index < 0 ? 0 : index;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final establishment =
        (json['establishment'] as Map<String, dynamic>?) ?? const {};
    final customer = (json['customer'] as Map<String, dynamic>?) ?? const {};
    return Order(
      id: _str(json['id']),
      number: _str(json['number']),
      status: _str(json['status']),
      paymentMethod: _str(json['payment_method']),
      paymentStatus: _str(json['payment_status']),
      subtotalCents: _int(json['subtotal_cents']),
      deliveryFeeCents: _int(json['delivery_fee_cents']),
      discountCents: _int(json['discount_cents']),
      totalCents: _int(json['total_cents']),
      addressLabel: _str(json['address_label']),
      addressLine: _str(json['address_line']),
      addressLatitude: _doubleOrNull(json['address_latitude']),
      addressLongitude: _doubleOrNull(json['address_longitude']),
      phone: _str(json['phone']),
      createdAt: _date(json['created_at']),
      establishment: MiniEstablishment.fromJson(establishment),
      items: [
        for (final item in (json['items'] as List? ?? const []))
          OrderItem.fromJson(item as Map<String, dynamic>),
      ],
      events: [
        for (final event in (json['events'] as List? ?? const []))
          OrderEvent.fromJson(event as Map<String, dynamic>),
      ],
      couponCode: json['coupon_code'] as String?,
      note: json['note'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      customerName: customer['name'] as String?,
      customerPhone: customer['phone'] as String?,
      delivery: json['delivery'] == null
          ? null
          : DeliveryInfo.fromJson(json['delivery'] as Map<String, dynamic>),
    );
  }
}

class SearchResult {
  const SearchResult({
    required this.establishments,
    required this.products,
    required this.categories,
  });

  final List<Establishment> establishments;
  final List<Product> products;
  final List<Category> categories;

  bool get isEmpty =>
      establishments.isEmpty && products.isEmpty && categories.isEmpty;

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
    establishments: [
      for (final item in (json['establishments'] as List? ?? const []))
        Establishment.fromJson(item as Map<String, dynamic>),
    ],
    products: [
      for (final item in (json['products'] as List? ?? const []))
        Product.fromJson(item as Map<String, dynamic>),
    ],
    categories: [
      for (final item in (json['categories'] as List? ?? const []))
        Category.fromJson(item as Map<String, dynamic>),
    ],
  );
}

class PartnerSummary {
  const PartnerSummary({
    required this.ordersToday,
    required this.salesTodayCents,
    required this.pendingOrders,
    required this.activeOrders,
    required this.totalOrders,
    required this.salesTotalCents,
    required this.rating,
    required this.reviewCount,
  });

  final int ordersToday;
  final int salesTodayCents;
  final int pendingOrders;
  final int activeOrders;
  final int totalOrders;
  final int salesTotalCents;
  final double rating;
  final int reviewCount;

  factory PartnerSummary.fromJson(Map<String, dynamic> json) => PartnerSummary(
    ordersToday: _int(json['orders_today']),
    salesTodayCents: _int(json['sales_today_cents']),
    pendingOrders: _int(json['pending_orders']),
    activeOrders: _int(json['active_orders']),
    totalOrders: _int(json['total_orders']),
    salesTotalCents: _int(json['sales_total_cents']),
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    reviewCount: _int(json['review_count']),
  );
}

class PartnerDashboardData {
  const PartnerDashboardData({
    required this.establishment,
    required this.summary,
    required this.recentOrders,
  });

  final Establishment establishment;
  final PartnerSummary summary;
  final List<Order> recentOrders;
}

class DeliveryAssignment {
  const DeliveryAssignment({
    required this.id,
    required this.status,
    required this.orderId,
    required this.number,
    required this.orderStatus,
    required this.totalCents,
    required this.addressLine,
    required this.establishmentName,
    this.addressLabel,
    this.customerPhone,
    this.note,
    this.establishmentAddress,
    this.establishmentPhone,
    this.acceptedAt,
    this.completedAt,
    this.addressLatitude,
    this.addressLongitude,
    this.courierLatitude,
    this.courierLongitude,
    this.departedAt,
    this.locationUpdatedAt,
  });

  final String id;
  final String status;
  final String orderId;
  final String number;
  final String orderStatus;
  final int totalCents;
  final String addressLine;
  final String establishmentName;
  final String? addressLabel;
  final String? customerPhone;
  final String? note;
  final String? establishmentAddress;
  final String? establishmentPhone;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final double? addressLatitude;
  final double? addressLongitude;
  final double? courierLatitude;
  final double? courierLongitude;
  final DateTime? departedAt;
  final DateTime? locationUpdatedAt;

  bool get isAvailable => status == 'available';

  factory DeliveryAssignment.fromJson(Map<String, dynamic> json) =>
      DeliveryAssignment(
        id: _str(json['id']),
        status: _str(json['status']),
        orderId: _str(json['order_id']),
        number: _str(json['number']),
        orderStatus: _str(json['order_status']),
        totalCents: _int(json['total_cents']),
        addressLine: _str(json['address_line']),
        establishmentName: _str(json['establishment_name']),
        addressLabel: json['address_label'] as String?,
        customerPhone: json['customer_phone'] as String?,
        note: json['note'] as String?,
        establishmentAddress: json['establishment_address'] as String?,
        establishmentPhone: json['establishment_phone'] as String?,
        acceptedAt: json['accepted_at'] == null
            ? null
            : _date(json['accepted_at']),
        completedAt: json['completed_at'] == null
            ? null
            : _date(json['completed_at']),
        addressLatitude: _doubleOrNull(json['address_latitude']),
        addressLongitude: _doubleOrNull(json['address_longitude']),
        courierLatitude: _doubleOrNull(json['courier_latitude']),
        courierLongitude: _doubleOrNull(json['courier_longitude']),
        departedAt: _dateOrNull(json['departed_at']),
        locationUpdatedAt: _dateOrNull(json['location_updated_at']),
      );
}

class AdminSummary {
  const AdminSummary({
    required this.customers,
    required this.partners,
    required this.couriers,
    required this.activePartners,
    required this.pendingPartners,
    required this.totalOrders,
    required this.ordersInProgress,
    required this.salesTotalCents,
    required this.salesTodayCents,
    required this.ordersToday,
    required this.recentOrders,
    required this.pendingEstablishments,
  });

  final int customers;
  final int partners;
  final int couriers;
  final int activePartners;
  final int pendingPartners;
  final int totalOrders;
  final int ordersInProgress;
  final int salesTotalCents;
  final int salesTodayCents;
  final int ordersToday;
  final List<Order> recentOrders;
  final List<Establishment> pendingEstablishments;

  factory AdminSummary.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? const {};
    return AdminSummary(
      customers: _int(summary['customers']),
      partners: _int(summary['partners']),
      couriers: _int(summary['couriers']),
      activePartners: _int(summary['active_partners']),
      pendingPartners: _int(summary['pending_partners']),
      totalOrders: _int(summary['total_orders']),
      ordersInProgress: _int(summary['orders_in_progress']),
      salesTotalCents: _int(summary['sales_total_cents']),
      salesTodayCents: _int(summary['sales_today_cents']),
      ordersToday: _int(summary['orders_today']),
      recentOrders: [
        for (final item in (json['recent_orders'] as List? ?? const []))
          Order.fromJson(item as Map<String, dynamic>),
      ],
      pendingEstablishments: [
        for (final item in (json['pending_partners'] as List? ?? const []))
          Establishment.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
    this.isActive = true,
  });

  final String id;
  final String role;
  final String name;
  final String email;
  final String phone;
  final DateTime createdAt;
  final bool isActive;

  String get roleLabel => switch (role) {
    'customer' => 'Cliente',
    'partner' => 'Parceiro',
    'delivery' => 'Estafeta',
    'admin' => 'Administrador',
    _ => role,
  };

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: _str(json['id']),
    role: _str(json['role']),
    name: _str(json['name']),
    email: _str(json['email']),
    phone: _str(json['phone']),
    createdAt: _date(json['created_at']),
    isActive: json['is_active'] != false,
  );
}

class AuditLog {
  const AuditLog({
    required this.action,
    required this.entity,
    required this.createdAt,
    this.actor,
    this.entityId,
  });

  final String action;
  final String entity;
  final DateTime createdAt;
  final String? actor;
  final String? entityId;

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
    action: _str(json['action']),
    entity: _str(json['entity']),
    createdAt: _date(json['created_at']),
    actor: json['actor'] as String?,
    entityId: json['entity_id'] as String?,
  );
}
