import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'backend_order_service.dart';
import 'notification_service.dart';

/// 💬 Modelo de mensagem do chat
class ChatMessage {
  final String user;
  final String message;
  final DateTime timestamp;
  final bool isMe;
  final bool isRestaurant;

  ChatMessage({
    required this.user,
    required this.message,
    required this.timestamp,
    this.isMe = false,
    this.isRestaurant = false,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> data, {bool isMe = false}) {
    return ChatMessage(
      user: data['user'] ?? data['senderName'] ?? 'Desconhecido',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'])
          : DateTime.now(),
      isMe: isMe,
      isRestaurant: data['isRestaurant'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user': user,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRestaurant': isRestaurant,
    };
  }
}

/// 💬 Serviço de Chat em Tempo Real com Pusher
class ChatService {
  static final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();
  static bool _initialized = false;
  
  // Callbacks por orderId
  static final Map<String, Function(ChatMessage)> _messageCallbacks = {};
  static final Map<String, Function(String)> _errorCallbacks = {};
  
  // Mensagens em cache por orderId
  static final Map<String, List<ChatMessage>> _messagesCache = {};
  
  // Lista de canais ativos
  static final Set<String> _activeChannels = {};

  /// Configuração do Pusher
  static const String _apiKey = '45b7798e358505a8343e';
  static const String _cluster = 'us2';

  /// Inicializar Pusher e conectar ao canal do pedido
  static Future<void> initialize({
    required String orderId,
    required String userId,
    required Function(ChatMessage) onMessageReceived,
    Function(String)? onError,
  }) async {
    try {
      debugPrint('💬 [ChatService] Inicializando para pedido $orderId...');
      
      // Salvar callbacks
      _messageCallbacks[orderId] = onMessageReceived;
      if (onError != null) {
        _errorCallbacks[orderId] = onError;
      }

      if (!_initialized) {
        debugPrint('💬 [ChatService] Inicializando Pusher...');

        try {
          await _pusher.init(
            apiKey: _apiKey,
            cluster: _cluster,
            onError: (String message, int? code, dynamic e) {
              debugPrint('❌ [ChatService] Erro Pusher: $message (code: $code)');
              for (var callback in _errorCallbacks.values) {
                callback(message);
              }
            },
            onConnectionStateChange: (String? currentState, String? previousState) {
              debugPrint('🔄 [ChatService] Estado: $previousState -> $currentState');
            },
          );

          _initialized = true;
          debugPrint('✅ [ChatService] Pusher inicializado');
        } catch (e) {
          debugPrint('❌ [ChatService] Erro crítico na inicialização: $e');
          onError?.call('Erro ao inicializar Pusher: $e');
          return;
        }
      }

      // Conectar ao canal se ainda não estiver conectado
      await _connectToChannel(orderId, userId);
      
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao inicializar: $e');
      onError?.call('Erro ao conectar ao chat: $e');
    }
  }

  /// Conectar a um canal específico
  static Future<void> _connectToChannel(String orderId, String userId) async {
    final channelName = 'order-$orderId';
    
    // Se já estiver conectado, não reconectar
    if (_activeChannels.contains(channelName)) {
      debugPrint('✅ [ChatService] Já conectado ao canal $channelName');
      return;
    }

    debugPrint('📡 [ChatService] Inscrevendo no canal: $channelName');

    await _pusher.subscribe(
      channelName: channelName,
      onEvent: (dynamic event) {
        try {
          debugPrint('📨 [ChatService] Evento recebido RAW: $event');
          debugPrint('📨 [ChatService] Event name: ${event.eventName}');
          debugPrint('📨 [ChatService] Event data: ${event.data}');

          // API/back-end deve enviar evento 'new-message'
          if (event.eventName == 'new-message' && event.data != null) {
            dynamic raw = event.data;
            Map<String, dynamic> data;

            debugPrint('📨 [ChatService] Raw data type: ${raw.runtimeType}');

            if (raw is String) {
              debugPrint('📨 [ChatService] Parsing String JSON...');
              data = json.decode(raw) as Map<String, dynamic>;
            } else if (raw is Map<String, dynamic>) {
              debugPrint('📨 [ChatService] Data já é Map');
              data = raw;
            } else {
              debugPrint('📨 [ChatService] Converting to Map...');
              data = Map<String, dynamic>.from(raw as Map);
            }

            debugPrint('💬 [ChatService] Data parsed: $data');
            
            final message = ChatMessage.fromMap(data, isMe: data['userId'] == userId);
            debugPrint('💬 [ChatService] Mensagem criada: ${message.message} (isMe: ${message.isMe}, isRestaurant: ${message.isRestaurant})');
            
            // Adicionar ao cache
            if (!_messagesCache.containsKey(orderId)) {
              _messagesCache[orderId] = [];
            }
            _messagesCache[orderId]!.add(message);
            
            // ✅ Disparar notificação se NÃO for mensagem própria e for do restaurante
            if (!message.isMe && message.isRestaurant) {
              debugPrint('🔔 [ChatService] Disparando notificação de nova mensagem');
              NotificationService.showChatNotification(
                orderId: orderId,
                senderName: message.user,
                messageText: message.message,
              );
            }
            
            // Notificar callback se existir
            _messageCallbacks[orderId]?.call(message);
          } else {
            debugPrint('⚠️ [ChatService] Evento ignorado ou sem data');
          }
        } catch (e) {
          debugPrint('❌ [ChatService] Erro ao processar evento do Pusher: $e');
        }

        return; // Retorno explícito para satisfazer assinatura
      },
    );

    await _pusher.connect();
    _activeChannels.add(channelName);
    debugPrint('✅ [ChatService] Conectado ao canal $channelName');
  }

  /// Enviar mensagem para o canal
  static Future<void> sendMessage({
    required String orderId,
    required String message,
    required String userName,
    required String userId,
    String? jwtToken,
  }) async {
    try {
      if (message.trim().isEmpty) return;

      debugPrint('📤 [ChatService] Enviando mensagem...');

      // Enviar mensagem através do backend (backend fará o trigger no Pusher)
      final backend = BackendOrderService();
      await backend.sendChatMessage(
        orderId: orderId,
        message: message,
        senderName: userName,
        userId: userId,
        isRestaurant: false,
      );

      debugPrint('✅ [ChatService] Mensagem enviada via backend');
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao enviar mensagem: $e');
      // Notificar todos os callbacks de erro
      for (var callback in _errorCallbacks.values) {
        callback('Erro ao enviar mensagem: $e');
      }
    }
  }

  /// Desconectar do Pusher
  static Future<void> disconnect({String? orderId}) async {
    try {
      if (orderId != null) {
        // Remover apenas callbacks deste pedido
        debugPrint('👋 [ChatService] Removendo callbacks do pedido $orderId');
        _messageCallbacks.remove(orderId);
        _errorCallbacks.remove(orderId);
      } else {
        // Desconectar completamente
        debugPrint('👋 [ChatService] Desconectando completamente...');
        await _pusher.disconnect();
        _initialized = false;
        _messageCallbacks.clear();
        _errorCallbacks.clear();
        _activeChannels.clear();
        debugPrint('✅ [ChatService] Desconectado');
      }
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao desconectar: $e');
    }
  }

  /// Obter mensagens do cache
  static List<ChatMessage> getCachedMessages(String orderId) {
    return _messagesCache[orderId] ?? [];
  }

  /// Adicionar mensagem ao cache (usado ao enviar)
  static void addMessageToCache(String orderId, ChatMessage message) {
    if (!_messagesCache.containsKey(orderId)) {
      _messagesCache[orderId] = [];
    }
    _messagesCache[orderId]!.add(message);
  }

  /// Limpar cache de um pedido
  static void clearCache(String orderId) {
    _messagesCache.remove(orderId);
  }

  /// Verificar se está conectado
  static Future<bool> isConnected() async {
    try {
      // Não há método direto, assume conectado se inicializado
      return _initialized;
    } catch (e) {
      return false;
    }
  }
}
