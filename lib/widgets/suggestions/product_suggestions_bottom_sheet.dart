import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import 'product_suggestion_card.dart';
import '../../pages/product/product_detail_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Bottom Sheet que exibe sugestões de produtos após adicionar item ao carrinho
/// 
/// Features:
/// - Mostra até 3 produtos relacionados
/// - Auto-fecha após 10 segundos
/// - Permite adicionar produtos ao carrinho
/// - Design compacto e atraente
/// - Abre detalhes para produtos multi-marca
class ProductSuggestionsBottomSheet extends StatefulWidget {
  final List<ProductModel> suggestions;
  final Function(ProductModel) onAddToCart;
  
  const ProductSuggestionsBottomSheet({
    Key? key,
    required this.suggestions,
    required this.onAddToCart,
  }) : super(key: key);
  
  /// Método estático para mostrar o bottom sheet
  static void show(
    BuildContext context, {
    required List<ProductModel> suggestions,
    required Function(ProductModel) onAddToCart,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ProductSuggestionsBottomSheet(
        suggestions: suggestions,
        onAddToCart: onAddToCart,
      ),
    );
  }
  
  @override
  State<ProductSuggestionsBottomSheet> createState() => 
      _ProductSuggestionsBottomSheetState();
}

class _ProductSuggestionsBottomSheetState 
    extends State<ProductSuggestionsBottomSheet> {
  
  @override
  void initState() {
    super.initState();
    
    // Auto-fechar após 10 segundos
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D3B3B), // Dark green
            Color(0xFF022E28), // Very dark green
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle (barra superior)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Título com efeito de brilho
            Text(
              'Complete seu pedido',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                  ),
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Lista horizontal de produtos sugeridos
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.suggestions.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final product = widget.suggestions[index];
                  return ProductSuggestionCard(
                    product: product,
                    onAddToCart: () async {
                      print('🎯 [SUGGESTION CLICK] Produto: ${product.name}');
                      
                      // Buscar dados completos do produto (API de sugestões não retorna marcas)
                      try {
                        print('🔍 [FETCH PRODUCT] Restaurant ID: ${product.restaurantId}');
                        print('🔍 [FETCH PRODUCT] Product ID: ${product.id}');
                        
                        final response = await http.get(
                          Uri.parse('https://api-pedeja.vercel.app/api/restaurants/${product.restaurantId}/products/${product.id}'),
                        );
                        
                        if (response.statusCode == 200) {
                          final productData = json.decode(response.body);
                          final fullProduct = ProductModel.fromJson(productData);
                          
                          print('🎯 [SUGGESTION CLICK] Dados completos - hasMultipleBrands: ${fullProduct.hasMultipleBrands}');
                          print('🎯 [SUGGESTION CLICK] Dados completos - brands.length: ${fullProduct.brands.length}');
                          
                          // Se produto tem múltiplas marcas, abre página de detalhes
                          if (fullProduct.hasMultipleBrands && fullProduct.brands.isNotEmpty) {
                            print('🎯 [SUGGESTION CLICK] Redirecionando para página de detalhes');
                            if (mounted) {
                              Navigator.of(context).pop(); // Fecha o bottom sheet
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailPage(product: fullProduct),
                                ),
                              );
                            }
                            return;
                          }
                        }
                      } catch (e) {
                        print('❌ [SUGGESTION CLICK] Erro ao buscar produto completo: $e');
                      }
                      
                      print('🎯 [SUGGESTION CLICK] Adicionando direto ao carrinho');
                      // Se produto simples, adiciona direto ao carrinho
                      widget.onAddToCart(product);
                      
                      // Fechar bottom sheet (só se ainda montado)
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botão "Não, obrigado" estilizado
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: const Text(
                'Não, obrigado',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
