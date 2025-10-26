import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;

/// Serviço de pagamentos com Mercado Pago (Split Payment)
/// NOTA: Temporariamente desabilitado devido incompatibilidade firebase_auth_web
class PaymentService {
  static const String apiUrl = 'https://api-pedeja.vercel.app';

  Future<Map<String, dynamic>> createPaymentWithSplit({
    required String orderId,
    String paymentMethod = 'mercadopago',
    int installments = 1,
  }) async {
    debugPrint('⚠️ Firebase desabilitado - createPaymentWithSplit simulado');
    
    return {
      'success': false,
      'error': 'Firebase temporariamente desabilitado. Configure Firebase para habilitar pagamentos.',
    };
  }

  Future<bool> isRestaurantConfigured(String restaurantId) async {
    debugPrint('⚠️ Firebase desabilitado - isRestaurantConfigured simulado');
    return false;
  }

  Future<Map<String, dynamic>> getPaymentStatus(String orderId) async {
    debugPrint('⚠️ Firebase desabilitado - getPaymentStatus simulado');
    return {'status': 'pending'};
  }
}
