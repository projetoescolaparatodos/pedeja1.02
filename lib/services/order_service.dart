import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/order_model.dart' as models;

/// 📦 Serviço de gerenciamento de pedidos no Firestore
class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Criar novo pedido
  Future<String> createOrder({
    required String restaurantId,
    required String restaurantName,
    required List<models.OrderItem> items,
    required double total,
    required String deliveryAddress,
    models.PaymentInfo? paymentInfo,
    double subtotal = 0.0,
    double deliveryFee = 0.0,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      debugPrint('📦 [OrderService] Criando pedido...');
      debugPrint('   Restaurante: $restaurantName');
      debugPrint('   Subtotal: R\$ ${subtotal.toStringAsFixed(2)}');
      debugPrint('   Taxa Entrega: R\$ ${deliveryFee.toStringAsFixed(2)}');
      debugPrint('   Total: R\$ ${total.toStringAsFixed(2)}');
      debugPrint('   Itens: ${items.length}');

      // Criar documento do pedido
      final orderData = {
        'userId': user.uid,
        'userEmail': user.email,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'items': items.map((item) => {
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'imageUrl': item.imageUrl,
          'addons': item.addons.map((addon) => {
            'name': addon.name,
            'price': addon.price,
          }).toList(),
        }).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'total': total,
        'deliveryAddress': deliveryAddress,
        'status': 'pending', // pending, confirmed, preparing, delivering, delivered, cancelled
        'paymentStatus': 'pending', // pending, paid, failed, refunded
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Adicionar informações de pagamento se fornecidas
      if (paymentInfo != null) {
        orderData['paymentInfo'] = {
          'method': paymentInfo.method,
          'provider': paymentInfo.provider,
          'status': paymentInfo.status,
          if (paymentInfo.needsChange != null) 'needsChange': paymentInfo.needsChange,
          if (paymentInfo.changeFor != null) 'changeFor': paymentInfo.changeFor,
        };
      }

      final docRef = await _firestore.collection('orders').add(orderData);
      
      debugPrint('✅ [OrderService] Pedido criado: ${docRef.id}');
      
      return docRef.id;
    } catch (e) {
      debugPrint('❌ [OrderService] Erro ao criar pedido: $e');
      rethrow;
    }
  }
  
  /// Buscar pedido por ID
  Future<models.Order?> getOrder(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      
      if (!doc.exists) {
        debugPrint('⚠️ [OrderService] Pedido não encontrado: $orderId');
        return null;
      }
      
      return models.Order.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('❌ [OrderService] Erro ao buscar pedido: $e');
      return null;
    }
  }
  
  /// Monitorar pedido em tempo real
  Stream<models.Order?> watchOrder(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return models.Order.fromFirestore(doc.data()!, doc.id);
    });
  }
  
  /// Buscar pedidos do usuário
  Future<List<models.Order>> getUserOrders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ [OrderService] Usuário não autenticado');
        return [];
      }

      final snapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => models.Order.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('❌ [OrderService] Erro ao buscar pedidos: $e');
      return [];
    }
  }
  
  /// Monitorar pedidos do usuário em tempo real
  Stream<List<models.Order>> watchUserOrders() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => models.Order.fromFirestore(doc.data(), doc.id))
            .toList());
  }
  
  /// Atualizar status do pedido
  Future<void> updateOrderStatus({
    required String orderId,
    required models.OrderStatus status,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ [OrderService] Status atualizado: $orderId -> $status');
    } catch (e) {
      debugPrint('❌ [OrderService] Erro ao atualizar status: $e');
      rethrow;
    }
  }
  
  /// Atualizar informações de pagamento
  Future<void> updatePaymentInfo({
    required String orderId,
    required models.PaymentInfo payment,
  }) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'payment': {
          'method': payment.method,
          'provider': payment.provider,
          'status': payment.status,
          'transactionId': payment.transactionId,
          'initPoint': payment.initPoint,
        },
        'paymentStatus': payment.status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ [OrderService] Pagamento atualizado: $orderId');
    } catch (e) {
      debugPrint('❌ [OrderService] Erro ao atualizar pagamento: $e');
      rethrow;
    }
  }
  
  /// Cancelar pedido
  Future<void> cancelOrder(String orderId) async {
    try {
      await updateOrderStatus(
        orderId: orderId,
        status: models.OrderStatus.cancelled,
      );
      debugPrint('✅ [OrderService] Pedido cancelado: $orderId');
    } catch (e) {
      debugPrint('❌ [OrderService] Erro ao cancelar pedido: $e');
      rethrow;
    }
  }
  
  /// Confirmar pagamento em dinheiro (chamado pelo entregador/restaurante)
  Future<void> confirmCashPayment({
    required String orderId,
    double? receivedAmount,
    double? changeGiven,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'paymentStatus': 'paid',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (receivedAmount != null) {
        updateData['paymentInfo.receivedAmount'] = receivedAmount;
      }
      if (changeGiven != null) {
        updateData['paymentInfo.changeGiven'] = changeGiven;
      }
      
      await _firestore.collection('orders').doc(orderId).update(updateData);
      
      debugPrint('✅ [OrderService] Pagamento em dinheiro confirmado: $orderId');
    } catch (e) {
      debugPrint('❌ [OrderService] Erro ao confirmar pagamento: $e');
      rethrow;
    }
  }
}
