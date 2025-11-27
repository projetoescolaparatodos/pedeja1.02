import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
      (total, addon) => total + addon.price,
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
      name: map['title'] ?? map['name'] ?? '', // ✅ Prioriza 'title' do backend
      price: (map['unitPrice'] ?? map['price'] ?? 0).toDouble(), // ✅ Usa 'unitPrice' do backend
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
  final String? userName;      // ✨ NOVO
  final String? userPhone;     // ✨ NOVO
  final List<OrderItem> items;
  final double total;
  final String deliveryAddress;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final PaymentInfo? payment;
  
  // ✨ Campos adicionais do pedido
  final double? subtotal;      // Subtotal dos itens (sem taxa de entrega)
  final double? deliveryFee;   // Taxa de entrega
  final double? discount;      // Desconto aplicado
  final double? serviceFee;    // Taxa de serviço

  Order({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.userId,
    required this.userEmail,
    this.userName,
    this.userPhone,
    required this.items,
    required this.total,
    required this.deliveryAddress,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.payment,
    this.subtotal,
    this.deliveryFee,
    this.discount,
    this.serviceFee,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,       // ✨ NOVO
      'userPhone': userPhone,     // ✨ NOVO
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

  /// Criar Order a partir de documento do Firestore
  factory Order.fromFirestore(Map<String, dynamic> data, String id) {
    return Order(
      id: id,
      restaurantId: data['restaurantId'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      userName: data['userName'],         // ✨ NOVO
      userPhone: data['userPhone'],       // ✨ NOVO
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] ?? data['totalAmount'] ?? 0).toDouble(),
      deliveryAddress: _parseDeliveryAddress(data['deliveryAddress']),
      status: OrderStatus.fromString(data['status'] ?? 'pending'),
      paymentStatus: PaymentStatus.fromString(data['paymentStatus'] ?? 'pending'),
      createdAt: _parseCreatedAtToDateTime(data['createdAt']),
      payment: data['payment'] != null 
          ? PaymentInfo.fromMap(data['payment'] as Map<String, dynamic>)
          : null,
      // ✨ Novos campos
      subtotal: data['subtotal'] != null ? (data['subtotal'] as num).toDouble() : null,
      deliveryFee: data['deliveryFee'] != null ? (data['deliveryFee'] as num).toDouble() : null,
      discount: data['discount'] != null ? (data['discount'] as num).toDouble() : null,
      serviceFee: data['serviceFee'] != null ? (data['serviceFee'] as num).toDouble() : null,
    );
  }

  /// Helper to parse deliveryAddress (can be String or Map)
  static String _parseDeliveryAddress(dynamic raw) {
    if (raw == null) return '';
    
    // Se já é string, retorna direto
    if (raw is String) return raw;
    
    // Se é Map, formata como string
    if (raw is Map<String, dynamic>) {
      final street = raw['street'] ?? '';
      final number = raw['number'] ?? '';
      final neighborhood = raw['neighborhood'] ?? '';
      final city = raw['city'] ?? '';
      final state = raw['state'] ?? '';
      
      if (street.isEmpty) return '';
      
      return '$street, $number - $neighborhood, $city - $state';
    }
    
    // Fallback: converte para string
    return raw.toString();
  }

  /// Helper to parse different createdAt formats (Timestamp, Map, String)
  static DateTime _parseCreatedAtToDateTime(dynamic raw) {
    try {
      if (raw == null) return DateTime.now();

      // Firestore Timestamp
      if (raw is Timestamp) return raw.toDate();

      // Some clients may serialize Timestamp as a map with 'seconds' / 'nanoseconds'
      if (raw is Map<String, dynamic>) {
        if (raw['seconds'] != null) {
          final seconds = raw['seconds'];
          if (seconds is int) {
            return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          }
          if (seconds is String) {
            return DateTime.fromMillisecondsSinceEpoch(int.parse(seconds) * 1000);
          }
        }
      }

      // ISO string
      if (raw is String) return DateTime.parse(raw);

      // Fallback: try to convert to string and parse
      return DateTime.parse(raw.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}

/// Status do pedido
enum OrderStatus {
  pending('pending', 'Processando pagamento'),           // Aguardando pagamento
  accepted('accepted', 'Pedido confirmado'),             // Pronto pra produzir ✅
  preparing('preparing', 'Preparando seu pedido'),       // Em preparação 👨‍🍳
  ready('ready', 'Pronto!'),                             // Pronto para retirada/entrega 📦
  awaitingBatch('awaiting_batch', 'Aguardando entregador'), // Aguardando lote ✋
  inBatch('in_batch', 'Saiu para entrega'),              // Em lote com entregador ✅
  outForDelivery('out_for_delivery', 'A caminho'),       // A caminho 🚴
  delivered('delivered', 'Entregue!'),                   // Entregue ✅
  cancelled('cancelled', 'Cancelado');                   // Cancelado ❌

  final String value;
  final String label;

  const OrderStatus(this.value, this.label);

  static OrderStatus fromString(String value) {
    // ✅ Suportar valores em português e inglês
    final normalizedValue = value.toLowerCase().trim().replaceAll(' ', '_');
    
    switch (normalizedValue) {
      case 'pending':
      case 'pendente':
        return OrderStatus.pending;
      case 'accepted':
      case 'aceito':
      case 'confirmado':
        return OrderStatus.accepted;
      case 'preparing':
      case 'preparando':
      case 'em_preparo':
      case 'em_preparação':
        return OrderStatus.preparing;
      case 'ready':
      case 'pronto':
        return OrderStatus.ready;
      case 'awaiting_batch':
      case 'aguardando_lote':
      case 'aguardando_entregador':
        return OrderStatus.awaitingBatch;
      case 'in_batch':
      case 'em_lote':
      case 'com_entregador':
        return OrderStatus.inBatch;
      case 'out_for_delivery':
      case 'on_the_way':
      case 'ontheway':
      case 'a_caminho':
      case 'delivering':
      case 'saiu_para_entrega':
        return OrderStatus.outForDelivery;
      case 'delivered':
      case 'entregue':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'cancelado':
        return OrderStatus.cancelled;
      default:
        debugPrint('⚠️ [OrderStatus] Status desconhecido: $value, usando pending');
        return OrderStatus.pending;
    }
  }
  
  /// 🎨 Retorna a cor apropriada para cada status
  static int getColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0xFFFFA726; // Laranja - aguardando
      case OrderStatus.accepted:
        return 0xFF66BB6A; // Verde claro - confirmado
      case OrderStatus.preparing:
        return 0xFF42A5F5; // Azul - preparando
      case OrderStatus.ready:
        return 0xFF26A69A; // Teal - pronto
      case OrderStatus.awaitingBatch:
        return 0xFFFFCA28; // Amarelo - aguardando
      case OrderStatus.inBatch:
        return 0xFF7E57C2; // Roxo - em lote
      case OrderStatus.outForDelivery:
        return 0xFF29B6F6; // Azul claro - a caminho
      case OrderStatus.delivered:
        return 0xFF66BB6A; // Verde - entregue
      case OrderStatus.cancelled:
        return 0xFFEF5350; // Vermelho - cancelado
    }
  }
  
  /// 📍 Retorna o ícone apropriado para cada status
  static String getIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return '⏳'; // Aguardando pagamento
      case OrderStatus.accepted:
        return '✅'; // Confirmado
      case OrderStatus.preparing:
        return '👨‍🍳'; // Preparando
      case OrderStatus.ready:
        return '📦'; // Pronto
      case OrderStatus.awaitingBatch:
        return '✋'; // Aguardando entregador
      case OrderStatus.inBatch:
        return '🚀'; // Em lote
      case OrderStatus.outForDelivery:
        return '🚴'; // A caminho
      case OrderStatus.delivered:
        return '🎉'; // Entregue
      case OrderStatus.cancelled:
        return '❌'; // Cancelado
    }
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
  final String? method; // 'cash', 'pix', 'credit_card', 'debit_card'
  final String? provider;
  final String status;
  final String? transactionId;
  final String? initPoint; // URL do checkout MP
  final bool? needsChange; // ✨ Precisa de troco?
  final double? changeFor; // ✨ Vai pagar com quanto?
  final double? changeAmount; // ✨ Valor do troco

  PaymentInfo({
    this.method,
    this.provider,
    required this.status,
    this.transactionId,
    this.initPoint,
    this.needsChange,
    this.changeFor,
    this.changeAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'provider': provider,
      'status': status,
      'transactionId': transactionId,
      'initPoint': initPoint,
      'needsChange': needsChange,
      'changeFor': changeFor,
      'changeAmount': changeAmount,
    };
  }

  factory PaymentInfo.fromMap(Map<String, dynamic> map) {
    return PaymentInfo(
      method: map['method'],
      provider: map['provider'],
      status: map['status'] ?? 'pending',
      transactionId: map['transactionId'],
      initPoint: map['initPoint'],
      needsChange: map['needsChange'],
      changeFor: map['changeFor'] != null ? (map['changeFor'] as num).toDouble() : null,
      changeAmount: map['changeAmount'] != null ? (map['changeAmount'] as num).toDouble() : null,
    );
  }
}
