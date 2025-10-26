// TEMPORARIAMENTE DESABILITADO - Firebase incompatível
// import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de item do pedido
class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final List<OrderItemAddon> addons;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.addons = const [],
  });

  double get totalPrice {
    final addonsTotal = addons.fold<double>(
      0,
      (sum, addon) => sum + addon.price,
    );
    return (price + addonsTotal) * quantity;
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'addons': addons.map((a) => a.toMap()).toList(),
      'totalPrice': totalPrice,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      imageUrl: map['imageUrl'] ?? '',
      addons: (map['addons'] as List<dynamic>?)
              ?.map((a) => OrderItemAddon.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Modelo de adicional do item
class OrderItemAddon {
  final String name;
  final double price;

  OrderItemAddon({
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
    };
  }

  factory OrderItemAddon.fromMap(Map<String, dynamic> map) {
    return OrderItemAddon(
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
    );
  }
}

/// Modelo completo do pedido
class Order {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String userId;
  final String userEmail;
  final List<OrderItem> items;
  final double total;
  final String deliveryAddress;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final PaymentInfo? payment;

  Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.userId,
    required this.userEmail,
    required this.items,
    required this.total,
    required this.deliveryAddress,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.payment,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'userId': userId,
      'userEmail': userEmail,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'totalAmount': total, // Compatibilidade com API
      'deliveryAddress': deliveryAddress,
      'status': status.value,
      'paymentStatus': paymentStatus.value,
      'createdAt': DateTime.now().toIso8601String(),
      'payment': payment?.toMap() ?? {
        'method': null,
        'provider': null,
        'status': 'pending',
      },
    };
  }

  // TEMPORARIAMENTE DESABILITADO - Firebase incompatível
  /*
  factory Order.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Order(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] ?? data['totalAmount'] ?? 0).toDouble(),
      deliveryAddress: data['deliveryAddress'] ?? '',
      status: OrderStatus.fromString(data['status'] ?? 'pending'),
      paymentStatus: PaymentStatus.fromString(data['paymentStatus'] ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      payment: data['payment'] != null 
          ? PaymentInfo.fromMap(data['payment'] as Map<String, dynamic>)
          : null,
    );
  }
  */
}

/// Status do pedido
enum OrderStatus {
  pending('pending', 'Pendente'),
  preparing('preparing', 'Preparando'),
  ready('ready', 'Pronto'),
  delivered('delivered', 'Entregue'),
  cancelled('cancelled', 'Cancelado');

  final String value;
  final String label;

  const OrderStatus(this.value, this.label);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

/// Status do pagamento
enum PaymentStatus {
  pending('pending', 'Pendente'),
  approved('approved', 'Aprovado'),
  paid('paid', 'Pago'),
  rejected('rejected', 'Rejeitado'),
  cancelled('cancelled', 'Cancelado');

  final String value;
  final String label;

  const PaymentStatus(this.value, this.label);

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Informações do pagamento
class PaymentInfo {
  final String? method;
  final String? provider;
  final String status;
  final String? transactionId;
  final String? initPoint; // URL do checkout MP

  PaymentInfo({
    this.method,
    this.provider,
    required this.status,
    this.transactionId,
    this.initPoint,
  });

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'provider': provider,
      'status': status,
      'transactionId': transactionId,
      'initPoint': initPoint,
    };
  }

  factory PaymentInfo.fromMap(Map<String, dynamic> map) {
    return PaymentInfo(
      method: map['method'],
      provider: map['provider'],
      status: map['status'] ?? 'pending',
      transactionId: map['transactionId'],
      initPoint: map['initPoint'],
    );
  }
}
