import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';

/// Card compacto de produto para exibir em sugestões (estilo moderno)
class ProductSuggestionCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onAddToCart;
  
  const ProductSuggestionCard({
    Key? key,
    required this.product,
    required this.onAddToCart,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAddToCart,
      child: Container(
        width: 160,
        height: 220,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE39110).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE39110).withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Imagem de fundo
              _buildProductImage(),
              
              // Gradiente overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              
              // Informações na parte inferior
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nome do produto (max 2 linhas)
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Preço
                    Text(
                      product.formattedPrice,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE39110),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Botão + no topo direito
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE39110),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProductImage() {
    final imageUrl = product.displayImage;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: 160,
        height: 220,
        color: const Color(0xFF0D3B3B).withOpacity(0.6),
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            color: Colors.white38,
            size: 48,
          ),
        ),
      );
    }
    
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 160,
      height: 220,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFF0D3B3B).withOpacity(0.6),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE39110),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF0D3B3B).withOpacity(0.6),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white38,
            size: 48,
          ),
        ),
      ),
    );
  }
}
