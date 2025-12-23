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

  // PRODUTOS EM DESTAQUE (Comida)
  List<ProductModel> _featuredProducts = [];
  bool _featuredProductsLoading = false;
  String? _featuredProductsError;

  List<ProductModel> get featuredProducts => _featuredProducts;
  bool get featuredProductsLoading => _featuredProductsLoading;
  String? get featuredProductsError => _featuredProductsError;

  // PRODUTOS DE FARMÁCIA
  List<ProductModel> _pharmacyProducts = [];
  bool _pharmacyProductsLoading = false;
  String? _pharmacyProductsError;

  List<ProductModel> get pharmacyProducts => _pharmacyProducts;
  bool get pharmacyProductsLoading => _pharmacyProductsLoading;
  String? get pharmacyProductsError => _pharmacyProductsError;

  // PRODUTOS DE MERCADO
  List<ProductModel> _marketProducts = [];
  bool _marketProductsLoading = false;
  String? _marketProductsError;

  List<ProductModel> get marketProducts => _marketProducts;
  bool get marketProductsLoading => _marketProductsLoading;
  String? get marketProductsError => _marketProductsError;

  // COMPATIBILIDADE: Mantém randomProducts como união das 3 listas
  @Deprecated('Use featuredProducts, pharmacyProducts ou marketProducts')
  List<ProductModel> get randomProducts => [
    ..._featuredProducts,
    ..._pharmacyProducts,
    ..._marketProducts,
  ];

  @Deprecated('Use featuredProductsLoading, pharmacyProductsLoading ou marketProductsLoading')
  bool get randomProductsLoading => 
    _featuredProductsLoading || _pharmacyProductsLoading || _marketProductsLoading;

  @Deprecated('Use featuredProductsError, pharmacyProductsError ou marketProductsError')
  String? get randomProductsError =>
    _featuredProductsError ?? _pharmacyProductsError ?? _marketProductsError;

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
      // Recarrega restaurantes e produtos silenciosamente para atualizar status
      _silentRefreshRestaurants();
      _silentRefreshProducts();
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

  /// Atualiza produtos silenciosamente (sem loading)
  Future<void> _silentRefreshProducts() async {
    debugPrint('🔄 [CatalogProvider] Refresh silencioso de produtos');
    await Future.wait([
      loadFeaturedProducts(force: true),
      loadPharmacyProducts(force: true),
      loadMarketProducts(force: true),
    ]);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Produtos filtrados por categoria e busca
  @Deprecated('Use filtros específicos em cada lista')
  List<ProductModel> get filteredProducts {
    var products = randomProducts;

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

  /// Carrega produtos em destaque (Comida) da API
  Future<void> loadFeaturedProducts({bool force = false}) async {
    if (!force && _featuredProducts.isNotEmpty) {
      debugPrint('✅ [CatalogProvider] Produtos em destaque já carregados (${_featuredProducts.length} produtos)');
      return;
    }

    if (_featuredProductsLoading) return;

    debugPrint('🚀 [CatalogProvider] Carregando TODOS os produtos em destaque...');

    _featuredProductsLoading = true;
    _featuredProductsError = null;
    notifyListeners();

    try {
      final url = Uri.parse('https://api-pedeja.vercel.app/api/products/featured');

      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> productsJson = data['data'];
          final total = data['total'] ?? productsJson.length;
          
          debugPrint('📦 [CatalogProvider] Produtos em destaque recebidos: $total');

          final products = productsJson.map((json) => ProductModel.fromJson(json)).toList();

          // 🎲 Shuffle local (personalizado por usuário)
          products.shuffle();

          // Extrai categorias
          for (var product in products) {
            if (product.category != null && product.category!.isNotEmpty) {
              _availableCategories.add(product.category!);
            }
          }

          _featuredProducts = products;
          _featuredProductsError = null;
          debugPrint('✅ [CatalogProvider] ${_featuredProducts.length} produtos em destaque carregados e embaralhados!');
        } else {
          _featuredProductsError = 'API retornou success=false';
        }
      } else {
        _featuredProductsError = 'Erro ao carregar: ${response.statusCode}';
      }
    } catch (error) {
      debugPrint('❌ [CatalogProvider] Erro produtos em destaque: $error');
      _featuredProductsError = 'Erro de conexão: $error';
    } finally {
      _featuredProductsLoading = false;
      notifyListeners();
    }
  }

  /// Carrega produtos de farmácia da API
  Future<void> loadPharmacyProducts({bool force = false}) async {
    if (!force && _pharmacyProducts.isNotEmpty) {
      debugPrint('✅ [CatalogProvider] Produtos de farmácia já carregados (${_pharmacyProducts.length} produtos)');
      return;
    }

    if (_pharmacyProductsLoading) return;

    debugPrint('🚀 [CatalogProvider] Carregando TODOS os produtos de farmácia...');

    _pharmacyProductsLoading = true;
    _pharmacyProductsError = null;
    notifyListeners();

    try {
      final url = Uri.parse('https://api-pedeja.vercel.app/api/products/pharmacy');

      debugPrint('📡 [CatalogProvider] URL Farmácia: $url');

      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final total = data['total'] ?? 0;
        debugPrint('🔍 [Backend Response Farmácia] success: ${data['success']}, total: $total');

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> productsJson = data['data'];
          
          debugPrint('📦 [CatalogProvider] Produtos de farmácia recebidos: ${productsJson.length}');

          final products = productsJson.map((json) => ProductModel.fromJson(json)).toList();

          // 🎲 Shuffle local (personalizado por usuário)
          products.shuffle();

          // Extrai categorias
          for (var product in products) {
            if (product.category != null && product.category!.isNotEmpty) {
              _availableCategories.add(product.category!);
            }
          }

          _pharmacyProducts = products;
          _pharmacyProductsError = null;
          debugPrint('✅ [CatalogProvider] ${_pharmacyProducts.length} produtos de farmácia carregados e embaralhados!');
        } else {
          _pharmacyProductsError = 'API retornou success=false';
        }
      } else {
        _pharmacyProductsError = 'Erro ao carregar: ${response.statusCode}';
      }
    } catch (error) {
      debugPrint('❌ [CatalogProvider] Erro produtos de farmácia: $error');
      _pharmacyProductsError = 'Erro de conexão: $error';
    } finally {
      _pharmacyProductsLoading = false;
      notifyListeners();
    }
  }

  /// Carrega produtos de mercado da API
  Future<void> loadMarketProducts({bool force = false}) async {
    if (!force && _marketProducts.isNotEmpty) {
      debugPrint('✅ [CatalogProvider] Produtos de mercado já carregados (${_marketProducts.length} produtos)');
      return;
    }

    if (_marketProductsLoading) return;

    debugPrint('🚀 [CatalogProvider] Carregando TODOS os produtos de mercado...');

    _marketProductsLoading = true;
    _marketProductsError = null;
    notifyListeners();

    try {
      final url = Uri.parse('https://api-pedeja.vercel.app/api/products/market');

      debugPrint('📡 [CatalogProvider] URL Mercado: $url');

      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final total = data['total'] ?? 0;
        debugPrint('🔍 [Backend Response Mercado] success: ${data['success']}, total: $total');

        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> productsJson = data['data'];
          
          debugPrint('📦 [CatalogProvider] Produtos de mercado recebidos: ${productsJson.length}');

          final products = productsJson.map((json) => ProductModel.fromJson(json)).toList();

          // 🎲 Shuffle local (personalizado por usuário)
          products.shuffle();

          // Extrai categorias
          for (var product in products) {
            if (product.category != null && product.category!.isNotEmpty) {
              _availableCategories.add(product.category!);
            }
          }

          _marketProducts = products;
          _marketProductsError = null;
          debugPrint('✅ [CatalogProvider] ${_marketProducts.length} produtos de mercado carregados e embaralhados!');
        } else {
          _marketProductsError = 'API retornou success=false';
        }
      } else {
        _marketProductsError = 'Erro ao carregar: ${response.statusCode}';
      }
    } catch (error) {
      debugPrint('❌ [CatalogProvider] Erro produtos de mercado: $error');
      _marketProductsError = 'Erro de conexão: $error';
    } finally {
      _marketProductsLoading = false;
      notifyListeners();
    }
  }

  /// COMPATIBILIDADE: Mantém método antigo mas chama os 3 novos
  @Deprecated('Use loadFeaturedProducts, loadPharmacyProducts e loadMarketProducts')
  Future<void> loadRandomProducts({bool force = false}) async {
    await Future.wait([
      loadFeaturedProducts(force: force),
      loadPharmacyProducts(force: force),
      loadMarketProducts(force: force),
    ]);
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