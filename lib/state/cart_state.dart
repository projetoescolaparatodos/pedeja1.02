import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 📊 Quantidade total de itens
  int get itemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  // 💰 Valor total do carrinho
  double get total {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // ➕ ADICIONAR ITEM AO CARRINHO
  void addItem({
    required String productId,
    required String name,
    required double price, // Preço JÁ com adicionais incluídos!
    String? imageUrl,
    List<Map<String, dynamic>> addons = const [],
    required String restaurantId,
    String? restaurantName,
    String? brandName,
  }) {
    // Verifica se já existe no carrinho
    final existingIndex = _items.indexWhere((item) => 
      item.id == productId && 
      _addonsAreEqual(item.addons, addons) &&
      item.brandName == brandName
    );

    if (existingIndex >= 0) {
      // ✅ Se já existe COM MESMOS ADICIONAIS, aumenta quantidade
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + 1,
      );
    } else {
      // ➕ Se não existe, adiciona novo item
      _items.add(CartItem(
        id: productId,
        name: name,
        price: price,
        imageUrl: imageUrl,
        addons: addons,
        restaurantId: restaurantId,
        restaurantName: restaurantName,        brandName: brandName,      ));
    }

    notifyListeners();
  }

  // 🔄 ATUALIZAR QUANTIDADE
  void updateItemQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(productId);
      return;
    }

    final index = _items.indexWhere((item) => item.id == productId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
      notifyListeners();
    }
  }

  // ➖ REMOVER ITEM
  void removeItem(String productId) {
    _items.removeWhere((item) => item.id == productId);
    notifyListeners();
  }

  // 🧹 LIMPAR CARRINHO
  void clear() {
    _items.clear();
    notifyListeners();
  }

  // 🔍 Compara se dois arrays de adicionais são iguais
  bool _addonsAreEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    
    for (int i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id']) return false;
    }
    
    return true;
  }

  // 🏪 Verifica se carrinho tem itens de múltiplos restaurantes
  bool get hasMultipleRestaurants {
    if (_items.isEmpty) return false;
    
    final firstRestaurant = _items.first.restaurantId;
    return _items.any((item) => item.restaurantId != firstRestaurant);
  }

  // 🏪 ID do restaurante do primeiro item (para validação)
  String? get currentRestaurantId {
    return _items.isNotEmpty ? _items.first.restaurantId : null;
  }

  // 🔄 Define estado de loading
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // ❌ Define erro
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
