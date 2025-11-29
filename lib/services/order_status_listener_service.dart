import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart' as models;
import 'notification_service.dart';

/// 👂 Serviço para escutar mudanças de status dos pedidos e enviar notificações
class OrderStatusListenerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Mapa de listeners ativos (orderId -> StreamSubscription)
  static final Map<String, StreamSubscription<DocumentSnapshot>> _listeners = {};
  
  // Mapa do último status conhecido de cada pedido
  static final Map<String, models.OrderStatus> _lastKnownStatus = {};
  
  // Listener de todos os pedidos do usuário
  static StreamSubscription<QuerySnapshot>? _userOrdersListener;

  /// Iniciar monitoramento de todos os pedidos do usuário
  static Future<void> startListeningToUserOrders() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ [OrderStatusListener] Usuário não autenticado');
        return;
      }

      debugPrint('👂 [OrderStatusListener] Iniciando monitoramento de pedidos do usuário ${user.uid}');

      // Cancelar listener anterior se existir
      await _userOrdersListener?.cancel();

      // Escutar mudanças em todos os pedidos do usuário
      _userOrdersListener = _firestore
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen(
            (snapshot) {
              debugPrint('📦 [OrderStatusListener] Mudanças detectadas em ${snapshot.docChanges.length} pedidos');
              
              for (var change in snapshot.docChanges) {
                if (change.type == DocumentChangeType.modified) {
                  _handleOrderChange(change.doc);
                }
                // Também monitorar novos pedidos
                else if (change.type == DocumentChangeType.added) {
                  final order = models.Order.fromFirestore(change.doc.data()!, change.doc.id);
                  _lastKnownStatus[order.id] = order.status;
                  debugPrint('📦 [OrderStatusListener] Novo pedido detectado: ${order.id} - Status: ${order.status.label}');
                }
              }
            },
            onError: (error) {
              debugPrint('❌ [OrderStatusListener] Erro no listener: $error');
            },
          );

      debugPrint('✅ [OrderStatusListener] Monitoramento iniciado');
    } catch (e) {
      debugPrint('❌ [OrderStatusListener] Erro ao iniciar monitoramento: $e');
    }
  }

  /// Tratar mudança de pedido
  static void _handleOrderChange(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final order = models.Order.fromFirestore(data, doc.id);
      final orderId = order.id;
      final newStatus = order.status;
      
      // Verificar se o status mudou
      final lastStatus = _lastKnownStatus[orderId];
      
      if (lastStatus != null && lastStatus != newStatus) {
        debugPrint('🔄 [OrderStatusListener] Status do pedido $orderId mudou: ${lastStatus.label} → ${newStatus.label}');
        
        // Enviar notificação de mudança de status
        _sendStatusChangeNotification(order, lastStatus, newStatus);
      }
      
      // Atualizar último status conhecido
      _lastKnownStatus[orderId] = newStatus;
    } catch (e) {
      debugPrint('❌ [OrderStatusListener] Erro ao tratar mudança: $e');
    }
  }

  /// Enviar notificação de mudança de status
  static void _sendStatusChangeNotification(
    models.Order order,
    models.OrderStatus oldStatus,
    models.OrderStatus newStatus,
  ) {
    // ✅ REMOVIDO: Não dispara notificação local aqui para evitar duplicatas
    // O backend envia via FCM quando detecta mudança no Firestore
    // Este listener serve APENAS para atualizar a UI em tempo real
    
    debugPrint('📦 [OrderStatusListener] Status mudou: ${oldStatus.label} → ${newStatus.label}');
    debugPrint('📦 [OrderStatusListener] Notificação será enviada pelo backend via FCM');
    
    // Nota: Se precisar atualizar UI, adicione callback aqui
  }

  /// Iniciar monitoramento de um pedido específico
  static Future<void> startListeningToOrder(String orderId) async {
    try {
      debugPrint('👂 [OrderStatusListener] Iniciando monitoramento do pedido $orderId');

      // Cancelar listener anterior se existir
      await _listeners[orderId]?.cancel();

      // Escutar mudanças no pedido
      _listeners[orderId] = _firestore
          .collection('orders')
          .doc(orderId)
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists) {
                _handleOrderChange(snapshot);
              }
            },
            onError: (error) {
              debugPrint('❌ [OrderStatusListener] Erro no listener do pedido $orderId: $error');
            },
          );

      debugPrint('✅ [OrderStatusListener] Monitoramento do pedido $orderId iniciado');
    } catch (e) {
      debugPrint('❌ [OrderStatusListener] Erro ao monitorar pedido $orderId: $e');
    }
  }

  /// Parar monitoramento de um pedido específico
  static Future<void> stopListeningToOrder(String orderId) async {
    await _listeners[orderId]?.cancel();
    _listeners.remove(orderId);
    _lastKnownStatus.remove(orderId);
    debugPrint('👋 [OrderStatusListener] Parou de monitorar pedido $orderId');
  }

  /// Parar monitoramento de todos os pedidos
  static Future<void> stopListeningToAllOrders() async {
    await _userOrdersListener?.cancel();
    _userOrdersListener = null;
    
    for (var listener in _listeners.values) {
      await listener.cancel();
    }
    
    _listeners.clear();
    _lastKnownStatus.clear();
    
    debugPrint('👋 [OrderStatusListener] Parou de monitorar todos os pedidos');
  }

  /// Limpar cache de status conhecidos (útil no logout)
  static void clearCache() {
    _lastKnownStatus.clear();
    debugPrint('🧹 [OrderStatusListener] Cache limpo');
  }
}
