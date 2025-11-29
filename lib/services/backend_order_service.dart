import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/order_model.dart' as models;

/// 🌐 Serviço de integração com API backend de pedidos
class BackendOrderService {
  static const String apiUrl = 'https://api-pedeja.vercel.app';

  /// Criar pedido via API
  Future<String> createOrder({
    required String token,
    required String restaurantId,
    required String restaurantName,
    required List<models.OrderItem> items,
    required double total,
    required Map<String, dynamic> deliveryAddress,
    required Map<String, dynamic> payment,
    String? userName,
    String? userPhone,
  }) async {
    try {
      debugPrint('📦 [BackendOrderService] Criando pedido na API...');
      debugPrint('   Restaurante: $restaurantName');
      debugPrint('   Total: R\$ ${total.toStringAsFixed(2)}');
      debugPrint('   Método: ${payment['method']}');

      final response = await http.post(
        Uri.parse('$apiUrl/api/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'restaurantId': restaurantId,
          'restaurantName': restaurantName,
          'items': items.map((item) => {
            'productId': item.productId,
            'title': item.name,              // API espera 'title' ao invés de 'name'
            'unitPrice': item.price,         // API espera 'unitPrice' ao invés de 'price'
            'quantity': item.quantity,
            'imageUrl': item.imageUrl,
            'addons': item.addons.map((addon) => {
              'name': addon.name,
              'price': addon.price,
            }).toList(),
          }).toList(),
          'totalAmount': total,
          'deliveryFee': 0.0,              // ✅ Taxa de entrega sempre 0 (adicionada manualmente depois pelo vendedor)
          'deliveryAddress': deliveryAddress,
          'payment': payment,
          if (userName != null) 'userName': userName,
          if (userPhone != null) 'userPhone': userPhone,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        final orderId = data['orderId'] ?? data['id'] ?? data['_id'];
        
        debugPrint('✅ [BackendOrderService] Pedido criado: $orderId');
        
        // Log do troco calculado se houver
        if (payment['method'] == 'cash' && payment['needsChange'] == true) {
          final changeAmount = data['payment']?['changeAmount'];
          if (changeAmount != null) {
            debugPrint('💰 Troco calculado: R\$ ${changeAmount.toStringAsFixed(2)}');
          }
        }
        
        return orderId.toString();
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Erro desconhecido';
        
        debugPrint('❌ [BackendOrderService] Erro ${response.statusCode}: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ [BackendOrderService] Erro ao criar pedido: $e');
      rethrow;
    }
  }

  /// Confirmar pagamento em dinheiro (entregador/restaurante)
  Future<void> confirmCashPayment({
    required String token,
    required String orderId,
    double? receivedAmount,
    double? changeGiven,
  }) async {
    try {
      debugPrint('💵 [BackendOrderService] Confirmando pagamento em dinheiro...');
      debugPrint('   Pedido: $orderId');

      final body = <String, dynamic>{};
      if (receivedAmount != null) body['receivedAmount'] = receivedAmount;
      if (changeGiven != null) body['changeGiven'] = changeGiven;

      final response = await http.patch(
        Uri.parse('$apiUrl/api/orders/$orderId/confirm-cash-payment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ [BackendOrderService] Pagamento confirmado');
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Erro desconhecido';
        
        debugPrint('❌ [BackendOrderService] Erro ${response.statusCode}: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ [BackendOrderService] Erro ao confirmar pagamento: $e');
      rethrow;
    }
  }

  /// Enviar mensagem de chat via backend (backend deve repassar ao Pusher)
  Future<void> sendChatMessage({
    required String token, // ✅ Token obrigatório
    required String orderId,
    required String message,
    required String senderName,
    required String userId,
    bool isRestaurant = false,
  }) async {
    try {
      final body = {
        'message': message,
        'senderName': senderName,
        'userId': userId,
        'isRestaurant': isRestaurant,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$apiUrl/api/orders/$orderId/messages'),
        headers: {
          'Authorization': 'Bearer $token', // ✅ Header de autorização adicionado
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [BackendOrderService] Mensagem enviada via backend');
        return;
      }

      final errorBody = json.decode(response.body);
      final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Erro desconhecido';
      debugPrint('❌ [BackendOrderService] Erro ao enviar chat: $errorMessage');
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('❌ [BackendOrderService] Exceção ao enviar chat: $e');
      rethrow;
    }
  }

  /// Buscar pedido por ID
  Future<Map<String, dynamic>> getOrder({
    required String token,
    required String orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/orders/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Erro desconhecido';
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ [BackendOrderService] Erro ao buscar pedido: $e');
      rethrow;
    }
  }

  /// Buscar pedidos do usuário
  Future<List<Map<String, dynamic>>> getUserOrders({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/orders/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['orders'] ?? []);
      } else {
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? errorBody['error'] ?? 'Erro desconhecido';
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ [BackendOrderService] Erro ao buscar pedidos: $e');
      rethrow;
    }
  }
}
