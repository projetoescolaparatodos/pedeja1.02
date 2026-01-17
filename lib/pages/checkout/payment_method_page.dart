import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/order_model.dart' as models;
import '../../models/restaurant_model.dart';
import '../../services/backend_order_service.dart';
import '../../state/auth_state.dart';
import '../../state/cart_state.dart';
import '../payment/pix_payment_page.dart';
import '../payment/card_checkout_page.dart'; // ✅ Checkout Pro
import '../profile/complete_profile_page.dart';

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
  String _deliveryMethod = 'delivery'; // 'delivery' | 'pickup'
  double? _deliveryFeeAmount; // Taxa que cliente paga
  double? _totalDeliveryFee;  // Taxa total (entregador recebe)
  RestaurantModel? _restaurant; // ✅ Modelo completo com dynamicDeliveryFee
  bool _isLoadingDeliveryFee = false;
  bool _needsChange = false;
  final TextEditingController _changeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeliveryFee();
  }
  Future<void> _loadDeliveryFee() async {
    setState(() {
      _isLoadingDeliveryFee = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/restaurants/${widget.restaurantId}'),
      );

      if (response.statusCode == 200) {
        final restaurantData = json.decode(response.body);
        
        // ✅ Parsear RestaurantModel completo (com dynamicDeliveryFee)
        _restaurant = RestaurantModel.fromJson(restaurantData);
        _totalDeliveryFee = _restaurant!.deliveryFee;
        
        debugPrint('🏪 Restaurante carregado: ${_restaurant!.name}');
        debugPrint('💰 Taxa real (entregador): R\$ ${_totalDeliveryFee!.toStringAsFixed(2)}');
        debugPrint('🎯 Taxa dinâmica ativada: ${_restaurant!.dynamicDeliveryFee?.enabled}');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao buscar restaurante: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDeliveryFee = false;
        });
      }
    }
  }

  List<dynamic> _restaurantItems(CartState cartState) {
    final allItems = cartState.items;
    return widget.specificItems ??
        allItems.where((item) => item.restaurantId == widget.restaurantId).toList();
  }

  double _calculateSubtotal(List<dynamic> restaurantItems) {
    return restaurantItems.fold<double>(0, (sum, item) => sum + item.totalPrice);
  }

  double _effectiveDeliveryFee() {
    if (_deliveryMethod == 'pickup') return 0.0;
    if (_restaurant == null) return 0.0;
    
    // ✅ Usar CartState para calcular taxa dinâmica baseada no subtotal
    final cartState = context.read<CartState>();
    final restaurantItems = _restaurantItems(cartState);
    final subtotal = _calculateSubtotal(restaurantItems);
    
    return cartState.calculateRestaurantDeliveryFee(_restaurant!, subtotal);
  }

  double _calculateTotal(double subtotal) {
    return subtotal + _effectiveDeliveryFee();
  }

  Map<String, dynamic> _buildAddressData(dynamic address, String formattedAddress) {
    // ✅ API espera campos individuais (street, number, etc) + method
    if (address is Map) {
      return {
        'method': _deliveryMethod, // 'delivery' ou 'pickup'
        'street': address['street'] ?? '',
        'number': address['number'] ?? '',
        'complement': address['complement'] ?? '',
        'neighborhood': address['neighborhood'] ?? '',
        'city': address['city'] ?? '',
        'state': address['state'] ?? '',
        'zipCode': address['zipCode'] ?? '',
        'fullAddress': formattedAddress, // Enviar também formatado
      };
    }

    // Fallback para string
    return {
      'fullAddress': formattedAddress,
      'method': _deliveryMethod,
    };
  }

  /// ✅ Parse de endereço no formato: "R. Fulana, 123 - Bairro, Cidade/Estado CEP: 12345-000"
  Map<String, dynamic> _parseAddressString(String fullAddress) {
    try {
      // Padrão: "Rua, Número - Bairro, Cidade - Estado CEP: 00000-000"
      // ou: "Rua, Número - Bairro, Cidade/Estado"
      
      String street = '';
      String number = '';
      String neighborhood = '';
      String city = '';
      String state = '';
      String zipCode = '';
      
      // Remover CEP se houver
      final cepMatch = RegExp(r'CEP:\s*(\d{5}-?\d{3})').firstMatch(fullAddress);
      if (cepMatch != null) {
        zipCode = cepMatch.group(1) ?? '';
        fullAddress = fullAddress.replaceFirst(cepMatch.group(0)!, '').trim();
      }
      
      // Padrão 1: "Rua, 123 - Bairro, Cidade/Estado"
      var match = RegExp(r'^(.+?),\s*(\d+)\s*-\s*([^,]+),\s*([^/]+)/(.+)$').firstMatch(fullAddress);
      
      if (match != null) {
        street = match.group(1)?.trim() ?? '';
        number = match.group(2)?.trim() ?? '';
        neighborhood = match.group(3)?.trim() ?? '';
        city = match.group(4)?.trim() ?? '';
        state = match.group(5)?.trim() ?? '';
      } else {
        // Padrão 2: "Rua, 123 - Bairro, Cidade - Estado"
        match = RegExp(r'^(.+?),\s*(\d+)\s*-\s*([^,]+),\s*(.+?)\s*-\s*(.+)$').firstMatch(fullAddress);
        
        if (match != null) {
          street = match.group(1)?.trim() ?? '';
          number = match.group(2)?.trim() ?? '';
          neighborhood = match.group(3)?.trim() ?? '';
          city = match.group(4)?.trim() ?? '';
          state = match.group(5)?.trim() ?? '';
        } else {
          // Fallback: usar tudo como street
          debugPrint('⚠️ [Parse] Não conseguiu parsear, usando formato original');
          street = fullAddress;
        }
      }
      
      return {
        'street': street,
        'number': number,
        'complement': '',
        'neighborhood': neighborhood,
        'city': city,
        'state': state,
        'zipCode': zipCode,
      };
    } catch (e) {
      debugPrint('❌ [Parse] Erro ao parsear endereço: $e');
      return {
        'street': fullAddress,
        'number': '',
        'complement': '',
        'neighborhood': '',
        'city': '',
        'state': '',
        'zipCode': '',
      };
    }
  }

  void _validateDeliveryAddressOrThrow(dynamic address) {
    if (_deliveryMethod == 'pickup') return; // Pickup não precisa validar endereço

    debugPrint('🔍 [Validação] Validando endereço: $address (tipo: ${address.runtimeType})');

    if (address is Map) {
      final requiredFields = {
        'street': 'Rua/Avenida',
        'number': 'Número',
        'neighborhood': 'Bairro',
        'city': 'Cidade',
        'state': 'Estado',
      };
      
      // CEP é opcional (nem sempre disponível no banco)
      final optionalFields = {
        'zipCode': 'CEP',
      };

      final missing = <String>[];
      
      requiredFields.forEach((field, label) {
        final value = address[field]?.toString().trim() ?? '';
        debugPrint('   Campo $field ($label): "$value" ${value.isEmpty ? "❌ VAZIO" : "✅"}');
        if (value.isEmpty) {
          missing.add(label);
        }
      });
      
      // Validar opcionais (apenas log, não bloqueia)
      optionalFields.forEach((field, label) {
        final value = address[field]?.toString().trim() ?? '';
        debugPrint('   Campo $field ($label - opcional): "$value" ${value.isEmpty ? "⚠️ VAZIO" : "✅"}');
      });

      if (missing.isNotEmpty) {
        final errorMsg = 'Complete o endereço: ${missing.join(', ')}';
        debugPrint('❌ [Validação] ERRO: $errorMsg');
        throw Exception(errorMsg);
      }
      
      debugPrint('✅ [Validação] Endereço completo!');
      return;
    }

    debugPrint('❌ [Validação] Endereço não é um Map!');
    throw Exception('Endereço inválido para entrega. Atualize seu cadastro.');
  }

  Future<double> _ensureDeliveryFeeLoaded() async {
    if (_deliveryMethod == 'pickup') return 0.0;
    if (_deliveryFeeAmount != null) return _deliveryFeeAmount!;
    await _loadDeliveryFee();
    return _deliveryFeeAmount ?? 0.0;
  }

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
      final restaurantItems = _restaurantItems(cartState);
      if (restaurantItems.isEmpty) {
        throw Exception('Carrinho vazio');
      }

      // 2. Validar dados do usuário
      final userData = authState.userData;
      if (userData == null) {
        throw Exception('Dados do usuário não encontrados. Faça login novamente.');
      }

      // Obter endereço atual do usuário
      var address = userData['address'];
      String deliveryAddressString;

      debugPrint('🏠 [Address Debug] userData[\'address\']: ${userData['address']}');

      if (address == null) {
        if (_deliveryMethod == 'delivery') {
          throw Exception('Endereço não cadastrado');
        }
        deliveryAddressString = 'Retirada no local';
        address = {}; // Mock vazio para pickup
      } else if (address is String) {
        deliveryAddressString = address;
        // ✅ Parse do formato: "R. Fulana, 123 - Bairro, Cidade/Estado"
        address = _parseAddressString(address);
        debugPrint('🏠 [Parse] String parseada: $address');
      } else if (address is Map) {
        final addressMap = Map<String, dynamic>.from(address);
        
        // ✅ COMPATIBILIDADE: Se campos vazios mas street tem tudo, parsear
        final street = addressMap['street']?.toString() ?? '';
        final number = addressMap['number']?.toString().trim() ?? '';
        final neighborhood = addressMap['neighborhood']?.toString().trim() ?? '';
        final city = addressMap['city']?.toString().trim() ?? '';
        final state = addressMap['state']?.toString().trim() ?? '';
        final zipCode = addressMap['zipCode']?.toString().trim() ?? '';
        
        if (number.isEmpty && neighborhood.isEmpty && city.isEmpty && street.contains(',')) {
          // Backend salvou tudo no campo street, parsear!
          debugPrint('🏠 [Parse] Endereço no formato antigo (tudo em street), parseando...');
          address = _parseAddressString(street);
          address['zipCode'] = zipCode; // Manter zipCode se houver
          debugPrint('🏠 [Parse] Endereço parseado: $address');
        }
        
        // Formatar string para exibição
        final parsedMap = address is Map ? Map<String, dynamic>.from(address) : addressMap;
        final finalStreet = parsedMap['street']?.toString() ?? '';
        final finalNumber = parsedMap['number']?.toString() ?? '';
        final finalComplement = parsedMap['complement']?.toString() ?? '';
        final finalNeighborhood = parsedMap['neighborhood']?.toString() ?? '';
        final finalCity = parsedMap['city']?.toString() ?? '';
        final finalState = parsedMap['state']?.toString() ?? '';
        final finalZipCode = parsedMap['zipCode']?.toString() ?? '';
        
        deliveryAddressString = '$finalStreet, $finalNumber'
            '${finalComplement.isNotEmpty ? ' - $finalComplement' : ''}'
            ' - $finalNeighborhood, $finalCity - $finalState'
            ' CEP: $finalZipCode';
      } else {
        throw Exception('Formato de endereço inválido');
      }

      debugPrint('🏠 [Address Final] address: $address');
      debugPrint('🏠 [Address Final] deliveryAddressString: $deliveryAddressString');

      // 2.1 Validar endereço somente para delivery
      _validateDeliveryAddressOrThrow(address);

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

      // 5. Calcular totais com taxa dinâmica
      final restaurantSubtotal = _calculateSubtotal(restaurantItems);
      await _ensureDeliveryFeeLoaded(); // Garantir que _restaurant está carregado
      
      if (_restaurant == null) {
        throw Exception('Dados do restaurante não carregados');
      }
      
      // ✅ Usar CartState para calcular taxa dinâmica baseada no subtotal real
      final double totalDeliveryFee = _deliveryMethod == 'pickup' ? 0.0 : _restaurant!.deliveryFee;
      final double customerPaid = _deliveryMethod == 'pickup' 
          ? 0.0 
          : cartState.calculateRestaurantDeliveryFee(_restaurant!, restaurantSubtotal);
      final double restaurantSubsidy = totalDeliveryFee - customerPaid;
      
      // Determinar modo
      String deliveryMode;
      if (customerPaid == 0) {
        deliveryMode = 'free';
      } else if (restaurantSubsidy > 0) {
        deliveryMode = 'partial';
      } else {
        deliveryMode = 'complete';
      }
      
      // Criar objeto delivery
      final Map<String, dynamic>? deliveryObject = _deliveryMethod == 'pickup' 
        ? null // Pickup não precisa delivery object
        : {
            'totalFee': totalDeliveryFee,
            'customerPaid': customerPaid,
            'restaurantSubsidy': restaurantSubsidy,
            'mode': deliveryMode,
          };
      
      debugPrint('🚚 [Delivery] totalFee: R\$ ${totalDeliveryFee.toStringAsFixed(2)}');
      debugPrint('🚚 [Delivery] customerPaid: R\$ ${customerPaid.toStringAsFixed(2)}');
      debugPrint('🚚 [Delivery] restaurantSubsidy: R\$ ${restaurantSubsidy.toStringAsFixed(2)}');
      debugPrint('🚚 [Delivery] mode: $deliveryMode');

      // 6. Preparar endereço formatado com method
      final addressData = _buildAddressData(address, deliveryAddressString);

      // 7. Criar pedido via API do backend (já salva no Firebase internamente)
      final orderId = await _backendOrderService.createOrder(
        token: authState.jwtToken ?? '',
        restaurantId: widget.restaurantId,
        restaurantName: widget.restaurantName,
        items: orderItems,
        subtotal: restaurantSubtotal,
        deliveryFee: customerPaid,
        delivery: deliveryObject, // ✅ Objeto delivery completo
        total: _calculateTotal(restaurantSubtotal),
        deliveryAddress: addressData,
        payment: paymentData,
        userName: userData['name']?.toString(),
        userPhone: userData['phone']?.toString(),
      );

      debugPrint('✅ Pedido criado via API: $orderId');

      // 8. Salvar total ANTES de limpar itens (INCLUINDO taxa de entrega)
      final totalAmount = _calculateTotal(restaurantSubtotal);

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
    final restaurantItems = _restaurantItems(cartState);
    final subtotal = _calculateSubtotal(restaurantItems);
    final deliveryFee = _effectiveDeliveryFee();
    final total = _calculateTotal(subtotal);
    final isPickup = _deliveryMethod == 'pickup';

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
                  _buildOrderSummary(
                    itemCount: restaurantItems.length,
                    subtotal: subtotal,
                    deliveryFee: deliveryFee,
                    total: total,
                    isPickup: isPickup,
                  ),

                  const SizedBox(height: 16),

                  _buildDeliveryMethodSelector(isPickup, deliveryFee),
                  
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
                    _buildChangeFields(total),
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

  Widget _buildOrderSummary({
    required int itemCount,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required bool isPickup,
  }) {
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
                '$itemCount ${itemCount == 1 ? 'item' : 'itens'}',
                style: const TextStyle(color: Colors.white70),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Subtotal: R\$ ${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Taxa: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (_isLoadingDeliveryFee && !isPickup)
                        const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE39110),
                          ),
                        )
                      else
                        Text(
                          isPickup
                              ? 'GRÁTIS (retirada)'
                              : 'R\$ ${deliveryFee.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isPickup ? Colors.greenAccent : Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Total: R\$ ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFE39110),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodSelector(bool isPickup, double deliveryFee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF033D35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE39110).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como quer receber?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDeliveryMethodTile(
            title: 'Entrega em casa',
            subtitle: 'Receba no endereço cadastrado',
            value: 'delivery',
            selected: _deliveryMethod == 'delivery',
            trailing: _isLoadingDeliveryFee
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE39110),
                    ),
                  )
                : Text(
                    'Taxa: R\$ ${deliveryFee.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
          ),
          // ✨ Botão para mudar endereço (só aparece quando delivery está selecionado)
          if (_deliveryMethod == 'delivery')
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompleteProfilePage(),
                    ),
                  );
                  // Recarregar taxa de entrega após voltar da página de endereço
                  if (mounted) {
                    _loadDeliveryFee();
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_location,
                      size: 16,
                      color: const Color(0xFFE39110),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mudar endereço',
                      style: TextStyle(
                        color: const Color(0xFFE39110),
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFE39110),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          _buildDeliveryMethodTile(
            title: 'Retirada no local',
            subtitle: 'Você busca no restaurante',
            value: 'pickup',
            selected: _deliveryMethod == 'pickup',
            trailing: const Text(
              'GRÁTIS',
              style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMethodTile({
    required String title,
    required String subtitle,
    required String value,
    required bool selected,
    required Widget trailing,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _deliveryMethod = value;
          _errorMessage = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _deliveryMethod,
              activeColor: const Color(0xFFE39110),
              onChanged: (_) {
                setState(() {
                  _deliveryMethod = value;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
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

  Widget _buildChangeFields(double totalAmount) {
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
                hintText: 'Ex: ${(totalAmount + 10).toStringAsFixed(2)}',
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
              'Total: R\$ ${totalAmount.toStringAsFixed(2)}',
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
