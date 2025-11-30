import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/cart_state.dart';
import '../../state/auth_state.dart';
import '../../models/cart_item.dart';
import '../profile/complete_profile_page.dart';
import '../checkout/checkout_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D3B3B), // Verde musgo escuro
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 📌 HEADER
          _buildHeader(context),

          // 📦 CONTEÚDO
          Expanded(
            child: Consumer<CartState>(
              builder: (context, cart, _) {
                // ⏳ LOADING
                if (cart.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE39110),
                      ),
                    ),
                  );
                }

                // 🛒 CARRINHO VAZIO
                if (cart.items.isEmpty) {
                  return _buildEmptyCart();
                }

                // ✅ LISTA DE ITENS + RESUMO
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length + 1, // +1 para resumo
                  itemBuilder: (context, index) {
                    // 💰 RESUMO (última posição)
                    if (index == cart.items.length) {
                      return _buildCartSummary(context, cart);
                    }

                    // 📦 ITEM DO CARRINHO
                    final item = cart.items[index];
                    return _buildCartItem(context, cart, item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4747),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFFE39110)),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Meu Carrinho',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE39110),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: const Color(0xFFE39110).withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Seu carrinho está vazio',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE39110),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Adicione itens para começar seu pedido',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartState cart, CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2F2F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A4747),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ IMAGEM
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                color: const Color(0xFF1A4747),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.fastfood,
                          color: Color(0xFFE39110),
                          size: 40,
                        ),
                      )
                    : const Icon(
                        Icons.fastfood,
                        color: Color(0xFFE39110),
                        size: 40,
                      ),
              ),
            ),

            const SizedBox(width: 12),

            // 📝 INFORMAÇÕES
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Adicionais
                  if (item.addonsDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.add_circle_outline,
                          size: 14,
                          color: Color(0xFFE39110),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.addonsDescription,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFE39110),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Preço
                  Text(
                    'R\$ ${item.price.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE39110),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ➕➖ CONTROLES DE QUANTIDADE
                  Row(
                    children: [
                      // Botão -
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: const Color(0xFFE39110),
                        iconSize: 28,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (item.quantity > 1) {
                            cart.updateItemQuantity(
                              item.id,
                              item.quantity - 1,
                            );
                          } else {
                            cart.removeItem(item.id);
                          }
                        },
                      ),

                      // Quantidade
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A4747),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE39110),
                          ),
                        ),
                      ),

                      // Botão +
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFFE39110),
                        iconSize: 28,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          cart.updateItemQuantity(
                            item.id,
                            item.quantity + 1,
                          );
                        },
                      ),

                      const Spacer(),

                      // Botão excluir
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: const Color(0xFFFF5722),
                        iconSize: 24,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          cart.removeItem(item.id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(BuildContext context, CartState cart) {
    final bool belowMinimum = cart.total < 10.0;

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A4747),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE39110),
                    ),
                  ),
                  Text(
                    'R\$ ${cart.total.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE39110),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ⚠️ AVISO DE VALOR MÍNIMO
              if (belowMinimum)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Valor mínimo do pedido: R\$ 10,00',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 🚀 BOTÃO FINALIZAR PEDIDO
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: belowMinimum ? null : () => _processCheckout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74241F), // Vinho
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    disabledForegroundColor: Colors.grey.shade600,
                    elevation: 4,
                    shadowColor: Colors.black.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Finalizar Pedido',
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
        const SizedBox(height: 100),
      ],
    );
  }

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => const CartPage(),
      ),
    );
  }

  /// 🔍 Processa checkout com validação de perfil completo
  static Future<void> _processCheckout(BuildContext context) async {
    debugPrint('🛒 [CHECKOUT] Iniciando processo de checkout');
    
    final authState = context.read<AuthState>();

    // 📡 Atualizar dados do AuthState verificando com a API
    debugPrint('🔄 [CHECKOUT] Verificando dados atualizados na API...');
    final isComplete = await authState.checkRegistrationComplete();
    
    debugPrint('📋 [CHECKOUT] AuthState.registrationComplete: $isComplete');
    debugPrint('📋 [CHECKOUT] AuthState.userData: ${authState.userData}');

    // 📡 Garantir que dados do usuário estão carregados
    if (authState.userData == null) {
      debugPrint('⚠️ [CHECKOUT] userData null - não autenticado');
      
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Você precisa fazer login primeiro'),
          backgroundColor: Color(0xFF74241F),
        ),
      );
      return;
    }

    if (!context.mounted) {
      debugPrint('❌ [CHECKOUT] Context não está mounted - abortando');
      return;
    }

    // 🔍 VALIDAÇÃO: Verifica se perfil está completo usando AuthState
    debugPrint('🔍 [CHECKOUT] Validando perfil...');
    debugPrint('📋 [CHECKOUT] registrationComplete: $isComplete');
    
    if (!isComplete) {
      debugPrint('⚠️ [CHECKOUT] Perfil incompleto - mostrando diálogo');
      
      // ⚠️ NÃO fecha o carrinho ainda - mostra dialog primeiro
      debugPrint('📢 [CHECKOUT] Mostrando dialog de campos faltantes');
      
      // Mostra diálogo explicativo
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0D3B3B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE39110), width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFE39110), size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cadastro Incompleto',
                  style: TextStyle(
                    color: Color(0xFFE39110),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para finalizar seu pedido, precisamos que você complete seu cadastro.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Deseja completar agora?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Agora não',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE39110),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Completar Cadastro',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      debugPrint('📊 [CHECKOUT] Dialog retornou: $shouldProceed');
      
      // Se usuário aceitar, navega para tela de cadastro
      if (shouldProceed == true) {
        debugPrint('✅ [CHECKOUT] Usuário aceitou completar cadastro');
        
        if (!context.mounted) {
          debugPrint('❌ [CHECKOUT] Context perdido após dialog');
          return;
        }
        
        // 🔙 AGORA SIM: Fecha o carrinho antes de navegar
        Navigator.pop(context);
        debugPrint('🔙 [CHECKOUT] Carrinho fechado');
        
        // Pequeno delay para garantir que a animação do carrinho terminou
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (!context.mounted) {
          debugPrint('❌ [CHECKOUT] Context perdido após fechar carrinho');
          return;
        }
        
        // Debug: confirma navegação
        debugPrint('🚀 [CHECKOUT] Navegando para CompleteProfilePage...');
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CompleteProfilePage(),
          ),
        );
        
        // Debug: retornou da tela
        debugPrint('🔙 [CHECKOUT] Retornou de CompleteProfilePage');
      } else {
        debugPrint('❌ [CHECKOUT] Usuário cancelou completar cadastro');
        // Usuário cancelou - mantém o carrinho aberto
      }

      debugPrint('⛔ [CHECKOUT] Interrompendo checkout (perfil incompleto)');
      return; // ⛔ Interrompe checkout
    }

    debugPrint('✅ [CHECKOUT] Perfil completo - prosseguindo...');
    
    // ✅ Perfil completo → Continua com checkout
    Navigator.pop(context); // Fecha carrinho

    await Future.delayed(const Duration(milliseconds: 100));

    if (!context.mounted) return;

    // 🚀 Navegar para tela de checkout com pagamento
    final cartState = context.read<CartState>();
    
    // Verificar se há itens no carrinho
    if (cartState.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carrinho vazio'),
          backgroundColor: Color(0xFF74241F),
        ),
      );
      return;
    }

    // Pegar dados do restaurante (primeiro item do carrinho)
    final firstItem = cartState.items.first;
    final restaurantId = firstItem.restaurantId;
    final restaurantName = firstItem.restaurantName ?? 'Restaurante';

    // Navegar para checkout
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          restaurantId: restaurantId,
          restaurantName: restaurantName,
        ),
      ),
    );
  }
}

