import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart' as models;
import '../../services/backend_order_service.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../payment/pix_payment_page.dart';
import '../payment/card_checkout_page.dart'; // ✅ Checkout Pro

/// Página de seleção do método de pagamento
class PaymentMethodPage extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;
  final List<dynamic>? specificItems; // Lista específica de itens para este restaurante

  const PaymentMethodPage({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
    this.specificItems, // Opcional: se não fornecido, usa todos do carrinho
  });

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  final BackendOrderService _backendOrderService = BackendOrderService();
  
  String? _selectedMethod;
  bool _needsChange = false;
  final TextEditingController _changeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _changeController.dispose();
    super.dispose();
  }

  /// Finaliza o pedido conforme método selecionado
  Future<void> _finalizarPedido() async {
    if (_selectedMethod == null) {
      setState(() {
        _errorMessage = 'Selecione um método de pagamento';
      });
      return;
    }

    // Validar troco se necessário
    if (_selectedMethod == 'cash' && _needsChange) {
      final changeValue = double.tryParse(_changeController.text.replaceAll(',', '.'));
      final cartState = context.read<CartState>();
      
      if (changeValue == null || changeValue <= cartState.total) {
        setState(() {
          _errorMessage = 'O valor para troco deve ser maior que o total do pedido';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cartState = context.read<CartState>();
      final authState = context.read<AuthState>();

      // 1. Validar carrinho e filtrar itens deste restaurante
      final allItems = cartState.items;
      
      // Usar itens específicos passados OU filtrar do carrinho pelo restaurantId
      final restaurantItems = widget.specificItems ?? 
          allItems.where((item) => item.restaurantId == widget.restaurantId).toList();
      
      if (restaurantItems.isEmpty) {
        throw Exception('Carrinho vazio');
      }

      // 2. Validar dados do usuário
      final userData = authState.userData;
      
      if (userData == null) {
        throw Exception('Dados do usuário não encontrados. Faça login novamente.');
      }

      // Obter endereço
      var address = userData['address'];
      String deliveryAddress;
      
      if (address == null) {
        final addresses = userData['addresses'];
        if (addresses is List && addresses.isNotEmpty) {
          deliveryAddress = addresses[0].toString();
        } else {
          throw Exception('Endereço não cadastrado');
        }
      } else if (address is String) {
        deliveryAddress = address;
      } else if (address is Map) {
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
      } else {
        throw Exception('Formato de endereço inválido');
      }

      // 3. Converter itens do restaurante (não todos do carrinho)
      final orderItems = restaurantItems.map((cartItem) {
        return models.OrderItem(
          productId: cartItem.id,
          name: cartItem.name,
          price: cartItem.price,
          quantity: cartItem.quantity,
          imageUrl: cartItem.imageUrl ?? '',
          addons: cartItem.addons
              .map<models.OrderItemAddon>((addon) => models.OrderItemAddon(
                    name: addon['name'] as String? ?? '',
                    price: (addon['price'] as num? ?? 0).toDouble(),
                  ))
              .toList(),
          brandName: cartItem.brandName,
        );
      }).toList();

      // 4. Preparar dados de pagamento para a API
      // Backend espera: 'pix', 'card' ou 'cash'
      String apiPaymentMethod = _selectedMethod!;
      if (_selectedMethod == 'credit_card' || _selectedMethod == 'debit_card') {
        apiPaymentMethod = 'card'; // ✅ Converter credit_card/debit_card para 'card'
      }
      
      Map<String, dynamic> paymentData = {
        'method': apiPaymentMethod,
      };
      
      if (_selectedMethod == 'cash') {
        paymentData['needsChange'] = _needsChange;
        if (_needsChange) {
          final changeFor = double.tryParse(_changeController.text.replaceAll(',', '.'));
          paymentData['changeFor'] = changeFor;
        }
      }

      // 5. Calcular total apenas deste restaurante
      final restaurantTotal = restaurantItems.fold<double>(
        0, 
        (sum, item) => sum + item.totalPrice,
      );

      // 6. Preparar endereço formatado
      Map<String, dynamic> addressData;
      
      if (address is Map) {
        addressData = Map<String, dynamic>.from(address);
      } else if (address is String) {
        addressData = {'fullAddress': address};
      } else {
        addressData = {'fullAddress': deliveryAddress};
      }

      // 7. Criar pedido via API do backend (já salva no Firebase internamente)
      final orderId = await _backendOrderService.createOrder(
        token: authState.jwtToken ?? '',
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
        items: orderItems,
        total: restaurantTotal, // ✅ Total apenas deste restaurante
        deliveryAddress: addressData,
        payment: paymentData,
        userName: userData['name']?.toString(),
        userPhone: userData['phone']?.toString(),
      );

      debugPrint('✅ Pedido criado via API: $orderId');

      // 8. Salvar total ANTES de limpar itens
      final totalAmount = restaurantTotal;

      // 9. Limpar APENAS os itens deste restaurante do carrinho
      for (var item in restaurantItems) {
        cartState.removeItem(item.id);
      }

      // 10. Redirecionar conforme método
      if (mounted) {
        if (_selectedMethod == 'cash') {
          // Pedido em dinheiro - retornar sucesso para coordinator
          final changeMessage = _needsChange 
              ? '. Troco para R\$ ${_changeController.text}' 
              : '';
          
          // Mostrar confirmação
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Pedido confirmado! Pague R\$ ${totalAmount.toStringAsFixed(2)} na entrega$changeMessage',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Retornar sucesso após delay
          await Future.delayed(const Duration(seconds: 1));
          
          if (mounted) {
            Navigator.pop(context, {'success': true, 'orderId': orderId});
          }
        } else if (_selectedMethod == 'credit_card' || _selectedMethod == 'debit_card') {
          // Cartão de Crédito/Débito - Checkout Pro do Mercado Pago
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CardCheckoutPage(
                orderId: orderId,
                totalAmount: totalAmount, // ✅ Usar valor salvo
                userEmail: userData['email'] ?? '',
              ),
            ),
          );
        } else {
          // PIX - vai para tela de pagamento PIX
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PixPaymentPage(
                orderId: orderId,
                payerEmail: userData['email'] ?? '',
                restaurantId: widget.restaurantId,
                restaurantName: widget.restaurantName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Erro: $e');

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
      
      // Opcional: Retornar erro após alguns segundos
      // await Future.delayed(const Duration(seconds: 3));
      // if (mounted) {
      //   Navigator.pop(context, {'success': false, 'error': _errorMessage});
      // }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = context.watch<CartState>();

    return Scaffold(
      backgroundColor: const Color(0xFF022E28),
      appBar: AppBar(
        title: const Text(
          'Método de Pagamento',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF74241F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE39110),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumo do pedido
                  _buildOrderSummary(cartState),
                  
                  const SizedBox(height: 32),
                  
                  // Título
                  const Text(
                    'Como você quer pagar?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Opções de pagamento
                  _buildPaymentOption(
                    icon: Icons.money,
                    title: 'Dinheiro na entrega',
                    subtitle: 'Pague quando receber o pedido',
                    value: 'cash',
                  ),
                  
                  // Campos de troco (se dinheiro selecionado)
                  if (_selectedMethod == 'cash') ...[
                    const SizedBox(height: 16),
                    _buildChangeFields(cartState),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  _buildPaymentOption(
                    icon: Icons.pix,
                    title: 'PIX',
                    subtitle: 'Aprovação imediata',
                    value: 'pix',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildPaymentOption(
                    icon: Icons.credit_card,
                    title: 'Cartão de Crédito',
                    subtitle: 'Pague com segurança via Mercado Pago',
                    value: 'credit_card',
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildPaymentOption(
                    icon: Icons.credit_card_outlined,
                    title: 'Cartão de Débito',
                    subtitle: 'Pagamento à vista via Mercado Pago',
                    value: 'debit_card',
                  ),
                  
                  // Mensagem de erro
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Botão de finalizar
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedMethod == null ? null : _finalizarPedido,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE39110),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Confirmar Pedido',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOrderSummary(CartState cartState) {
    return Container(
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
          const Text(
            'Resumo do Pedido',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cartState.itemCount} ${cartState.itemCount == 1 ? 'item' : 'itens'}',
                style: const TextStyle(color: Colors.white70),
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
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    bool isDisabled = false,
  }) {
    final isSelected = _selectedMethod == value;
    
    return GestureDetector(
      onTap: isDisabled ? null : () {
        setState(() {
          _selectedMethod = value;
          _errorMessage = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
                )
              : null,
          color: isSelected ? null : const Color(0xFF033D35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFE39110) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDisabled 
                    ? Colors.grey 
                    : (isSelected ? const Color(0xFFE39110) : const Color(0xFF74241F)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
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
                    title,
                    style: TextStyle(
                      color: isDisabled ? Colors.grey : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDisabled ? Colors.grey : Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFE39110),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeFields(CartState cartState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF033D35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE39110).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _needsChange,
                onChanged: (value) {
                  setState(() {
                    _needsChange = value ?? false;
                    if (!_needsChange) {
                      _changeController.clear();
                    }
                  });
                },
                activeColor: const Color(0xFFE39110),
              ),
              const Expanded(
                child: Text(
                  'Preciso de troco',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (_needsChange) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _changeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Vai pagar com quanto?',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Ex: ${(cartState.total + 10).toStringAsFixed(2)}',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(
                  color: Color(0xFFE39110),
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE39110)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE39110)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE39110),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: R\$ ${cartState.total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
