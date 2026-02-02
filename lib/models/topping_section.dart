// 🍕 SISTEMA DE ADICIONAIS AVANÇADOS - SEÇÕES
// Modelo para seções de toppings (bases, cremes, complementos, etc.)
// Cada seção tem limites min/max e lista de itens disponíveis

class ToppingSection {
  final String id;
  final String name;
  final int minItems;
  final int maxItems;
  final List<ToppingItem> items;

  ToppingSection({
    required this.id,
    required this.name,
    required this.minItems,
    required this.maxItems,
    required this.items,
  });

  // Parse do JSON vindo da API
  factory ToppingSection.fromJson(Map<String, dynamic> json) {
    return ToppingSection(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      minItems: json['minItems'] as int? ?? 0,
      maxItems: json['maxItems'] as int? ?? 0,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => ToppingItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Converte para JSON para enviar à API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'minItems': minItems,
      'maxItems': maxItems,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // Verifica se a seção é obrigatória (min > 0)
  bool get isRequired => minItems > 0;

  // Verifica se a seção permite múltiplos itens
  bool get allowsMultiple => maxItems > 1;
}

// 🧃 Item individual dentro de uma seção de toppings
class ToppingItem {
  final String id;
  final String name;
  final double price;

  ToppingItem({
    required this.id,
    required this.name,
    required this.price,
  });

  // Parse do JSON vindo da API
  factory ToppingItem.fromJson(Map<String, dynamic> json) {
    return ToppingItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converte para JSON para enviar à API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  // Preço formatado em reais (R$ X,XX)
  String get formattedPrice {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Criar cópia do item
  ToppingItem copyWith({
    String? id,
    String? name,
    double? price,
  }) {
    return ToppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
}

// 🛒 Item selecionado pelo usuário (para enviar ao carrinho/pedido)
class SelectedTopping {
  final String sectionId;
  final String sectionName;
  final String itemId;
  final String itemName;
  final double itemPrice;
  final int quantity;

  SelectedTopping({
    required this.sectionId,
    required this.sectionName,
    required this.itemId,
    required this.itemName,
    required this.itemPrice,
    this.quantity = 1,
  });

  // Converte para o formato esperado pelo backend
  Map<String, dynamic> toJson() {
    return {
      'sectionId': sectionId,
      'sectionName': sectionName,
      'itemId': itemId,
      'itemName': itemName,
      'itemPrice': itemPrice,
      'quantity': quantity,
    };
  }

  // Parse do JSON (útil para reconstruir do carrinho)
  factory SelectedTopping.fromJson(Map<String, dynamic> json) {
    return SelectedTopping(
      sectionId: json['sectionId'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      itemId: json['itemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      itemPrice: (json['itemPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  // Preço total deste item (preço × quantidade)
  double get totalPrice => itemPrice * quantity;
}
