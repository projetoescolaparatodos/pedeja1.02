import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // ✅ Para Color
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 🔔 Serviço de Notificações Push com Firebase Cloud Messaging
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _fcmToken;
  static String? _authToken;
  static String? _userId; // ✅ ID do usuário (backend)
  static Function(String)? _onNotificationClick;

  /// Getter para o token FCM
  static String? get fcmToken => _fcmToken;

  /// Configurar callback de clique em notificação
  static void setNotificationClickHandler(Function(String) handler) {
    _onNotificationClick = handler;
  }

  /// Inicializar notificações push
  static Future<void> initialize({String? authToken}) async {
    try {
      debugPrint('🔔 [NotificationService] Inicializando...');
      
      if (authToken != null) {
        _authToken = authToken;
      }

      // 🍎 Pedir permissão (iOS)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ [NotificationService] Permissão concedida');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ [NotificationService] Permissão provisória');
      } else {
        debugPrint('❌ [NotificationService] Permissão negada');
        return;
      }

      // 📱 Configurar notificações locais
      await _configureLocalNotifications();

      // 🔑 Obter e registrar token FCM
      await _getFcmToken();

      // 🔄 Atualizar token quando mudar
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 [NotificationService] Token atualizado');
        _fcmToken = newToken;
        _sendTokenToBackend(newToken);
      });

      // 📬 Escutar notificações em foreground
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 🔔 Escutar cliques em notificações (background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

      // 🔔 Verificar se app foi aberto por notificação
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 [NotificationService] App aberto por notificação');
        _handleNotificationClick(initialMessage);
      }

      debugPrint('✅ [NotificationService] Inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ [NotificationService] Erro ao inicializar: $e');
    }
  }

  /// Configurar notificações locais
  static Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 [NotificationService] Notificação local clicada');
        if (details.payload != null) {
          _onNotificationClick?.call(details.payload!);
        }
      },
    );

    // 🤖 Canal de notificação (Android)
    const androidChannel = AndroidNotificationChannel(
      'order_updates',
      'Atualizações de Pedidos',
      description: 'Notificações sobre o status dos seus pedidos',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      ledColor: Color(0xFFFFC107), // ✅ LED amarelo
    );

    const chatChannel = AndroidNotificationChannel(
      'chat_messages',
      'Mensagens do Chat',
      description: 'Notificações de novas mensagens no chat',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      ledColor: Color(0xFFFFC107), // ✅ LED amarelo
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(androidChannel);
    await androidImpl?.createNotificationChannel(chatChannel);

    debugPrint('✅ [NotificationService] Notificações locais configuradas');
  }

  /// Obter token FCM
  static Future<void> _getFcmToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        _fcmToken = token;
        debugPrint('📱 [NotificationService] FCM Token obtido');
        debugPrint('   Token: ${token.substring(0, 20)}...');
        
        // Enviar para backend se tivermos authToken
        if (_authToken != null) {
          await _sendTokenToBackend(token);
        }
      } else {
        debugPrint('⚠️ [NotificationService] Token FCM não disponível');
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Erro ao obter token: $e');
    }
  }

  /// Enviar token FCM para o backend
  static Future<void> _sendTokenToBackend(String token) async {
    if (_authToken == null) {
      debugPrint('⚠️ [NotificationService] Auth token não disponível, pulando envio');
      return;
    }

    try {
      debugPrint('📤 [NotificationService] Enviando token para backend...');

      // ✅ Endpoint correto: POST /api/users/fcm-token (userId vem do JWT)
      final response = await http.post(
        Uri.parse('https://api-pedeja.vercel.app/api/users/fcm-token'),
        headers: {
          'Authorization': 'Bearer $_authToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'fcmToken': token}),
      );

      debugPrint('📡 [NotificationService] Response status: ${response.statusCode}');
      debugPrint('📡 [NotificationService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [NotificationService] Token FCM registrado no backend!');
          debugPrint('   Token: ${token.substring(0, 20)}...');
        }
      } else {
        debugPrint('❌ [NotificationService] Erro ao registrar token:');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ [NotificationService] Erro ao enviar token: $e');
    }
  }

  /// Atualizar auth token e user ID (chamar após login)
  static Future<void> updateAuthToken(String authToken, {String? userId}) async {
    _authToken = authToken;
    if (userId != null) {
      _userId = userId;
    }
    
    // Se já temos FCM token, enviar para backend
    if (_fcmToken != null) {
      await _sendTokenToBackend(_fcmToken!);
    } else {
      // Se não, tentar obter agora
      await _getFcmToken();
    }
  }

  /// Tratar mensagem recebida em foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 [NotificationService] Notificação recebida (foreground)');
    debugPrint('   Título: ${message.notification?.title}');
    debugPrint('   Corpo: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Exibir notificação local
    await _showLocalNotification(message);
  }

  /// Exibir notificação local
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'order_updates',
      'Atualizações de Pedidos',
      channelDescription: 'Notificações sobre o status dos seus pedidos',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification', // ✅ Ícone pequeno branco
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // ✅ Logo grande colorida
      color: Color(0xFFFFC107), // ✅ Amarelo PedeJá (#FFC107)
      colorized: true, // ✅ Aplicar cor de fundo amarela
      showWhen: true, // ✅ Mostrar timestamp
      visibility: NotificationVisibility.public, // ✅ Visibilidade pública
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      message.notification?.title ?? 'Pedido Atualizado',
      message.notification?.body ?? 'Seu pedido foi atualizado',
      details,
      payload: message.data['orderId'],
    );

    debugPrint('✅ [NotificationService] Notificação local exibida');
  }

  /// 💬 Exibir notificação de nova mensagem no chat
  static Future<void> showChatNotification({
    required String orderId,
    required String senderName,
    required String messageText,
  }) async {
    try {
      debugPrint('💬 [NotificationService] Mostrando notificação de chat');
      debugPrint('   Pedido: $orderId');
      debugPrint('   De: $senderName');
      debugPrint('   Mensagem: $messageText');

      // Pegar primeiros 8 caracteres do orderId para exibir
      final shortOrderId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;

      final androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Mensagens do Chat',
        channelDescription: 'Notificações de novas mensagens no chat',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification', // ✅ Ícone pequeno branco
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // ✅ Logo grande colorida
        color: const Color(0xFFFFC107), // ✅ Amarelo PedeJá (#FFC107)
        colorized: true, // ✅ Aplicar cor de fundo amarela
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        orderId.hashCode, // ID único baseado no orderId
        '$senderName',
        messageText,
        details,
        payload: orderId,
      );

      debugPrint('✅ [NotificationService] Notificação de chat exibida');
    } catch (e) {
      debugPrint('❌ [NotificationService] Erro ao exibir notificação de chat: $e');
    }
  }

  /// 📦 Exibir notificação de mudança de status do pedido
  static Future<void> showOrderStatusNotification({
    required String orderId,
    required String title,
    required String body,
    required dynamic status, // OrderStatus enum
  }) async {
    try {
      debugPrint('📦 [NotificationService] Mostrando notificação de status');
      debugPrint('   Pedido: $orderId');
      debugPrint('   Título: $title');
      debugPrint('   Corpo: $body');

      const androidDetails = AndroidNotificationDetails(
        'order_updates',
        'Atualizações de Pedidos',
        channelDescription: 'Notificações sobre o status dos seus pedidos',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification', // ✅ Ícone pequeno branco
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // ✅ Logo grande colorida
        color: Color(0xFFFFC107), // ✅ Amarelo PedeJá (#FFC107)
        colorized: true, // ✅ Aplicar cor de fundo amarela
        showWhen: true, // ✅ Mostrar timestamp
        visibility: NotificationVisibility.public, // ✅ Visibilidade pública
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        orderId.hashCode + 1000, // ID único baseado no orderId (diferente do chat)
        title,
        body,
        details,
        payload: orderId,
      );

      debugPrint('✅ [NotificationService] Notificação de status exibida');
    } catch (e) {
      debugPrint('❌ [NotificationService] Erro ao exibir notificação de status: $e');
    }
  }

  /// Tratar clique em notificação
  static void _handleNotificationClick(RemoteMessage message) {
    debugPrint('🔔 [NotificationService] Notificação clicada');
    
    final orderId = message.data['orderId'];
    if (orderId != null && orderId is String) {
      debugPrint('   Order ID: $orderId');
      _onNotificationClick?.call(orderId);
    }
  }

  /// Limpar token (logout)
  static Future<void> clearToken() async {
    try {
      if (_authToken != null && _fcmToken != null) {
        // Opcional: Enviar request para remover token do backend
        debugPrint('🧹 [NotificationService] Limpando token');
      }
      
      _authToken = null;
      _fcmToken = null;
      
      // Deletar token FCM do dispositivo
      await _messaging.deleteToken();
      
      debugPrint('✅ [NotificationService] Token limpo');
    } catch (e) {
      debugPrint('❌ [NotificationService] Erro ao limpar token: $e');
    }
  }

  /// Obter status da permissão
  static Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Solicitar permissão novamente
  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }
}

/// 🔥 Handler para notificações em background (top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔥 [Background] Notificação recebida');
  debugPrint('   Título: ${message.notification?.title}');
  debugPrint('   Corpo: ${message.notification?.body}');
  debugPrint('   Data: ${message.data}');

  // Se a notificação não tiver payload de exibição (notification),
  // mas tiver dados (data), forçamos a exibição local.
  if (message.notification == null && message.data.isNotEmpty) {
    debugPrint('🔥 [Background] Mensagem de dados pura detectada - exibindo notificação local');
    
    // Inicializar plugin localmente neste isolado
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await localNotifications.initialize(initSettings);

    // Tentar extrair título e corpo dos dados
    final title = message.data['title'] ?? 'Nova Atualização';
    final body = message.data['body'] ?? message.data['message'] ?? 'Você tem uma nova atualização';
    final orderId = message.data['orderId'];

    const androidDetails = AndroidNotificationDetails(
      'order_updates',
      'Atualizações de Pedidos',
      channelDescription: 'Notificações sobre o status dos seus pedidos',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification', // ✅ Ícone pequeno branco
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // ✅ Logo grande colorida
      color: Color(0xFFFFC107), // ✅ Amarelo PedeJá (#FFC107)
      colorized: true, // ✅ Aplicar cor de fundo amarela
      showWhen: true, // ✅ Mostrar timestamp
      visibility: NotificationVisibility.public, // ✅ Visibilidade pública
    );

    const details = NotificationDetails(android: androidDetails);

    await localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: orderId,
    );
  }
}
