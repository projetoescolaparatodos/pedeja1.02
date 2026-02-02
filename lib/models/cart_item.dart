class CartItem {
  final String id;              // ID do produto
  final String name;            // Nome do produto
  final double price;           // ✅ Preço unitário BASE (sem adicionais)
  final String? imageUrl;       // URL da imagem
  final int quantity;           // Quantidade
  final List<Map<String, dynamic>> addons; // Adicionais escolhidos (sistema simples)
  final String restaurantId;    // ID do restaurante (importante!)
  final String? restaurantName; // Nome do restaurante
  final String? brandName;      // Nome da marca (para produtos com variantes)
  final bool hasMultipleBrands; // Se o produto tem múltiplas marcas
  
  // 🍕 SISTEMA DE ADICIONAIS AVANÇADOS
  final List<Map<String, dynamic>>? advancedToppingsSelections;
  
  // 🏪 PRODUTOS SOMENTE RETIRADA
  final bool pickupOnly;

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
    this.hasMultipleBrands = false,
    this.advancedToppingsSelections,
    this.pickupOnly = false,
  });

  // 💰 Calcula preço dos adicionais
  double get addonsTotal {
    double total = 0.0;
    
    // Adicionais simples (sistema antigo)
    if (addons.isNotEmpty) {
      total += addons.fold<double>(0, (sum, addon) => sum + (addon['price'] as num).toDouble());
    }
    
    // Adicionais avançados (seções)
    if (advancedToppingsSelections != null && advancedToppingsSelections!.isNotEmpty) {
      for (var selection in advancedToppingsSelections!) {
        final itemPrice = (selection['itemPrice'] as num?)?.toDouble() ?? 0.0;
        final quantity = (selection['quantity'] as int?) ?? 1;
        total += itemPrice * quantity;
      }
    }
    
    return total;
  }

  // 💰 Preço unitário com adicionais (base + adicionais)
  double get unitPriceWithAddons => price + addonsTotal;

  // 💰 Preço total (preço unitário com adicionais × quantidade)
  double get totalPrice => unitPriceWithAddons * quantity;

  // 📝 Descrição dos adicionais
  String get addonsDescription {
    final parts = <String>[];
    
    // Adicionais simples
    if (addons.isNotEmpty) {
      parts.add(addons.map((a) => a['name']).join(', '));
    }
    
    // Adicionais avançados (seções)
    if (advancedToppingsSelections != null && advancedToppingsSelections!.isNotEmpty) {
      for (var selection in advancedToppingsSelections!) {
        final name = selection['itemName'] as String? ?? '';
        final qty = selection['quantity'] as int? ?? 1;
        if (qty > 1) {
          parts.add('$name (${qty}x)');
        } else {
          parts.add(name);
        }
      }
    }
    
    return parts.join(', ');
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
      hasMultipleBrands: hasMultipleBrands,
      advancedToppingsSelections: advancedToppingsSelections,
      pickupOnly: pickupOnly,
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
