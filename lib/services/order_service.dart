import 'package:flutter/foundation.dart' show debugPrint;
import '../models/order_model.dart' as models;

/// Serviço de gerenciamento de pedidos no Firebase
/// NOTA: Temporariamente desabilitado devido incompatibilidade firebase_auth_web
class OrderService {
  Future<String> createOrder({
    required String restaurantId,
    required String restaurantName,
    required List<models.OrderItem> items,
    required double total,
    required String deliveryAddress,
  }) async {
    debugPrint('⚠️ Firebase desabilitado - createOrder simulado');
    return 'mock-order-id-${DateTime.now().millisecondsSinceEpoch}';
  }
  
  Future<models.Order?> getOrder(String orderId) async {
    debugPrint('⚠️ Firebase desabilitado - getOrder simulado');
    return null;
  }
  
  Stream<models.Order?> watchOrder(String orderId) {
    debugPrint('⚠️ Firebase desabilitado - watchOrder simulado');
    return Stream.value(null);
  }
  
  Future<List<models.Order>> getUserOrders() async {
    debugPrint('⚠️ Firebase desabilitado - getUserOrders simulado');
    return [];
  }
  
  Stream<List<models.Order>> watchUserOrders() {
    debugPrint('⚠️ Firebase desabilitado - watchUserOrders simulado');
    return Stream.value([]);
  }
  
  Future<void> updateOrderStatus({
    required String orderId,
    required models.OrderStatus status,
  }) async {
    debugPrint('⚠️ Firebase desabilitado - updateOrderStatus simulado');
  }
  
  Future<void> updatePaymentInfo({
    required String orderId,
    required models.PaymentInfo payment,
  }) async {
    debugPrint('⚠️ Firebase desabilitado - updatePaymentInfo simulado');
  }
  
  Future<void> cancelOrder(String orderId) async {
    debugPrint('⚠️ Firebase desabilitado - cancelOrder simulado');
  }
}
