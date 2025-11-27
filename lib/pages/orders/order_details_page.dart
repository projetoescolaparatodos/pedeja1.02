import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'dart:async';
import '../../models/order_model.dart';
import '../../services/chat_service.dart';
import '../../state/auth_state.dart';

class OrderDetailsPage extends StatefulWidget {
  final Order order;

  const OrderDetailsPage({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isChatExpanded = false;
  bool _isConnecting = true;
  String? _error;
  bool _isDisconnecting = false;
  
  // ✅ Estado atual do pedido (atualizado em tempo real)
  late Order _currentOrder;
  StreamSubscription<DocumentSnapshot>? _orderSubscription;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    WidgetsBinding.instance.addObserver(this);
    _loadCachedMessages();
    _initializeChat();
    _listenToOrderChanges(); // ✅ Escutar mudanças no pedido
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // ✅ Apenas desconectar se pedido estiver entregue ou cancelado
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // ✅ Usar _currentOrder que é atualizado em tempo real
      if (_currentOrder.status == OrderStatus.delivered || 
          _currentOrder.status == OrderStatus.cancelled) {
        debugPrint('📦 [OrderDetailsPage] Pedido finalizado, desconectando chat');
        _safeDisconnect();
      } else {
        debugPrint('📦 [OrderDetailsPage] Pedido ativo, mantendo conexão para notificações');
      }
    }
    
    // ✅ Reconectar quando o app volta ao foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [OrderDetailsPage] App retomado, reconectando chat...');
      _initializeChat();
    }
  }

  Future<void> _loadCachedMessages() async {
    // Carregar mensagens do cache (agora é assíncrono)
    final cachedMessages = await ChatService.getCachedMessages(widget.order.id);
    if (cachedMessages.isNotEmpty) {
      setState(() {
        _messages.addAll(cachedMessages);
      });
      debugPrint('💬 [OrderDetailsPage] ${cachedMessages.length} mensagens carregadas do cache');
    }
  }

  /// ✅ Escutar mudanças no status do pedido em tempo real
  void _listenToOrderChanges() {
    final authState = Provider.of<AuthState>(context, listen: false);
    if (authState.currentUser == null) return;

    debugPrint('📡 [OrderDetailsPage] Iniciando listener de mudanças do pedido ${widget.order.id}');

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.order.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        try {
          final updatedOrder = Order.fromFirestore(
            snapshot.data() as Map<String, dynamic>,
            snapshot.id,
          );
          
          // ✅ Detectar mudança de status
          if (updatedOrder.status != _currentOrder.status) {
            debugPrint('🔄 [OrderDetailsPage] Status mudou: ${_currentOrder.status.label} → ${updatedOrder.status.label}');
            
            setState(() {
              _currentOrder = updatedOrder;
            });
            
            // ✅ Se pedido foi entregue/cancelado, desconectar chat
            if (updatedOrder.status == OrderStatus.delivered || 
                updatedOrder.status == OrderStatus.cancelled) {
              debugPrint('📦 [OrderDetailsPage] Pedido finalizado, desconectando chat');
              _safeDisconnect();
            }
          } else {
            // Atualizar outros campos sem mudar status
            setState(() {
              _currentOrder = updatedOrder;
            });
          }
        } catch (e) {
          debugPrint('❌ [OrderDetailsPage] Erro ao processar atualização: $e');
        }
      }
    }, onError: (error) {
      debugPrint('❌ [OrderDetailsPage] Erro no listener: $error');
    });
  }

  Future<void> _initializeChat() async {
    // ⚠️ Temporariamente desabilitado na web devido a problema com Pusher JS
    if (kIsWeb) {
      setState(() {
        _error = 'Chat disponível apenas no app mobile (em breve na web)';
        _isConnecting = false;
      });
      return;
    }

    final authState = Provider.of<AuthState>(context, listen: false);
    
    if (authState.currentUser == null) {
      setState(() {
        _error = 'Usuário não autenticado';
        _isConnecting = false;
      });
      return;
    }

    try {
      await ChatService.initialize(
        orderId: widget.order.id,
        userId: authState.currentUser!.uid,
        restaurantName: widget.order.restaurantName, // ✅ Passar nome do restaurante
        onMessageReceived: (message) {
          // ✅ Evitar duplicatas: verificar se já existe mensagem similar recente
          final isDuplicate = _messages.any((m) => 
            m.message == message.message && 
            m.user == message.user &&
            m.timestamp.difference(message.timestamp).abs().inSeconds < 5
          );
          
          if (!isDuplicate) {
            setState(() {
              _messages.add(message);
            });
            _scrollToBottom();
          } else {
            debugPrint('⚠️ [OrderDetailsPage] Mensagem duplicada ignorada');
          }
        },
        onError: (error) {
          setState(() {
            _error = error;
          });
        },
      );

      setState(() {
        _isConnecting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao conectar ao chat: $e';
        _isConnecting = false;
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final authState = Provider.of<AuthState>(context, listen: false);
    final userName = authState.userData?['name'] ?? 'Cliente';
    final userId = authState.currentUser?.uid ?? '';

    final message = _messageController.text;
    
    // ✅ Adicionar mensagem localmente IMEDIATAMENTE (feedback visual)
    final localMessage = ChatMessage(
      user: userName,
      message: message,
      timestamp: DateTime.now(),
      isMe: true,
      isRestaurant: false,
    );
    
    setState(() {
      _messages.add(localMessage);
    });
    _messageController.clear();
    _scrollToBottom();
    
    // Enviar via backend → Pusher pode devolver outra cópia
    ChatService.sendMessage(
      orderId: widget.order.id,
      message: message,
      userName: userName,
      userId: userId,
      jwtToken: authState.jwtToken ?? '',
    ).catchError((error) {
      debugPrint('❌ [OrderDetailsPage] Erro ao enviar mensagem: $error');
      // Mostrar erro ao usuário
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar mensagem: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    // ✅ Cancelar listener do Firestore
    _orderSubscription?.cancel();
    
    // ✅ NÃO desconectar o chat ao sair da página
    // O chat só deve desconectar quando:
    // 1. Pedido for entregue/cancelado
    // 2. Usuário fizer logout
    debugPrint('📦 [OrderDetailsPage] Saindo da página, mantendo chat conectado para notificações');
    
    super.dispose();
  }
  
  /// Desconectar de forma segura sem propagar exceções
  void _safeDisconnect() {
    if (_isDisconnecting) return;
    _isDisconnecting = true;
    
    // Usar Future.delayed para evitar erro durante dispose
    Future.delayed(Duration.zero, () async {
      try {
        await ChatService.disconnect(orderId: widget.order.id);
      } catch (e) {
        debugPrint('⚠️ [OrderDetailsPage] Erro ao desconectar (ignorado): $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF022E28),
      appBar: AppBar(
        title: Text(
          'Pedido #${widget.order.id.substring(0, 8)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF74241F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Timeline
            _buildStatusTimeline(),

            const SizedBox(height: 16),

            // Restaurant Info
            _buildRestaurantInfo(),

            const SizedBox(height: 16),

            // Customer Info (se disponível)
            if (widget.order.userName != null || widget.order.userPhone != null)
              _buildCustomerInfo(),

            if (widget.order.userName != null || widget.order.userPhone != null)
              const SizedBox(height: 16),

            // Items List
            _buildItemsList(),

            const SizedBox(height: 16),

            // Delivery Address
            _buildDeliveryAddress(),

            const SizedBox(height: 16),

            // Payment Info
            _buildPaymentInfo(),

            const SizedBox(height: 16),

            // Order Summary
            _buildOrderSummary(),

            const SizedBox(height: 16),

            // Chat Section
            _buildChatSection(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status do Pedido',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildStatusStep(
            icon: Icons.receipt_long,
            title: 'Pedido Recebido',
            isActive: _currentOrder.status == OrderStatus.pending,
            isCompleted: _currentOrder.status == OrderStatus.accepted ||
                _currentOrder.status == OrderStatus.preparing ||
                _currentOrder.status == OrderStatus.ready ||
                _currentOrder.status == OrderStatus.awaitingBatch ||
                _currentOrder.status == OrderStatus.inBatch ||
                _currentOrder.status == OrderStatus.outForDelivery ||
                _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusConnector(
            isCompleted: _currentOrder.status == OrderStatus.accepted ||
                _currentOrder.status == OrderStatus.preparing ||
                _currentOrder.status == OrderStatus.ready ||
                _currentOrder.status == OrderStatus.awaitingBatch ||
                _currentOrder.status == OrderStatus.inBatch ||
                _currentOrder.status == OrderStatus.outForDelivery ||
                _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusStep(
            icon: Icons.restaurant,
            title: 'Preparando',
            isActive: _currentOrder.status == OrderStatus.accepted ||
                _currentOrder.status == OrderStatus.preparing,
            isCompleted: _currentOrder.status == OrderStatus.ready ||
                _currentOrder.status == OrderStatus.awaitingBatch ||
                _currentOrder.status == OrderStatus.inBatch ||
                _currentOrder.status == OrderStatus.outForDelivery ||
                _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusConnector(
            isCompleted: _currentOrder.status == OrderStatus.ready ||
                _currentOrder.status == OrderStatus.awaitingBatch ||
                _currentOrder.status == OrderStatus.inBatch ||
                _currentOrder.status == OrderStatus.outForDelivery ||
                _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusStep(
            icon: Icons.check_circle,
            title: 'Pronto',
            isActive: _currentOrder.status == OrderStatus.ready ||
                _currentOrder.status == OrderStatus.awaitingBatch,
            isCompleted: _currentOrder.status == OrderStatus.inBatch ||
                _currentOrder.status == OrderStatus.outForDelivery ||
                _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusConnector(
            isCompleted: _currentOrder.status == OrderStatus.inBatch ||
                _currentOrder.status == OrderStatus.outForDelivery ||
                _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusStep(
            icon: Icons.delivery_dining,
            title: 'A Caminho',
            isActive: _currentOrder.status == OrderStatus.inBatch ||
                _currentOrder.status == OrderStatus.outForDelivery,
            isCompleted: _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusConnector(
            isCompleted: _currentOrder.status == OrderStatus.delivered,
          ),
          _buildStatusStep(
            icon: Icons.home,
            title: 'Entregue',
            isActive: _currentOrder.status == OrderStatus.delivered,
            isCompleted: _currentOrder.status == OrderStatus.delivered,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStep({
    required IconData icon,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color color;
    if (isCompleted) {
      color = Colors.green;
    } else if (isActive) {
      color = const Color(0xFFE39110);
    } else {
      color = Colors.white30;
    }

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? color.withValues(alpha: 0.2)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            color: isCompleted || isActive ? Colors.white : Colors.white54,
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusConnector({required bool isCompleted}) {
    return Container(
      margin: const EdgeInsets.only(left: 19, top: 4, bottom: 4),
      width: 2,
      height: 20,
      color: isCompleted ? Colors.green : Colors.white30,
    );
  }

  Widget _buildRestaurantInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE39110),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.store,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.order.restaurantName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(widget.order.createdAt),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFE39110),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.order.userName != null) ...[
                  const Text(
                    'Cliente',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.order.userName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (widget.order.userPhone != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        color: Color(0xFFE39110),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.order.userPhone!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_cart,
                  color: Color(0xFFE39110),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Itens (${widget.order.items.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: widget.order.items.length,
            separatorBuilder: (context, index) => const Divider(
              color: Colors.white24,
              height: 24,
            ),
            itemBuilder: (context, index) {
              final item = widget.order.items[index];
              return _buildOrderItem(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quantity badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE39110),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        
        // Item info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Mostrar apenas os nomes dos adicionais, não os preços
              if (item.addons.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...item.addons.map((addon) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '+ ${addon.name}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                )),
              ],
              // Mostrar preço base + adicionais
              const SizedBox(height: 4),
              Text(
                'R\$ ${item.price.toStringAsFixed(2)}${item.addons.isNotEmpty ? ' + ${item.addons.map((a) => a.price).reduce((a, b) => a + b).toStringAsFixed(2)}' : ''}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        
        // Price (total do item com quantidade)
        Text(
          'R\$ ${item.totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Color(0xFFE39110),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryAddress() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.location_on,
                color: Color(0xFFE39110),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Endereço de Entrega',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.order.deliveryAddress,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.payment,
                color: Color(0xFFE39110),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Pagamento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getPaymentStatusColor(widget.order.paymentStatus),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.order.paymentStatus.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (widget.order.payment != null) ...[
            const SizedBox(height: 8),
            if (widget.order.payment!.method != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Método:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _translatePaymentMethod(widget.order.payment!.method!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            // ✅ Mostrar informação de troco se necessário
            if (widget.order.payment!.needsChange == true) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Troco para:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'R\$ ${widget.order.payment!.changeFor?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Troco:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'R\$ ${widget.order.payment!.changeAmount?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      color: Color(0xFFE39110),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    // Calcular subtotal dos itens se não vier do backend
    final subtotal = widget.order.subtotal ?? 
                     widget.order.items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    final deliveryFee = widget.order.deliveryFee ?? 0;
    final discount = widget.order.discount ?? 0;
    final serviceFee = widget.order.serviceFee ?? 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Subtotal dos itens
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              Text(
                'R\$ ${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          
          // Taxa de entrega
          if (deliveryFee > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Taxa de entrega',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'R\$ ${deliveryFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
          
          // Taxa de serviço
          if (serviceFee > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Taxa de serviço',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'R\$ ${serviceFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
          
          // Desconto
          if (discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Desconto',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '- R\$ ${discount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'R\$ ${widget.order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFE39110),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.approved:
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.pending:
        return const Color(0xFFE39110);
      case PaymentStatus.rejected:
      case PaymentStatus.cancelled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoje às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Ontem às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 💬 Seção de Chat com o Vendedor
  Widget _buildChatSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isChatExpanded = !_isChatExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: _isChatExpanded ? Radius.zero : const Radius.circular(14),
                  bottomRight: _isChatExpanded ? Radius.zero : const Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble,
                    color: Color(0xFFE39110),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chat com o Vendedor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isChatExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // Chat Content
          if (_isChatExpanded) ...[
            // Connecting State
            if (_isConnecting)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFE39110),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Conectando ao chat...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error State
            if (_error != null && !_isConnecting)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

            // Chat Messages
            if (!_isConnecting && _error == null) ...[
              // Messages List
              Container(
                height: 300,
                padding: const EdgeInsets.all(12),
                child: _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma mensagem ainda.\nInicie a conversa!',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildChatBubble(_messages[index]);
                        },
                      ),
              ),

              const Divider(color: Colors.white24, height: 1),

              // Message Input
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Digite sua mensagem...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE39110),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 💬 Bolha de mensagem individual
  Widget _buildChatBubble(ChatMessage message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: message.isMe
              ? const Color(0xFFE39110)
              : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: message.isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: message.isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isMe)
              Text(
                message.user,
                style: const TextStyle(
                  color: Color(0xFFE39110),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            if (!message.isMe) const SizedBox(height: 4),
            Text(
              message.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: message.isMe ? Colors.white70 : Colors.white54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Traduzir método de pagamento
  String _translatePaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Dinheiro';
      case 'credit_card':
      case 'credit':
        return 'Cartão de Crédito';
      case 'debit_card':
      case 'debit':
        return 'Cartão de Débito';
      case 'pix':
        return 'PIX';
      case 'mercado_pago':
        return 'Mercado Pago';
      default:
        return method.toUpperCase();
    }
  }
}

