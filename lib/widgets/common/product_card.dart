
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
                      
                      // Otimizações de cache
                      memCacheWidth: 400,
                      memCacheHeight: 400,
                      maxWidthDiskCache: 400,
                      maxHeightDiskCache: 400,
                      
                      // Enquanto carrega
                      placeholder: (_, __) => Container(
                        color: const Color(0xFF022E28),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE39110),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      
                      // Se der erro ao carregar
                      errorWidget: (_, url, error) => Container(
                        color: const Color(0xFF022E28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
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
                      ),
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

            // BADGES DO PRODUTO (topo esquerdo)
            if (product.badges.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                right: restaurantName != null ? 70 : 8,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: product.badges.map((badge) => _buildBadge(badge)).toList(),
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

                  // DESCRIÇÃO (opcional)
                  if (product.description != null && product.description!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        product.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // BADGE DE PREÇO (circular no canto inferior esquerdo)
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
                        product.formattedPrice,
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

  /// Constrói badge individual com ícone e cor específica
  Widget _buildBadge(String badge) {
    // Configuração de cores e ícones por tipo de badge
    final Map<String, Map<String, dynamic>> badgeConfig = {
      'vegano': {
        'label': 'Vegano',
        'icon': Icons.eco,
        'color': const Color(0xFF8BC34A),
      },
      'vegetariano': {
        'label': 'Vegetariano',
        'icon': Icons.eco,
        'color': const Color(0xFF8BC34A),
      },
      'sem_gluten': {
        'label': 'Sem Glúten',
        'icon': Icons.health_and_safety,
        'color': const Color(0xFF4CAF50),
      },
      'promo': {
        'label': 'Promoção',
        'icon': Icons.local_fire_department,
        'color': const Color(0xFFFF6F3D),
      },
      'novo': {
        'label': 'Novo',
        'icon': Icons.fiber_new,
        'color': const Color(0xFFE39110),
      },
      'picante': {
        'label': 'Picante',
        'icon': Icons.whatshot,
        'color': const Color(0xFFFF5722),
      },
    };

    final config = badgeConfig[badge.toLowerCase()] ?? {
      'label': badge,
      'icon': Icons.star,
      'color': const Color(0xFFDA9528),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            config['label'] as String,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
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
