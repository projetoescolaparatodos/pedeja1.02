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
  static bool _globallyConnected = false; // ✅ Indica se Pusher está conectado globalmente
  static String? _currentAuthToken; // ✅ Token de autenticação compartilhado
  static String? _currentUserId; // ✅ UserId atual
  
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

  /// ✅ NOVO: Inicializar Pusher GLOBALMENTE (chamado no login)
  /// Isso permite receber notificações de chat mesmo com chat fechado
  static Future<void> initializeGlobally({
    required String authToken,
    required String userId,
  }) async {
    try {
      if (_globallyConnected) {
        debugPrint('⚠️ [ChatService] Já conectado globalmente');
        return;
      }

      debugPrint('🌍 [ChatService] ========================================');
      debugPrint('🌍 [ChatService] Inicializando Pusher GLOBALMENTE...');
      debugPrint('🌍 [ChatService] UserId: $userId');
      debugPrint('🌍 [ChatService] ========================================');
      
      // Salvar credenciais
      _currentAuthToken = authToken;
      _currentUserId = userId;
      
      // Inicializar Pusher se ainda não foi
      if (!_initialized) {
        await _initializePusher();
      }
      
      // Conectar ao Pusher
      try {
        await _pusher.connect();
        
        // ✅ Aguardar um tempo fixo para conexão estabelecer (Pusher não tem getConnectionState)
        await Future.delayed(const Duration(seconds: 2));
        
        _globallyConnected = true;
        debugPrint('✅ [ChatService] Pusher conectado globalmente!');
      } catch (e) {
        debugPrint('❌ [ChatService] Erro ao conectar globalmente: $e');
        throw e;
      }
    } catch (e) {
      debugPrint('❌ [ChatService] Erro na inicialização global: $e');
      throw e;
    }
  }

  /// ✅ NOVO: Subscrever em pedidos ativos do usuário (chamado após login)
  static Future<void> subscribeToUserOrders({
    required List<String> orderIds,
  }) async {
    if (!_globallyConnected || _currentUserId == null) {
      debugPrint('⚠️ [ChatService] Não conectado globalmente, pulando subscribe');
      return;
    }

    for (final orderId in orderIds) {
      // Só subscribe se ainda não está ativo
      if (!_activeChannels.contains('order-$orderId')) {
        try {
          debugPrint('📡 [ChatService] Subscrevendo globalmente em order-$orderId');
          await _subscribeToChannel(orderId, _currentUserId!);
          _activeChannels.add('order-$orderId');
        } catch (e) {
          debugPrint('❌ [ChatService] Erro ao subscrever order-$orderId: $e');
        }
      }
    }
  }

  /// ✅ NOVO: Desconectar globalmente (chamado no logout)
  static Future<void> disconnectGlobally() async {
    try {
      debugPrint('🌍 [ChatService] Desconectando globalmente...');
      
      // Desconectar Pusher
      await _pusher.disconnect().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⚠️ [ChatService] Timeout ao desconectar globalmente (ignorado)');
        },
      );
      
      _globallyConnected = false;
      _currentAuthToken = null;
      _currentUserId = null;
      _activeChannels.clear();
      _messageCallbacks.clear();
      _errorCallbacks.clear();
      
      debugPrint('✅ [ChatService] Desconectado globalmente');
    } catch (e) {
      debugPrint('❌ [ChatService] Erro ao desconectar globalmente: $e');
    }
  }

  /// ✅ Extrair inicialização do Pusher para reutilizar
  static Future<void> _initializePusher() async {
    if (_initialized) return;

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
          if (currentState == 'DISCONNECTED' && (_globallyConnected || _activeChannels.isNotEmpty)) {
            debugPrint('🔄 [ChatService] Tentando reconectar em 3 segundos...');
            Future.delayed(const Duration(seconds: 3), () {
              if (_initialized && (_globallyConnected || _activeChannels.isNotEmpty)) {
                _pusher.connect().then((_) {
                  debugPrint('✅ [ChatService] Reconectado!');
                }).catchError((e) {
                  debugPrint('❌ [ChatService] Erro ao reconectar: $e');
                });
              }
            });
          }
          
          if (currentState == 'RECONNECTING') {
            debugPrint('⚠️ [ChatService] Pusher em loop de reconexão, aguardando...');
          }
        },
        onAuthorizer: (String channelName, String socketId, dynamic options) async {
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
      throw e;
    }
  }

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
      debugPrint('💬 [ChatService] ========================================');
      debugPrint('💬 [ChatService] Inicializando para pedido $orderId...');
      debugPrint('💬 [ChatService] UserId: $userId');
      debugPrint('💬 [ChatService] Canais ativos: $_activeChannels');
      debugPrint('💬 [ChatService] Conectado globalmente: $_globallyConnected');
      debugPrint('💬 [ChatService] ========================================');
      
      // 🔴 CRÍTICO: Se já existe callback para este pedido, desconectar primeiro
      if (_activeChannels.contains('order-$orderId')) {
        debugPrint('⚠️ [ChatService] Canal order-$orderId já está ativo, desconectando primeiro...');
        await disconnect(orderId: orderId);
        // Aguardar um pouco para garantir que desconectou
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // 🚨 CRÍTICO: Validar authToken ANTES de qualquer operação
      if (authToken == null || authToken.isEmpty) {
        debugPrint('❌ [ChatService] ERRO: authToken ausente ou vazio');
        onError?.call('Token de autenticação não disponível');
        throw Exception('authToken é obrigatório para chat');
      }
      
      // ✅ Salvar token de autenticação
      _currentAuthToken = authToken;
      _currentUserId = userId;
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

      // ✅ Se já conectado globalmente, apenas subscribe no canal
      if (_globallyConnected) {
        debugPrint('🌍 [ChatService] Usando conexão global existente');
        await _subscribeToChannel(orderId, userId);
        _activeChannels.add('order-$orderId');
        debugPrint('✅ [ChatService] Subscrito ao canal order-$orderId (conexão global)');
        return;
      }

      // ✅ Caso contrário, inicializar Pusher localmente
      if (!_initialized) {
        await _initializePusher();
      }

      // 🚨 CRÍTICO: Subscribe ao canal (registra listeners ANTES da conexão)
      await _subscribeToChannel(orderId, userId);
      
      // Conectar o Pusher e AGUARDAR conexão estar estabelecida
      final channelName = 'order-$orderId';
      try {
        debugPrint('🔌 [ChatService] Conectando ao Pusher...');
        await _pusher.connect();
        
        // ✅ Aguardar um tempo fixo para conexão estabelecer (Pusher não tem getConnectionState)
        await Future.delayed(const Duration(seconds: 2));
        
        _activeChannels.add(channelName);
        debugPrint('✅ [ChatService] Conectado ao Pusher e canal $channelName');
      } catch (e) {
        debugPrint('❌ [ChatService] Erro ao conectar: $e');
        // Limpar estado em caso de erro
        _activeChannels.remove(channelName);
        _messageCallbacks.remove(orderId);
        _errorCallbacks.remove(orderId);
        onError?.call('Erro ao conectar: $e');
        return;
      }
      
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

  /// Conectar a um canal específico (APENAS subscribe, sem connect)
  static Future<void> _subscribeToChannel(String orderId, String userId) async {
    final channelName = 'order-$orderId';
    
    debugPrint('📡 [ChatService] Inscrevendo no canal: $channelName');

    await _pusher.subscribe(
      channelName: channelName,
      onEvent: (dynamic event) {
        try {
          debugPrint('📨 [ChatService] ========== EVENTO RECEBIDO ==========');
          debugPrint('📨 [ChatService] Canal: $channelName');
          debugPrint('📨 [ChatService] Event name: ${event.eventName}');
          debugPrint('📨 [ChatService] Event data type: ${event.data.runtimeType}');
          debugPrint('📨 [ChatService] Event data: ${event.data}');
          debugPrint('📨 [ChatService] ========================================');

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
            debugPrint('💾 [ChatService] Mensagem adicionada ao cache em memória. Total: ${_messagesCache[orderId]!.length}');
            
            // Salvar no storage de forma assíncrona (não bloqueia)
            _saveMessagesToStorage(orderId).then((_) {
              debugPrint('✅ [ChatService] Mensagem salva no SharedPreferences com sucesso');
            }).catchError((e) {
              debugPrint('⚠️ [ChatService] Erro ao salvar mensagem no storage: $e');
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
            if (_messageCallbacks.containsKey(orderId)) {
              try {
                _messageCallbacks[orderId]?.call(message);
                debugPrint('✅ [ChatService] Callback notificado com sucesso');
              } catch (e) {
                debugPrint('⚠️ [ChatService] Erro ao chamar callback (página provavelmente fechada): $e');
                // Não propagar erro - página já foi fechada
              }
            } else {
              debugPrint('⚠️ [ChatService] Callback não existe mais para orderId: $orderId');
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

    debugPrint('✅ [ChatService] Subscrito ao canal $channelName (aguardando conexão)');
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

  /// Carregar mensagens históricas do backend
  static Future<List<ChatMessage>> loadMessagesFromBackend({
    required String orderId,
    required String authToken,
    required String currentUserId,
  }) async {
    try {
      debugPrint('📥 [ChatService] ========================================');
      debugPrint('📥 [ChatService] Carregando mensagens do Firebase...');
      debugPrint('📥 [ChatService] OrderId: $orderId');
      debugPrint('📥 [ChatService] CurrentUserId: $currentUserId');
      debugPrint('📥 [ChatService] Token presente: ${authToken.isNotEmpty}');
      debugPrint('📥 [ChatService] ========================================');
      
      final backend = BackendOrderService();
      final messagesData = await backend.getChatMessages(
        token: authToken,
        orderId: orderId,
        limit: 100, // ✅ Buscar últimas 100 mensagens
      );
      
      debugPrint('📥 [ChatService] Resposta do backend: ${messagesData.length} mensagens');
      
      if (messagesData.isEmpty) {
        debugPrint('💬 [ChatService] Nenhuma mensagem no histórico do Firebase');
        return [];
      }
      
      // ✅ Debug: Mostrar estrutura da primeira mensagem
      if (messagesData.isNotEmpty) {
        debugPrint('📥 [ChatService] Estrutura da primeira mensagem:');
        debugPrint('   Keys: ${messagesData[0].keys.join(', ')}');
        debugPrint('   SenderName: ${messagesData[0]['senderName'] ?? messagesData[0]['user']}');
        debugPrint('   Message: ${messagesData[0]['message']}');
        debugPrint('   Timestamp: ${messagesData[0]['timestamp']}');
        debugPrint('   IsRestaurant: ${messagesData[0]['isRestaurant']}');
        debugPrint('   UserId/SenderId: ${messagesData[0]['userId'] ?? messagesData[0]['senderId']}');
      }
      
      // Converter para ChatMessage
      final messages = messagesData.map((data) {
        // ✅ Tentar múltiplos campos para sender ID
        final messageSenderId = data['userId'] ?? data['senderId'] ?? '';
        final isFromCurrentUser = messageSenderId == currentUserId;
        
        debugPrint('   Convertendo: ${data['senderName']} (isMe: $isFromCurrentUser)');
        
        return ChatMessage.fromMap(data, isMe: isFromCurrentUser);
      }).toList();
      
      // Ordenar por timestamp (mais antigas primeiro)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // ✅ Adicionar ao cache (importante para manter histórico)
      if (!_messagesCache.containsKey(orderId)) {
        _messagesCache[orderId] = [];
      }
      
      // ✅ Não duplicar mensagens já existentes no cache
      final existingKeys = _messagesCache[orderId]!.map((m) => 
        '${m.timestamp.millisecondsSinceEpoch}_${m.message}_${m.user}'
      ).toSet();
      
      for (var msg in messages) {
        final key = '${msg.timestamp.millisecondsSinceEpoch}_${msg.message}_${msg.user}';
        if (!existingKeys.contains(key)) {
          _messagesCache[orderId]!.add(msg);
        }
      }
      
      // Ordenar cache
      _messagesCache[orderId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // Salvar no storage
      await _saveMessagesToStorage(orderId);
      
      debugPrint('✅ [ChatService] ${messages.length} mensagens carregadas do Firebase');
      debugPrint('✅ [ChatService] Cache agora tem ${_messagesCache[orderId]!.length} mensagens');
      return messages;
    } catch (e, stackTrace) {
      debugPrint('❌ [ChatService] Erro ao carregar mensagens do Firebase: $e');
      debugPrint('❌ [ChatService] Stack trace: $stackTrace');
      // Não falhar, apenas retornar lista vazia
      return [];
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
