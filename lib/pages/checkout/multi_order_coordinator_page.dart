import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/cart_state.dart';
import '../../models/restaurant_model.dart';
import 'payment_method_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Página coordenadora de múltiplos pedidos
/// Orienta o usuário a processar cada restaurante individualmente
class MultiOrderCoordinatorPage extends StatefulWidget {
  final Map<String, List<dynamic>> itemsByRestaurant;

  const MultiOrderCoordinatorPage({
    super.key,
    required this.itemsByRestaurant,
  });

  @override
  State<MultiOrderCoordinatorPage> createState() => _MultiOrderCoordinatorPageState();
}

class _MultiOrderCoordinatorPageState extends State<MultiOrderCoordinatorPage> {
  final Map<String, String> _orderStatus = {}; // restaurantId → 'pending' | 'processing' | 'completed' | 'error'
  final Map<String, RestaurantModel?> _restaurants = {};
  bool _isLoadingRestaurants = true;

  @override
  void initState() {
    super.initState();
    // Inicializar todos como pendentes
    for (var restaurantId in widget.itemsByRestaurant.keys) {
      _orderStatus[restaurantId] = 'pending';
    }
    _loadRestaurants();
  }

  /// Busca dados dos restaurantes na API
  Future<void> _loadRestaurants() async {
    for (var restaurantId in widget.itemsByRestaurant.keys) {
      try {
        final response = await http.get(
          Uri.parse('https://api-pedeja.vercel.app/api/restaurants/$restaurantId'),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _restaurants[restaurantId] = RestaurantModel.fromJson(data);
        }
      } catch (e) {
        debugPrint('Erro ao carregar restaurante $restaurantId: $e');
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoadingRestaurants = false;
      });
    }
  }

  /// Navega para PaymentMethodPage e aguarda resultado
  Future<void> _processOrder(String restaurantId) async {
    final restaurant = _restaurants[restaurantId];
    final restaurantName = restaurant?.name ?? 'Restaurante';
    final items = widget.itemsByRestaurant[restaurantId] ?? [];
    
    setState(() {
      _orderStatus[restaurantId] = 'processing';
    });

    // Navegar para PaymentMethodPage existente com itens específicos
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodPage(
          restaurantId: restaurantId,
          restaurantName: restaurantName,
          specificItems: items, // ✅ Passar apenas itens deste restaurante
        ),
      ),
    );

    // Atualizar status com base no resultado
    if (!mounted) return;

    setState(() {
      if (result != null && result['success'] == true) {
        _orderStatus[restaurantId] = 'completed';
      } else if (result != null && result['success'] == false) {
        _orderStatus[restaurantId] = 'error';
      } else {
        // Usuário voltou sem finalizar
        _orderStatus[restaurantId] = 'pending';
      }
    });

    // Verificar se todos foram concluídos com sucesso
    _checkIfAllCompleted();
  }

  /// Verifica se todos os pedidos foram finalizados
  void _checkIfAllCompleted() {
    final allCompleted = _orderStatus.values.every((status) => status == 'completed');
    
    if (allCompleted) {
      // ✅ Carrinho já foi limpo gradualmente pelo PaymentMethodPage
      // Não precisa chamar clear() aqui
      
      // Voltar para home
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Todos os pedidos foram processados com sucesso!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Voltar para home após 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'processing':
        return Icons.sync;
      case 'error':
        return Icons.error;
      default:
        return Icons.pending;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Concluído';
      case 'processing':
        return 'Processando...';
      case 'error':
        return 'Erro - Tentar novamente';
      default:
        return 'Aguardando';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartState>();
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // Avisar que há pedidos pendentes
        final hasPending = _orderStatus.values.any((s) => s == 'pending' || s == 'processing');
        
        if (hasPending) {
          final shouldLeave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A4747),
              title: const Text(
                '⚠️ Pedidos Pendentes',
                style: TextStyle(color: Color(0xFFE39110)),
              ),
              content: const Text(
                'Você ainda tem pedidos não processados. Deseja realmente sair?',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Continuar Aqui',
                    style: TextStyle(color: Color(0xFFE39110)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Sair',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          
          if (shouldLeave ?? false) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D3B3B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A4747),
          title: const Text(
            'Finalizar Pedidos',
            style: TextStyle(color: Color(0xFFE39110)),
          ),
          iconTheme: const IconThemeData(color: Color(0xFFE39110)),
        ),
        body: _isLoadingRestaurants
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE39110),
                ),
              )
            : Column(
                children: [
                  // Banner informativo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A4747),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE39110),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFFE39110),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Múltiplos Restaurantes',
                              style: TextStyle(
                                color: Color(0xFFE39110),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Você tem itens de ${widget.itemsByRestaurant.length} ${widget.itemsByRestaurant.length == 1 ? 'estabelecimento' : 'estabelecimentos'} diferentes no carrinho.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '📦 Cada pedido será processado individualmente.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '🔄 Após finalizar o pedido 1, você voltará aqui para processar o pedido 2.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '✅ Mantenha esta página aberta até concluir todos os pedidos.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de restaurantes
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.itemsByRestaurant.length,
                      itemBuilder: (context, index) {
                        final restaurantId = widget.itemsByRestaurant.keys.elementAt(index);
                        final items = widget.itemsByRestaurant[restaurantId]!;
                        final restaurant = _restaurants[restaurantId];
                        final status = _orderStatus[restaurantId] ?? 'pending';
                        
                        final restaurantName = restaurant?.name ?? 
                                               items.first.restaurantName ?? 
                                               'Restaurante';
                        
                        final subtotal = items.fold<double>(
                          0, 
                          (sum, item) => sum + item.totalPrice,
                        );

                        return Card(
                          color: const Color(0xFF1A4747),
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _getStatusColor(status),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header com nome e status
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pedido ${index + 1}',
                                            style: const TextStyle(
                                              color: Color(0xFFE39110),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            restaurantName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      _getStatusIcon(status),
                                      color: _getStatusColor(status),
                                      size: 32,
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Status text
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _getStatusColor(status),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _getStatusText(status),
                                    style: TextStyle(
                                      color: _getStatusColor(status),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white24),
                                const SizedBox(height: 8),
                                
                                // Itens
                                Text(
                                  '${items.length} ${items.length == 1 ? 'item' : 'itens'}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Subtotal
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Subtotal:',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'R\$ ${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFFE39110),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Botão de ação
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: (status == 'pending' || status == 'error')
                                        ? () => _processOrder(restaurantId)
                                        : null,
                                    icon: Icon(
                                      status == 'error' 
                                          ? Icons.refresh 
                                          : Icons.payment,
                                    ),
                                    label: Text(
                                      status == 'completed'
                                          ? '✅ Pedido Finalizado'
                                          : status == 'processing'
                                              ? 'Processando...'
                                              : status == 'error'
                                                  ? 'Tentar Novamente'
                                                  : 'Processar Pedido',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: status == 'error'
                                          ? Colors.orange
                                          : const Color(0xFFE39110),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      disabledBackgroundColor: Colors.grey,
                                      disabledForegroundColor: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Total geral
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A4747),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Geral',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '(todos os restaurantes)',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'R\$ ${cartState.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFFE39110),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
