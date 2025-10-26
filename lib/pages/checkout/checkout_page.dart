import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart' as models;
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../state/cart_state.dart';
import '../../state/user_state.dart';
import 'payment_status_page.dart';

/// Tela de checkout com pagamento Mercado Pago
class CheckoutPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const CheckoutPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final OrderService _orderService = OrderService();
  final PaymentService _paymentService = PaymentService();
  
  bool _isLoading = false;
  String? _errorMessage;

  /// Finaliza o pedido e cria pagamento
  Future<void> _finalizarPagamento() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cartState = context.read<CartState>();
      final userState = context.read<UserState>();

      // 1. Validar carrinho
      if (cartState.items.isEmpty) {
        throw Exception('Carrinho vazio');
      }

      // 2. Validar endereço
      final userData = userState.userData;
      if (userData == null) {
        throw Exception('Dados do usuário não encontrados');
      }

      final address = userData['address'];
      if (address == null) {
        throw Exception('Endereço não cadastrado');
      }

      // Formatar endereço
      final complement = address['complement'] as String?;
      final deliveryAddress = '${address['street']}, ${address['number']}'
          '${complement != null && complement.isNotEmpty ? ' - $complement' : ''}'
          ' - ${address['neighborhood']}, ${address['city']} - ${address['state']}'
          ' CEP: ${address['zipCode']}';

      debugPrint('📦 Criando pedido...');

      // 3. Converter itens do carrinho para OrderItem
      final orderItems = cartState.items.map((cartItem) {
        return models.OrderItem(
          productId: cartItem.id,
          name: cartItem.name,
          price: cartItem.price,
          quantity: cartItem.quantity,
          imageUrl: cartItem.imageUrl ?? '',
          addons: cartItem.addons
              .map((addon) => models.OrderItemAddon(
                    name: addon['name'] as String? ?? '',
                    price: (addon['price'] as num? ?? 0).toDouble(),
                  ))
              .toList(),
        );
      }).toList();

      // 4. Criar pedido no Firebase
      final orderId = await _orderService.createOrder(
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
        items: orderItems,
        total: cartState.total,
        deliveryAddress: deliveryAddress,
      );

      debugPrint('✅ Pedido criado: $orderId');

      // 5. Criar pagamento com split
      debugPrint('💳 Criando pagamento com split...');
      
      final paymentData = await _paymentService.createPaymentWithSplit(
        orderId: orderId,
        paymentMethod: 'mercadopago',
      );

      // 6. Verificar resposta
      if (!paymentData['success']) {
        throw Exception(paymentData['error'] ?? 'Erro ao criar pagamento');
      }

      final payment = paymentData['payment'];
      if (payment == null) {
        throw Exception('Dados do pagamento não retornados');
      }

      final checkoutUrl = payment['initPoint'];
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('URL do checkout não encontrada');
      }

      debugPrint('🌐 Abrindo checkout: $checkoutUrl');

      // 7. Abrir checkout do Mercado Pago
      final uri = Uri.parse(checkoutUrl);

      if (await canLaunchUrl(uri)) {
        // Abrir no navegador externo
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        // 8. Limpar carrinho
        cartState.clear();

        // 9. Navegar para tela de status
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentStatusPage(orderId: orderId),
            ),
          );
        }
      } else {
        throw Exception('Não foi possível abrir o checkout do Mercado Pago');
      }
    } catch (e) {
      debugPrint('❌ Erro: $e');

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $_errorMessage'),
            backgroundColor: const Color(0xFF74241F),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartState>();

    return Scaffold(
      backgroundColor: const Color(0xFF022E28),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D3B3B),
        title: const Text(
          'Finalizar Pedido',
          style: TextStyle(color: Color(0xFFE39110)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE39110)),
      ),
      body: Column(
        children: [
          // Resumo do pedido
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurante
                  _buildSection(
                    title: 'Restaurante',
                    child: Text(
                      widget.restaurantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Itens
                  _buildSection(
                    title: 'Itens do Pedido',
                    child: Column(
                      children: cartState.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text(
                                '${item.quantity}x',
                                style: const TextStyle(
                                  color: Color(0xFFE39110),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              Text(
                                'R\$ ${item.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B3B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE39110),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            color: Color(0xFFE39110),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF74241F).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF74241F),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFF74241F),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Botão de pagamento
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D3B3B),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _finalizarPagamento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE39110),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Pagar com Mercado Pago',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFE39110),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
