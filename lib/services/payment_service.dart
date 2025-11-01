import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;

/// 💳 Serviço de pagamentos com Mercado Pago (Split Payment)
class PaymentService {
  static const String apiUrl = 'https://api-pedeja.vercel.app';

  /// Criar pagamento DIRETO com application_fee (Checkout API)
  Future<Map<String, dynamic>> createDirectPayment({
    required String orderId,
    required String? jwtToken,
    required String paymentMethodId, // 'pix', 'credit_card', etc
    required String payerEmail,
    required String identificationType, // 'CPF' ou 'CNPJ'
    required String identificationNumber,
    String? token, // Token do cartão (se for credit_card)
    int installments = 1,
  }) async {
    try {
      debugPrint('💳 [PaymentService] Criando pagamento DIRETO...');
      debugPrint('   Order ID: $orderId');
      debugPrint('   Payment Method: $paymentMethodId');
      
      if (jwtToken == null || jwtToken.isEmpty) {
        debugPrint('❌ [PaymentService] Token JWT não encontrado');
        return {
          'success': false,
          'error': 'Token de autenticação não encontrado. Faça login novamente.',
        };
      }
      
      debugPrint('🔑 [PaymentService] Token JWT recebido');
      
      final body = {
        'orderId': orderId,
        'paymentMethodId': paymentMethodId,
        'payerEmail': payerEmail,
        'identificationType': identificationType,
        'identificationNumber': identificationNumber,
      };
      
      // Adicionar token do cartão se fornecido
      if (token != null && token.isNotEmpty) {
        body['token'] = token;
      }
      
      if (installments > 1) {
        body['installments'] = installments.toString();
      }
      
      final response = await http.post(
        Uri.parse('$apiUrl/api/payments/mp/create-direct'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode(body),
      );

      debugPrint('📡 [PaymentService] Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        debugPrint('🔍 [PaymentService] Response body completo: $data');
        
        if (data['success'] == true) {
          debugPrint('✅ [PaymentService] Pagamento direto criado com sucesso');
          
          final payment = data['payment'];
          debugPrint('   Payment ID: ${payment?['id']}');
          debugPrint('   Status: ${payment?['status']}');
          
          if (paymentMethodId == 'pix') {
            debugPrint('   QR Code: ${payment?['qrCode']?.substring(0, 50)}...');
          }
          
          return {
            'success': true,
            'payment': payment,
          };
        } else {
          final error = data['error'] ?? 'Erro desconhecido';
          debugPrint('❌ [PaymentService] Erro na API: $error');
          
          return {
            'success': false,
            'error': error,
          };
        }
      } else {
        debugPrint('❌ [PaymentService] Erro HTTP: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
        
        return {
          'success': false,
          'error': 'Erro ao criar pagamento (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('❌ [PaymentService] Exceção: $e');
      
      return {
        'success': false,
        'error': 'Erro ao conectar com servidor: $e',
      };
    }
  }

  /// Criar pagamento com split (divide valor entre plataforma e restaurante)
  /// DEPRECADO - Use createDirectPayment() para melhor controle
  Future<Map<String, dynamic>> createPaymentWithSplit({
    required String orderId,
    required String? jwtToken, // ← Token JWT como parâmetro
    String paymentMethod = 'mercadopago',
    int installments = 1,
  }) async {
    try {
      debugPrint('💳 [PaymentService] Criando pagamento...');
      debugPrint('   Order ID: $orderId');
      debugPrint('   Método: $paymentMethod');
      
      // 🔑 Validar token JWT
      if (jwtToken == null || jwtToken.isEmpty) {
        debugPrint('❌ [PaymentService] Token JWT não encontrado');
        return {
          'success': false,
          'error': 'Token de autenticação não encontrado. Faça login novamente.',
        };
      }
      
      debugPrint('🔑 [PaymentService] Token JWT recebido');
      
      final response = await http.post(
        Uri.parse('$apiUrl/api/payment/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken', // ← Header de autenticação
        },
        body: jsonEncode({
          'orderId': orderId,
          'paymentMethod': paymentMethod,
          'installments': installments,
        }),
      );

      debugPrint('📡 [PaymentService] Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        debugPrint('🔍 [PaymentService] Response body completo: $data');
        debugPrint('🔍 [PaymentService] data.keys: ${data.keys}');
        debugPrint('🔍 [PaymentService] data["initPoint"]: ${data['initPoint']}');
        debugPrint('🔍 [PaymentService] data["init_point"]: ${data['init_point']}');
        
        if (data['success'] == true) {
          debugPrint('✅ [PaymentService] Pagamento criado com sucesso');
          
          // O backend retorna initPoint diretamente no data, não dentro de payment
          final initPoint = data['initPoint'] ?? data['init_point'];
          final paymentId = data['paymentId'] ?? data['payment_id'];
          
          debugPrint('   Init Point: $initPoint');
          debugPrint('   Payment ID: $paymentId');
          
          return {
            'success': true,
            'payment': {
              'initPoint': initPoint,
              'init_point': initPoint, // Ambas as variações
              'id': paymentId,
            },
          };
        } else {
          final error = data['error'] ?? 'Erro desconhecido';
          debugPrint('❌ [PaymentService] Erro na API: $error');
          
          return {
            'success': false,
            'error': error,
          };
        }
      } else {
        debugPrint('❌ [PaymentService] Erro HTTP: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
        
        return {
          'success': false,
          'error': 'Erro ao criar pagamento (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('❌ [PaymentService] Exceção: $e');
      
      return {
        'success': false,
        'error': 'Erro ao conectar com servidor: $e',
      };
    }
  }

  /// Verificar se restaurante está configurado para receber pagamentos
  Future<bool> isRestaurantConfigured(String restaurantId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/payment/restaurant/$restaurantId/status'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['configured'] == true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ [PaymentService] Erro ao verificar configuração: $e');
      return false;
    }
  }

  /// Buscar status do pagamento
  Future<Map<String, dynamic>> getPaymentStatus(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiUrl/api/payment/status/$orderId'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      
      return {'status': 'unknown'};
    } catch (e) {
      debugPrint('❌ [PaymentService] Erro ao buscar status: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }
}
