import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:http/http.dart' as http;
import 'notification_service.dart';
import '../models/order_model.dart' as models;

/// 📡 Serviço de Monitoramento de Status via Pusher (Real-time)
/// 
/// Este serviço recebe atualizações de status diretamente do backend via Pusher,
/// proporcionando notificações instantâneas quando o status do pedido muda.
class OrderStatusPusherService {
  static final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  static bool _initialized = false;
  static String? _currentUserId;
  static String? _currentChannelName;
  
  // ✅ Getter para verificar inicialização externa
  static bool get isInitialized => _initialized;
  
  // Callbacks para atualização da UI
  static Function(String orderId, models.OrderStatus status)? onStatusUpdate;

  /// Configuração do Pusher
  static const String _apiKey = '45b7798e358505a8343e';
  static const String _cluster = 'us2';

  /// Inicializar Pusher e conectar ao canal do usuário
  static Future<void> initialize({
    required String userId,
    String? authToken,
    Function(String orderId, models.OrderStatus status)? onUpdate,
  }) async {
    try {
      _currentUserId = userId;
      onStatusUpdate = onUpdate;
      
      debugPrint('📡 [OrderStatusPusher] Inicializando para usuário $userId...');

      if (!_initialized) {
        debugPrint('📡 [OrderStatusPusher] Configurando Pusher...');

        await _pusher.init(
          apiKey: _apiKey,
          cluster: _cluster,
          onError: (String message, int? code, dynamic e) {
            debugPrint('❌ [OrderStatusPusher] Erro: $message (code: $code)');
          },
          onConnectionStateChange: (String? currentState, String? previousState) {
            debugPrint('🔄 [OrderStatusPusher] Estado: $previousState → $currentState');
            
            // ✅ Reconectar automaticamente se desconectado
            if (currentState == 'DISCONNECTED' && _initialized && _currentUserId != null) {
              debugPrint('🔄 [OrderStatusPusher] Reconectando...');
              Future.delayed(const Duration(seconds: 2), () {
                _pusher.connect().then((_) {
                  debugPrint('✅ [OrderStatusPusher] Reconectado!');
                }).catchError((e) {
                  debugPrint('❌ [OrderStatusPusher] Erro ao reconectar: $e');
                });
              });
            }
          },
          onAuthorizer: (String channelName, String socketId, dynamic options) async {
            // Autorizar canal privado com o backend
            debugPrint('🔐 [OrderStatusPusher] Autorizando canal: $channelName');
            
            // Se tiver token, enviar para backend autorizar
            if (authToken != null) {
              try {
                // Backend deve ter endpoint /api/pusher/auth
                final response = await _authorizeChannel(
                  channelName: channelName,
                  socketId: socketId,
                  authToken: authToken,
                );
                return response;
              } catch (e) {
                debugPrint('❌ [OrderStatusPusher] Erro na autorização: $e');
                return null;
              }
            }
            
            return null;
          },
        );

        await _pusher.connect();
        _initialized = true;
        debugPrint('✅ [OrderStatusPusher] Pusher inicializado e conectado');
      }

      // Inscrever no canal do usuário
      await _subscribeToUserChannel(userId);
      
    } catch (e) {
      debugPrint('❌ [OrderStatusPusher] Erro ao inicializar: $e');
    }
  }

  /// Autorizar canal privado no backend
  static Future<Map<String, dynamic>?> _authorizeChannel({
    required String channelName,
    required String socketId,
    required String authToken,
  }) async {
    try {
      // ✅ Implementando autenticação via endpoint do backend
      final response = await http.post(
        Uri.parse('https://api-pedeja.vercel.app/pusher/auth'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'socket_id': socketId,
          'channel_name': channelName,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ [OrderStatusPusher] Canal autorizado: $channelName');
        return json.decode(response.body);
      } else {
        debugPrint('❌ [OrderStatusPusher] Erro na autorização: ${response.statusCode}');
        return null;
      }
      
    } catch (e) {
      debugPrint('❌ [OrderStatusPusher] Erro ao autorizar canal: $e');
      return null;
    }
  }

  /// Inscrever no canal do usuário
  static Future<void> _subscribeToUserChannel(String userId) async {
    try {
      // ✅ Canal privado do usuário: private-user-{userId}
      _currentChannelName = 'private-user-$userId';
      
      debugPrint('📡 [OrderStatusPusher] Inscrevendo no canal: $_currentChannelName');

      await _pusher.subscribe(
        channelName: _currentChannelName!,
        onEvent: (dynamic event) {
          try {
            debugPrint('📨 [OrderStatusPusher] Evento recebido: ${event.eventName}');

            if (event.eventName == 'order-status-updated' && event.data != null) {
              _handleStatusUpdate(event.data);
            }
          } catch (e) {
            debugPrint('❌ [OrderStatusPusher] Erro ao processar evento: $e');
          }
        },
      );

      debugPrint('✅ [OrderStatusPusher] Inscrito no canal $_currentChannelName');
    } catch (e) {
      debugPrint('❌ [OrderStatusPusher] Erro ao inscrever no canal: $e');
    }
  }

  /// Processar atualização de status recebida
  static void _handleStatusUpdate(dynamic eventData) {
    try {
      Map<String, dynamic> data;

      // Parsear dados do evento
      if (eventData is String) {
        data = json.decode(eventData);
      } else if (eventData is Map<String, dynamic>) {
        data = eventData;
      } else {
        data = Map<String, dynamic>.from(eventData as Map);
      }

      debugPrint('📦 [OrderStatusPusher] Dados parsed: $data');

      final orderId = data['orderId'] as String?;
      final statusStr = data['status'] as String?;
      final restaurantName = data['restaurantName'] as String? ?? 'Restaurante';
      
      if (orderId == null || statusStr == null) {
        debugPrint('⚠️ [OrderStatusPusher] Dados incompletos no evento');
        return;
      }

      // Converter string de status para enum
      final status = _parseStatus(statusStr);
      if (status == null) {
        debugPrint('⚠️ [OrderStatusPusher] Status inválido: $statusStr');
        return;
      }

      debugPrint('🔄 [OrderStatusPusher] Status atualizado: Pedido $orderId → ${status.label}');

      // Enviar notificação
      _sendStatusNotification(orderId, status, restaurantName);

      // Notificar callback para atualizar UI
      onStatusUpdate?.call(orderId, status);
      
    } catch (e) {
      debugPrint('❌ [OrderStatusPusher] Erro ao processar atualização: $e');
    }
  }

  /// Converter string de status para enum
  static models.OrderStatus? _parseStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'pendente':
        return models.OrderStatus.pending;
      case 'em_preparo':
      case 'preparing':
        return models.OrderStatus.preparing;
      case 'pronto':
      case 'ready':
        return models.OrderStatus.ready;
      case 'a_caminho':
      case 'on_the_way':
        return models.OrderStatus.outForDelivery;
      case 'entregue':
      case 'delivered':
        return models.OrderStatus.delivered;
      case 'cancelado':
      case 'cancelled':
        return models.OrderStatus.cancelled;
      default:
        return null;
    }
  }

  /// Enviar notificação de mudança de status
  static void _sendStatusNotification(
    String orderId,
    models.OrderStatus status,
    String restaurantName,
  ) {
    String title;
    String body;

    switch (status) {
      case models.OrderStatus.pending:
        title = '🕒 Pedido Recebido';
        body = 'Seu pedido #${orderId.substring(0, 8)} foi recebido e está aguardando confirmação';
        break;
      case models.OrderStatus.accepted:
        title = '✅ Pedido Confirmado';
        body = 'Seu pedido #${orderId.substring(0, 8)} foi confirmado e está sendo preparado!';
        break;
      case models.OrderStatus.preparing:
        title = '👨‍🍳 Pedido em Preparo';
        body = 'Seu pedido #${orderId.substring(0, 8)} está sendo preparado!';
        break;
      case models.OrderStatus.ready:
        title = '📦 Pedido Pronto';
        body = 'Seu pedido #${orderId.substring(0, 8)} está pronto!';
        break;
      case models.OrderStatus.awaitingBatch:
        title = '✋ Aguardando Entregador';
        body = 'Seu pedido #${orderId.substring(0, 8)} está aguardando um entregador';
        break;
      case models.OrderStatus.inBatch:
        title = '🚀 Saiu para Entrega';
        body = 'Seu pedido #${orderId.substring(0, 8)} está com o entregador!';
        break;
      case models.OrderStatus.outForDelivery:
        title = '🚴 Pedido a Caminho';
        body = 'Seu pedido #${orderId.substring(0, 8)} está a caminho!';
        break;
      case models.OrderStatus.delivered:
        title = '🎉 Pedido Entregue';
        body = 'Seu pedido #${orderId.substring(0, 8)} foi entregue. Bom apetite!';
        break;
      case models.OrderStatus.cancelled:
        title = '❌ Pedido Cancelado';
        body = 'Seu pedido #${orderId.substring(0, 8)} foi cancelado';
        break;
    }

    // ✅ REMOVIDO: Não dispara notificação local aqui para evitar duplicatas
    // O backend envia via FCM, Pusher serve apenas para atualização de UI em tempo real
    debugPrint('📦 [OrderStatusPusher] Status atualizado via Pusher: ${status.label}');
    debugPrint('📦 [OrderStatusPusher] Notificação será enviada pelo backend via FCM');
    
    // NotificationService.showOrderStatusNotification(...) - REMOVIDO
  }

  /// Desconectar e limpar recursos
  static Future<void> disconnect() async {
    try {
      debugPrint('👋 [OrderStatusPusher] Desconectando...');

      if (_currentChannelName != null) {
        try {
          await _pusher.unsubscribe(channelName: _currentChannelName!);
        } catch (e) {
          debugPrint('⚠️ [OrderStatusPusher] Erro ao unsubscribe: $e');
        }
      }

      try {
        await _pusher.disconnect().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            debugPrint('⚠️ [OrderStatusPusher] Timeout ao desconectar');
          },
        );
      } catch (e) {
        debugPrint('⚠️ [OrderStatusPusher] Erro ao desconectar: $e');
      }

      _initialized = false;
      _currentUserId = null;
      _currentChannelName = null;
      onStatusUpdate = null;
      
      debugPrint('✅ [OrderStatusPusher] Desconectado');
    } catch (e) {
      debugPrint('❌ [OrderStatusPusher] Erro ao desconectar: $e');
    }
  }

  /// Verificar se está conectado
  static bool isConnected() {
    return _initialized && _currentUserId != null;
  }
}
