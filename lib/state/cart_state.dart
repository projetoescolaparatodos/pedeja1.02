import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../models/restaurant_model.dart';
import '../models/dynamic_delivery_fee_model.dart';

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;
  bool _hasShownSuggestions = false; // Controle para mostrar sugestões apenas 1x

  // Getters
  List<CartItem> get items => _items;
  bool get hasShownSuggestions => _hasShownSuggestions;
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
    bool hasMultipleBrands = false,
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
        restaurantName: restaurantName,
        brandName: brandName,
        hasMultipleBrands: hasMultipleBrands,
      ));
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
    _hasShownSuggestions = false; // Resetar flag ao limpar carrinho
    notifyListeners();
  }
  
  // 🎯 Marcar que sugestões foram mostradas
  void markSuggestionsAsShown() {
    _hasShownSuggestions = true;
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

  // 🏪 Agrupa itens por restaurante
  Map<String, List<CartItem>> get itemsByRestaurant {
    final Map<String, List<CartItem>> grouped = {};
    
    for (var item in _items) {
      if (!grouped.containsKey(item.restaurantId)) {
        grouped[item.restaurantId] = [];
      }
      grouped[item.restaurantId]!.add(item);
    }
    
    return grouped;
  }

  // 💰 Calcula subtotal de um restaurante específico
  double getRestaurantSubtotal(String restaurantId) {
    return _items
        .where((item) => item.restaurantId == restaurantId)
        .fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // 📉 Calcula quanto falta para atingir o pedido mínimo
  double getMissingAmount(String restaurantId, double minimumOrder) {
    final subtotal = getRestaurantSubtotal(restaurantId);
    final missing = minimumOrder - subtotal;
    return missing > 0 ? missing : 0;
  }

  // ✅ Verifica se o restaurante atingiu o pedido mínimo
  bool meetsMinimum(String restaurantId, double minimumOrder) {
    return getRestaurantSubtotal(restaurantId) >= minimumOrder;
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

  // 💰 Calcula subtotal do carrinho (sem entrega)
  double calculateSubtotal() {
    return _items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  // 🚚 Calcula taxa de entrega de um restaurante específico (dinâmica ou fixa)
  /// 
  /// Prioridade:
  /// 1. Se taxa dinâmica está ativada → usa faixa correspondente
  /// 2. Se não → usa sistema antigo (customerDeliveryFee)
  /// 3. Se não → usa taxa padrão (deliveryFee)
  double calculateRestaurantDeliveryFee(
    RestaurantModel restaurant,
    double restaurantSubtotal,
  ) {
    // ✅ 1. TAXA DINÂMICA (NOVA!)
    if (restaurant.dynamicDeliveryFee?.enabled == true) {
      final tiers = restaurant.dynamicDeliveryFee!.tiers;

      // Encontra a faixa que corresponde ao valor do pedido
      final matchedTier = tiers.firstWhere(
        (tier) => tier.matches(restaurantSubtotal),
        orElse: () => DeliveryFeeTier(
          minValue: 0,
          customerPays: restaurant.deliveryFee,
          // subsidy é calculado, não passado!
        ),
      );

      debugPrint(
          '🎯 [TAXA DINÂMICA] ${restaurant.name} - Subtotal: R\$ ${restaurantSubtotal.toStringAsFixed(2)}');
      debugPrint(
          '   Faixa: R\$ ${matchedTier.minValue} - ${matchedTier.maxValue ?? "∞"}');
      debugPrint(
          '   Cliente paga: R\$ ${matchedTier.customerPays.toStringAsFixed(2)}');

      return matchedTier.customerPays;
    }

    // ❌ 2. SISTEMA ANTIGO (compatibilidade)
    if (restaurant.customerDeliveryFee != null &&
        restaurant.customerDeliveryFee! < restaurant.deliveryFee) {
      debugPrint(
          '📦 [TAXA PARCIAL] ${restaurant.name} - Cliente paga: R\$ ${restaurant.customerDeliveryFee}');
      return restaurant.customerDeliveryFee!;
    }

    // ❌ 3. TAXA PADRÃO
    debugPrint(
        '📦 [TAXA PADRÃO] ${restaurant.name} - Cliente paga: R\$ ${restaurant.deliveryFee}');
    return restaurant.deliveryFee;
  }

  // 🚚 Calcula SOMA de todas as taxas de entrega (múltiplos restaurantes)
  /// 
  /// CRÍTICO: Quando há produtos de diferentes restaurantes,
  /// cada um tem sua taxa de entrega, então SOMA todas as taxas!
  double calculateTotalDeliveryFee(
      Map<String, RestaurantModel> restaurantsMap) {
    double totalDeliveryFee = 0.0;

    for (var entry in itemsByRestaurant.entries) {
      final restaurantId = entry.key;
      final restaurant = restaurantsMap[restaurantId];

      if (restaurant != null) {
        final restaurantSubtotal = getRestaurantSubtotal(restaurantId);
        final fee =
            calculateRestaurantDeliveryFee(restaurant, restaurantSubtotal);
        totalDeliveryFee += fee;

        debugPrint(
            '🚚 [SOMA TAXA] ${restaurant.name}: R\$ ${fee.toStringAsFixed(2)}');
      }
    }

    debugPrint(
        '🚚 [TOTAL ENTREGA] R\$ ${totalDeliveryFee.toStringAsFixed(2)} (${itemsByRestaurant.length} restaurantes)');
    return totalDeliveryFee;
  }

  // 💰 Calcula quanto o restaurante subsidia
  /// 
  /// ✅ CRÍTICO: Subsídio é SEMPRE CALCULADO, nunca lido do banco!
  /// Exemplo: taxa real = R$ 5, cliente paga R$ 3
  /// subsídio = 5 - 3 = R$ 2 (restaurante paga a diferença)
  double calculateRestaurantSubsidy(
    RestaurantModel restaurant,
    double restaurantSubtotal,
  ) {
    final customerPays =
        calculateRestaurantDeliveryFee(restaurant, restaurantSubtotal);
    final realDeliveryFee = restaurant.deliveryFee;

    // ✅ SEMPRE calcula: taxa real - taxa que cliente paga
    final subsidy = realDeliveryFee - customerPays;
    return subsidy > 0 ? subsidy : 0;
  }

  // 💰 Calcula total que cliente paga (subtotal + entregas)
  double calculateTotal(Map<String, RestaurantModel> restaurantsMap) {
    final subtotal = calculateSubtotal();
    final deliveryFee = calculateTotalDeliveryFee(restaurantsMap);

    return subtotal + deliveryFee;
  }

  // 📊 Verifica quanto falta para frete grátis em um restaurante
  /// Retorna null se não houver próxima faixa ou se já estiver grátis
  Map<String, dynamic>? getFreeShippingProgress(
    RestaurantModel restaurant,
    double restaurantSubtotal,
  ) {
    // Só funciona com taxa dinâmica
    if (restaurant.dynamicDeliveryFee?.enabled != true) {
      return null;
    }

    final tiers = restaurant.dynamicDeliveryFee!.tiers;
    final currentFee =
        calculateRestaurantDeliveryFee(restaurant, restaurantSubtotal);

    // Se já está grátis, não mostra progresso
    if (currentFee == 0) {
      return null;
    }

    // Procura a próxima faixa com taxa menor
    DeliveryFeeTier? nextTier;
    for (var tier in tiers) {
      if (tier.minValue > restaurantSubtotal &&
          tier.customerPays < currentFee) {
        nextTier = tier;
        break;
      }
    }

    // Se não há próxima faixa com taxa menor, não mostra nada
    if (nextTier == null) {
      return null;
    }

    final needed = nextTier.minValue - restaurantSubtotal;
    final savings = currentFee - nextTier.customerPays;

    return {
      'needed': needed,
      'savings': savings,
      'nextTierMinValue': nextTier.minValue,
    };
  }
}
