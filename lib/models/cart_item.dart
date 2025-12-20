class CartItem {
  final String id;              // ID do produto
  final String name;            // Nome do produto
  final double price;           // ✅ Preço unitário BASE (sem adicionais)
  final String? imageUrl;       // URL da imagem
  final int quantity;           // Quantidade
  final List<Map<String, dynamic>> addons; // Adicionais escolhidos
  final String restaurantId;    // ID do restaurante (importante!)
  final String? restaurantName; // Nome do restaurante
  final String? brandName;      // Nome da marca (para produtos com variantes)

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.quantity = 1,
    this.addons = const [],
    required this.restaurantId,
    this.restaurantName,
    this.brandName,
  });

  // 💰 Calcula preço dos adicionais
  double get addonsTotal {
    if (addons.isEmpty) return 0;
    return addons.fold<double>(0, (sum, addon) => sum + (addon['price'] as num).toDouble());
  }

  // 💰 Preço unitário com adicionais (base + adicionais)
  double get unitPriceWithAddons => price + addonsTotal;

  // 💰 Preço total (preço unitário com adicionais × quantidade)
  double get totalPrice => unitPriceWithAddons * quantity;

  // 📝 Descrição dos adicionais
  String get addonsDescription {
    if (addons.isEmpty) return '';
    return addons.map((a) => a['name']).join(', ');
  }

  // 🔄 Criar cópia com quantidade alterada
  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      name: name,
      price: price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
      addons: addons,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      brandName: brandName,
    );
  }

  // Conversão para JSON (para API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit_price': price,
    };
  }
}
