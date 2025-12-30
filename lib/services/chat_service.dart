import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'backend_order_service.dart';
import 'notification_service.dart';
import 'order_status_pusher_service.dart'; // ✅ Import adicionado

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
  static String? _currentAuthToken; // ✅ Token de autenticação compartilhado
  
  // Callbacks por orderId
  static final Map<String, Function(ChatMessage)> _messageCallbacks = {};
  static final Map<String, Function(String)> _errorCallbacks = {};
  
  // Mensagens em cache por orderId
  static final Map<String, List<ChatMessage>> _messagesCache = {};
  
  // ✅ Nome do restaurante por orderId (para notificações)
  static final Map<String, String> _restaurantNames = {};
  
  // Lista de canais ativos
  static final Set<String> _activeChannels = {};
  
  // ✅ ID do pedido com chat atualmente aberto (para suprimir notificações)
  static String? _activeOrderId;

  /// Configuração do Pusher
  static const String _apiKey = '45b7798e358505a8343e';
  static const String _cluster = 'us2';
  
  /// Chave para SharedPreferences
  static const String _storagePrefix = 'chat_messages_';
  static const Duration _cacheExpiration = Duration(days: 7); // Mensagens duram 7 dias

  /// Definir qual pedido tem chat ativo (para suprimir notificações)
  static void setActiveChatOrder(String? orderId) {
    _activeOrderId = orderId;
    debugPrint('💬 [ChatService] Chat ativo definido: ${orderId ?? "nenhum"}');
  }

  /// Inicializar Pusher e conectar ao canal do pedido
  static Future<void> initialize({
    required String orderId,
    required String userId,
    required Function(ChatMessage) onMessageReceived,
    String? restaurantName, // ✅ Adicionar nome do restaurante
    String? authToken, // ✅ CRÍTICO: Token de autenticação
    Function(String)? onError,
  }) async {
    try {
      debugPrint('💬 [ChatService] Inicializando para pedido $orderId...');
      
      // 🚨 CRÍTICO: Validar authToken ANTES de qualquer operação
      if (authToken == null || authToken.isEmpty) {
        debugPrint('❌ [ChatService] ERRO: authToken ausente ou vazio');
        onError?.call('Token de autenticação não disponível');
        throw Exception('authToken é obrigatório para chat');
      }
      
      // ✅ Salvar token de autenticação
      _currentAuthToken = authToken;
      debugPrint('💬 [ChatService] Token de autenticação salvo e validado');
      
      // Salvar callbacks
      _messageCallbacks[orderId] = onMessageReceived;
      if (onError != null) {
        _errorCallbacks[orderId] = onError;
      }
      
      // ✅ Salvar nome do restaurante para notificações
      if (restaurantName != null) {
        _restaurantNames[orderId] = restaurantName;
      }

      // ✅ Verificar se já foi inicializado por outro serviço
      if (!_initialized && OrderStatusPusherService.isInitialized) {
        debugPrint('💬 [ChatService] Pusher já inicializado pelo OrderStatusPusherService');
        _initialized = true;
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
              
              // ✅ Reconectar automaticamente se desconectado (mas com limite)
              if (currentState == 'DISCONNECTED' && _activeChannels.isNotEmpty) {
                debugPrint('🔄 [ChatService] Tentando reconectar em 3 segundos...');
                Future.delayed(const Duration(seconds: 3), () {
                  if (_initialized && _activeChannels.isNotEmpty) {
                    _pusher.connect().then((_) {
                      debugPrint('✅ [ChatService] Reconectado!');
                    }).catchError((e) {
                      debugPrint('❌ [ChatService] Erro ao reconectar: $e');
                      // Não tentar reconectar indefinidamente
                    });
                  }
                });
              }
              
              // ✅ Evitar loop de reconexão
              if (currentState == 'RECONNECTING') {
                debugPrint('⚠️ [ChatService] Pusher em loop de reconexão, aguardando...');
              }
            },
            onAuthorizer: (String channelName, String socketId, dynamic options) async {
              // ✅ CRÍTICO: Autorizar canais privados com backend
              debugPrint('🔐 [ChatService] Autorizando canal: $channelName');
              
              if (_currentAuthToken != null) {
                try {
                  final response = await _authorizeChannel(
                    channelName: channelName,
                    socketId: socketId,
                    authToken: _currentAuthToken!,
                  );
                  return response;
                } catch (e) {
                  debugPrint('❌ [ChatService] Erro na autorização: $e');
                  return null;
                }
              }
              
              debugPrint('⚠️ [ChatService] Sem token de autenticação');
              return null;
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

  /// Autorizar canal privado no backend
  static Future<Map<String, dynamic>?> _authorizeChannel({
    required String channelName,
    required String socketId,
    required String authToken,
  }) async {
    try {
      debugPrint('🔐 [ChatService] Autorizando $channelName (socketId: $socketId)');
      
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
        final data = json.decode(response.body);
        debugPrint('✅ [ChatService] Canal autorizado: $channelName');
        return data;
      } else {
        debugPrint('❌ [ChatService] Erro na autorização: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao autorizar canal: $e');
      return null;
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
            
            // ✅ Backend pode enviar 'userId' ou 'senderId'
            final messageSenderId = data['userId'] ?? data['senderId'];
            final message = ChatMessage.fromMap(data, isMe: messageSenderId == userId);
            debugPrint('💬 [ChatService] Mensagem criada: ${message.message} (senderId: $messageSenderId, userId: $userId, isMe: ${message.isMe}, isRestaurant: ${message.isRestaurant})');
            
            // Adicionar ao cache (memória + storage)
            if (!_messagesCache.containsKey(orderId)) {
              _messagesCache[orderId] = [];
            }
            _messagesCache[orderId]!.add(message);
            
            // Salvar no storage de forma assíncrona (não bloqueia)
            _saveMessagesToStorage(orderId).catchError((e) {
              debugPrint('⚠️ [ChatService] Erro ao salvar mensagem no storage (continuando): $e');
            });
            
            // ✅ SEMPRE disparar notificação se NÃO for mensagem própria e for do restaurante
            // (Removida supressão quando chat está aberto)
            if (!message.isMe && message.isRestaurant) {
              debugPrint('🔔 [ChatService] Disparando notificação de nova mensagem');
              final restaurantName = _restaurantNames[orderId] ?? 'Restaurante';
              NotificationService.showChatNotification(
                orderId: orderId,
                senderName: restaurantName,
                messageText: message.message,
              );
            }
            
            // Notificar callback se existir (proteger contra chamadas após dispose)
            try {
              _messageCallbacks[orderId]?.call(message);
            } catch (e) {
              debugPrint('⚠️ [ChatService] Erro ao chamar callback (página provavelmente fechada): $e');
              // Não propagar erro - página já foi fechada
            }
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
    required String jwtToken, // ✅ Token obrigatório
  }) async {
    try {
      if (message.trim().isEmpty) return;

      debugPrint('📤 [ChatService] Enviando mensagem...');

      // Enviar mensagem através do backend (backend fará o trigger no Pusher)
      final backend = BackendOrderService();
      await backend.sendChatMessage(
        token: jwtToken, // ✅ Passando token
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
        
        // Unsubscribe do canal específico
        final channelName = 'order-$orderId';
        if (_activeChannels.contains(channelName)) {
          try {
            await _pusher.unsubscribe(channelName: channelName);
            _activeChannels.remove(channelName);
            debugPrint('✅ [ChatService] Unsubscribed do canal $channelName');
          } catch (e) {
            debugPrint('⚠️ [ChatService] Erro ao unsubscribe (ignorando): $e');
            // Ignora erro de unsubscribe, apenas remove do set
            _activeChannels.remove(channelName);
          }
        }
      } else {
        // Desconectar completamente
        debugPrint('👋 [ChatService] Desconectando completamente...');
        
        try {
          // Desconectar sem esperar muito tempo
          await _pusher.disconnect().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              debugPrint('⚠️ [ChatService] Timeout ao desconectar (ignorado)');
            },
          );
        } catch (e) {
          debugPrint('⚠️ [ChatService] Erro ao desconectar (ignorado): $e');
        }
        
        _initialized = false;
        _messageCallbacks.clear();
        _errorCallbacks.clear();
        _activeChannels.clear();
        debugPrint('✅ [ChatService] Desconectado');
      }
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao desconectar (não crítico): $e');
      // Não propaga o erro, apenas loga
    }
  }

  /// Obter mensagens do cache (primeiro tenta memória, depois SharedPreferences)
  static Future<List<ChatMessage>> getCachedMessages(String orderId) async {
    // Se já tem em memória, retorna
    if (_messagesCache.containsKey(orderId) && _messagesCache[orderId]!.isNotEmpty) {
      debugPrint('💾 [ChatService] Retornando ${_messagesCache[orderId]!.length} mensagens da memória');
      return _messagesCache[orderId]!;
    }
    
    // Tentar carregar do SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storagePrefix$orderId';
      final storedData = prefs.getString(key);
      
      if (storedData != null) {
        final Map<String, dynamic> data = json.decode(storedData);
        final DateTime savedAt = DateTime.parse(data['savedAt']);
        
        // Verificar se não expirou
        if (DateTime.now().difference(savedAt) < _cacheExpiration) {
          final List<dynamic> messagesJson = data['messages'];
          final messages = messagesJson.map((m) => ChatMessage.fromMap(m)).toList();
          
          // Salvar em memória para acesso rápido
          _messagesCache[orderId] = messages;
          
          debugPrint('💾 [ChatService] ${messages.length} mensagens carregadas do storage (salvas há ${DateTime.now().difference(savedAt).inHours}h)');
          return messages;
        } else {
          debugPrint('⏰ [ChatService] Mensagens expiradas, limpando storage');
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao carregar mensagens do storage: $e');
    }
    
    return [];
  }

  /// Adicionar mensagem ao cache (memória + SharedPreferences)
  static Future<void> addMessageToCache(String orderId, ChatMessage message) async {
    // Adicionar à memória
    if (!_messagesCache.containsKey(orderId)) {
      _messagesCache[orderId] = [];
    }
    _messagesCache[orderId]!.add(message);
    
    // Salvar no SharedPreferences
    await _saveMessagesToStorage(orderId);
  }
  
  /// Salvar mensagens no SharedPreferences
  static Future<void> _saveMessagesToStorage(String orderId) async {
    try {
      final messages = _messagesCache[orderId];
      if (messages == null || messages.isEmpty) return;
      
      final prefs = await SharedPreferences.getInstance();
      final key = '$_storagePrefix$orderId';
      
      final data = {
        'savedAt': DateTime.now().toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
      };
      
      await prefs.setString(key, json.encode(data));
      debugPrint('💾 [ChatService] ${messages.length} mensagens salvas no storage');
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao salvar mensagens no storage: $e');
    }
  }

  /// Limpar cache de um pedido (memória + SharedPreferences)
  static Future<void> clearCache(String orderId) async {
    _messagesCache.remove(orderId);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_storagePrefix$orderId');
      debugPrint('🗑️ [ChatService] Cache limpo para pedido $orderId');
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao limpar cache: $e');
    }
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
