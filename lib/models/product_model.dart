/// Modelo de dados para produtos da API PedeJá
class ProductModel {
  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final double price;
  final String? category;
  final String? imageUrl;
  final String? image;
  final bool isAvailable;
  final List<String> badges;
  final List<Addon> addons;

  ProductModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.price,
    this.category,
    this.imageUrl,
    this.image,
    this.isAvailable = true,
    this.badges = const [],
    this.addons = const [],
  });

  /// Converte JSON da API para ProductModel
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      restaurantId: json['restaurantId'] ?? '',
      name: json['name'] ?? 'Produto sem nome',
      description: json['description'],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'],
      imageUrl: json['imageUrl'],
      image: json['image'],
      isAvailable: json['isAvailable'] ?? true,
      
      // Converte array de strings para badges
      badges: (json['badges'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      
      // Converte array de objetos para Addons
      addons: (json['addons'] as List<dynamic>?)?.map((addon) {
        return Addon(
          id: addon['id'] ?? '',
          name: addon['name'] ?? '',
          price: (addon['price'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList() ?? [],
    );
  }

  /// Retorna URL da imagem com proxy para Firebase
  String? get displayImage {
    final rawImage = image ?? imageUrl;
    
    // Se não tem imagem, retorna null
    if (rawImage == null || rawImage.isEmpty) return null;
    
    // ✅ Se for Firebase Storage, USA PROXY DA API
    if (rawImage.contains('firebasestorage.googleapis.com')) {
      return 'https://api-pedeja.vercel.app/api/image/$id?source=product&type=thumb';
    }
    
    // ✅ Se for URL externa (HTTP/HTTPS), retorna direto
    if (rawImage.startsWith('http')) {
      return rawImage;
    }
    
    // ✅ Se for caminho relativo, adiciona base da API
    return 'https://api-pedeja.vercel.app$rawImage';
  }

  /// Formata preço para exibição (R$ 25,90)
  String get formattedPrice {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// Verifica se produto tem promoção
  bool get hasPromo {
    return badges.any((badge) => badge.toLowerCase() == 'promo');
  }
}

/// Modelo de adicional/complemento
class Addon {
  final String id;
  final String name;
  final double price;

  Addon({
    required this.id,
    required this.name,
    required this.price,
  });

  /// Formata preço do addon
  String get formattedPrice {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
