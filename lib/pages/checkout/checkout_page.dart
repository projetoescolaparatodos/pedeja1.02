import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import 'payment_method_page.dart';

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
      final authState = context.read<AuthState>();

      // 1. Validar carrinho
      if (cartState.items.isEmpty) {
        throw Exception('Carrinho vazio');
      }

      // 2. Validar dados do usuário (usa AuthState em vez de UserState)
      final userData = authState.userData;
      
      debugPrint('🔍 [CHECKOUT] userData completo: $userData');
      
      if (userData == null) {
        throw Exception('Dados do usuário não encontrados. Faça login novamente.');
      }

      // Tentar obter endereço do campo 'address' ou do array 'addresses'
      var address = userData['address'];
      
      debugPrint('🔍 [CHECKOUT] address type: ${address?.runtimeType}');
      debugPrint('🔍 [CHECKOUT] address value: $address');
      
      // Se address for String (formato antigo), vamos usar como deliveryAddress direto
      String deliveryAddress;
      
      if (address == null) {
        // Tentar usar o array de endereços
        final addresses = userData['addresses'];
        if (addresses is List && addresses.isNotEmpty) {
          deliveryAddress = addresses[0].toString();
          debugPrint('📍 [CHECKOUT] Usando endereço do array addresses: $deliveryAddress');
        } else {
          throw Exception('Endereço não cadastrado');
        }
      } else if (address is String) {
        // Usar o endereço como String formatada
        deliveryAddress = address;
        debugPrint('📍 [CHECKOUT] Usando endereço como String: $deliveryAddress');
      } else if (address is Map) {
        // Formato novo (Map com campos separados)
        final addressMap = Map<String, dynamic>.from(address);
        final street = addressMap['street']?.toString() ?? '';
        final number = addressMap['number']?.toString() ?? '';
        final complement = addressMap['complement']?.toString() ?? '';
        final neighborhood = addressMap['neighborhood']?.toString() ?? '';
        final city = addressMap['city']?.toString() ?? '';
        final state = addressMap['state']?.toString() ?? '';
        final zipCode = addressMap['zipCode']?.toString() ?? '';
        
        deliveryAddress = '$street, $number'
            '${complement.isNotEmpty ? ' - $complement' : ''}'
            ' - $neighborhood, $city - $state'
            ' CEP: $zipCode';
        
        debugPrint('📍 [CHECKOUT] Endereço formatado do Map: $deliveryAddress');
      } else {
        debugPrint('❌ [CHECKOUT] Tipo de address desconhecido: ${address.runtimeType}');
        throw Exception('Formato de endereço inválido');
      }

      debugPrint('📦 Navegando para seleção de método de pagamento...');

      // 3. Ir para seleção de método de pagamento
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentMethodPage(
              restaurantId: widget.restaurantId,
              restaurantName: widget.restaurantName,
            ),
          ),
        );
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
                            'Método de Pagamento',
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
