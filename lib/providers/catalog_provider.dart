import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/restaurant_model.dart';
import '../models/product_model.dart';

class CatalogProvider extends ChangeNotifier {
  Timer? _refreshTimer;
  
  // RESTAURANTES
  List<RestaurantModel> _restaurants = [];
  bool _restaurantsLoading = false;
  String? _restaurantsError;

  List<RestaurantModel> get restaurants => _restaurants;
  bool get restaurantsLoading => _restaurantsLoading;
  String? get restaurantsError => _restaurantsError;

  // PRODUTOS ALEATÓRIOS (Home)
  List<ProductModel> _randomProducts = [];
  bool _randomProductsLoading = false;
  String? _randomProductsError;

  List<ProductModel> get randomProducts => _randomProducts;
  bool get randomProductsLoading => _randomProductsLoading;
  String? get randomProductsError => _randomProductsError;

  // FILTROS
  String _selectedCategory = 'Todos';
  final Set<String> _availableCategories = {'Todos'};
  String _searchQuery = '';

  String get selectedCategory => _selectedCategory;
  List<String> get availableCategories => _availableCategories.toList();
  String get searchQuery => _searchQuery;

  CatalogProvider() {
    // Inicia o timer de refresh automático a cada 5 minutos
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      debugPrint('🔄 [CatalogProvider] Auto-refresh ativado (5min)');
      // Recarrega restaurantes silenciosamente para atualizar status
      _silentRefreshRestaurants();
    });
  }

  /// Atualiza restaurantes sem mostrar loading (para não interferir na UX)
  Future<void> _silentRefreshRestaurants() async {
    try {
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/restaurants'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _restaurants = data.map((json) => RestaurantModel.fromJson(json)).toList();
        notifyListeners(); // Notifica listeners para atualizar UI
        debugPrint('✅ [CatalogProvider] Restaurantes atualizados automaticamente');
      }
    } catch (error) {
      debugPrint('❌ [CatalogProvider] Erro no auto-refresh: $error');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Produtos filtrados por categoria e busca
  List<ProductModel> get filteredProducts {
    var products = _randomProducts;

    // Filtro por categoria
    if (_selectedCategory != 'Todos') {
      products = products
          .where((p) => p.category == _selectedCategory)
          .toList();
    }

    // Filtro por busca
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      products = products.where((p) {
        final name = p.name.toLowerCase();
        final description = (p.description ?? '').toLowerCase();
        final category = (p.category ?? '').toLowerCase();

        return name.contains(query) ||
            description.contains(query) ||
            category.contains(query);
      }).toList();
    }

    return products;
  }

  Future<void> loadRestaurants() async {
    if (_restaurantsLoading) return;

    _restaurantsLoading = true;
    _restaurantsError = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/restaurants'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _restaurants = data.map((json) => RestaurantModel.fromJson(json)).toList();
        _restaurantsError = null;
      } else {
        _restaurantsError = 'Erro ao carregar restaurantes: ${response.statusCode}';
      }
    } catch (error) {
      _restaurantsError = 'Erro de conexão: $error';
    } finally {
      _restaurantsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRestaurants() async {
    _restaurants.clear();
    await loadRestaurants();
  }

  /// Carrega produtos aleatórios da API
  Future<void> loadRandomProducts({bool force = false}) async {
    // Evita recarregar se já tem dados
    if (!force && _randomProducts.isNotEmpty) {
      debugPrint('✅ [CatalogProvider] Produtos já carregados');
      return;
    }

    if (_randomProductsLoading) return;

    debugPrint('🚀 [CatalogProvider] Carregando produtos da API...');

    _randomProductsLoading = true;
    _randomProductsError = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/products/all'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> productsJson = data['data'];

          debugPrint('📦 [CatalogProvider] Recebidos ${productsJson.length} produtos');

          // Converte JSON para ProductModel
          final products = productsJson
              .map((json) => ProductModel.fromJson(json))
              .toList();

          // Extrai categorias únicas
          _availableCategories.clear();
          _availableCategories.add('Todos');
          for (var product in products) {
            if (product.category != null && product.category!.isNotEmpty) {
              _availableCategories.add(product.category!);
            }
          }

          _randomProducts = products;
          _randomProductsError = null;

          debugPrint('✅ [CatalogProvider] ${products.length} produtos carregados!');
          debugPrint('📂 [CatalogProvider] Categorias: ${_availableCategories.join(", ")}');
        } else {
          _randomProductsError = 'API retornou success=false';
        }
      } else {
        _randomProductsError = 'Erro ao carregar produtos: ${response.statusCode}';
      }
    } catch (error) {
      debugPrint('❌ [CatalogProvider] Erro ao carregar produtos: $error');
      _randomProductsError = 'Erro de conexão: $error';
    } finally {
      _randomProductsLoading = false;
      notifyListeners();
    }
  }

  /// Seleciona categoria para filtro
  void selectCategory(String category) {
    _selectedCategory = category;
    debugPrint('🔍 [CatalogProvider] Categoria selecionada: $category');
    notifyListeners();
  }

  /// Define query de busca
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    debugPrint('🔍 [CatalogProvider] Busca: $_searchQuery');
    notifyListeners();
  }

  /// Limpa filtros
  void clearFilters() {
    _selectedCategory = 'Todos';
    _searchQuery = '';
    notifyListeners();
  }

  /// Atualiza produtos
  Future<void> refreshProducts() async {
    await loadRandomProducts(force: true);
  }

  /// Busca nome do restaurante por ID
  String? getRestaurantName(String restaurantId) {
    try {
      final restaurant = _restaurants.firstWhere(
        (r) => r.id == restaurantId,
      );
      return restaurant.name;
    } catch (e) {
      return null;
    }
  }
}