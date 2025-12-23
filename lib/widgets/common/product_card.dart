
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../pages/product/product_detail_page.dart';

/// Card de produto para PedeJá
/// Exibe produto da API com badges, preço e informações do restaurante
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final String? restaurantName; // Nome do restaurante (badge superior)
  final VoidCallback? onTap;
  final bool hero;
  final String? heroTag;
  final bool isRestaurantOpen;

  const ProductCard({
    super.key,
    required this.product,
    this.restaurantName,
    this.onTap,
    this.hero = false,
    this.heroTag,
    this.isRestaurantOpen = true,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFE39110), // Borda dourada
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // IMAGEM DE FUNDO
            Positioned.fill(
              child: product.displayImage?.isNotEmpty == true
                  ? CachedNetworkImage(
                      imageUrl: product.displayImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF022E28),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE39110),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        return Container(
                          color: const Color(0xFF022E28),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                color: Colors.white24,
                                size: 48,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Imagem indisponível',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      // Configurações para melhorar carregamento em release
                      maxWidthDiskCache: 800,
                      maxHeightDiskCache: 800,
                      memCacheWidth: 400,
                      memCacheHeight: 400,
                    )
                  : Container(
                      color: const Color(0xFF022E28),
                      child: const Icon(
                        Icons.restaurant,
                        color: Colors.white24,
                        size: 48,
                      ),
                    ),
            ),

            // GRADIENTE OVERLAY - Escuro na metade inferior para legibilidade
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.6, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.0),   // Topo transparente
                      Colors.black.withValues(alpha: 0.3),   // 60% levemente escuro
                      Colors.black.withValues(alpha: 0.85),  // Fundo bem escuro
                    ],
                  ),
                ),
              ),
            ),

            // BADGE DE RESTAURANTE (topo direito)
            if (restaurantName != null && restaurantName!.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D3B3B), // Verde escuro
                    border: Border.all(
                      color: const Color(0xFFE39110), // Borda dourada
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    restaurantName!,
                    style: const TextStyle(
                      color: Color(0xFFE39110), // Texto dourado
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Badge de múltiplas marcas (canto superior esquerdo)
            if (product.hasMultipleBrands && product.brands.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF74241F).withValues(alpha: 0.95),
                    border: Border.all(
                      color: const Color(0xFFE39110),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${product.brands.length} marcas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // TEXTOS E PREÇO (parte inferior)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TÍTULO
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // BADGE DE PREÇO
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D3B3B), // Verde escuro
                        border: Border.all(
                          color: const Color(0xFFE39110), // Borda dourada
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.hasPriceRange 
                            ? product.priceRangeText
                            : product.formattedPrice,
                        style: const TextStyle(
                          color: Color(0xFFE39110), // Texto dourado
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final clickable = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isRestaurantOpen
            ? () {
                if (onTap != null) {
                  onTap!();
                } else {
                  _navigateToDetail(context);
                }
              }
            : null,
        child: Opacity(
          opacity: isRestaurantOpen ? 1.0 : 0.5,
          child: card,
        ),
      ),
    );

    // Hero animation opcional
    if (hero && heroTag != null) {
      return Hero(tag: heroTag!, child: clickable);
    }
    return clickable;
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }
}
