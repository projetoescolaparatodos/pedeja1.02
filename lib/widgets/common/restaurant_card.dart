import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/restaurant_model.dart';

class RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.width = 260,
    this.height = 160,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showStatus = restaurant.apiIsOpen != null;
    final isOpen = restaurant.isOpen == true;

    return Hero(
      tag: 'restaurant-${restaurant.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Imagem de fundo (cobre todo o card)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildImage(),
                  ),
                ),

                // Gradiente escuro no fundo
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Badge de status (Aberto/Fechado)
                if (showStatus)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isOpen 
                            ? const Color(0xFF4CAF50) 
                            : const Color(0xFFFF5722),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        isOpen ? 'Aberto' : 'Fechado',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Informações do restaurante
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nome do restaurante
                      Text(
                        restaurant.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Endereço
                      Text(
                        restaurant.address,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = restaurant.displayImage?.trim();
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      memCacheHeight: 300,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF74241F),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }
}