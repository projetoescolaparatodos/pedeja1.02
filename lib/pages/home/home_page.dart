import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/catalog_provider.dart';
import '../../models/restaurant_model.dart';
import '../../widgets/common/restaurant_card.dart';
import '../../widgets/common/product_card.dart';
import '../categories/categories_page.dart';
import '../restaurant/restaurant_detail_page.dart';
import '../../state/cart_state.dart';
import '../cart/cart_page.dart';
import '../profile/complete_profile_page.dart';
import '../orders/orders_page.dart';
import '../auth/login_page.dart';
import '../../core/services/operating_hours_service.dart';
import '../../state/auth_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _promoPageController = PageController();
  
  String _searchQuery = '';
  bool _showLogo = true;
  Timer? _promoAutoPlayTimer;
  
  late Future<List<Map<String, dynamic>>> _promotionsFuture;

  // Categorias de farmácia/mercado para separação
  static const List<String> _pharmacyMarketCategories = [
    'remédio',
    'remedio',
    'farmácia',
    'farmacia',
    'mercearia',
    'higiene',
    'cuidados pessoais',
    'beleza',
    'limpeza',
    'bebê',
    'bebe',
    'pet shop',
    'saúde',
    'saude',
  ];

  @override
  void initState() {
    super.initState();
    _promotionsFuture = _fetchPromotions();
    
    // Auto-scroll para o carousel a cada 5 segundos
    _promoAutoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_promoPageController.hasClients) {
        int nextPage = (_promoPageController.page?.toInt() ?? 0) + 1;
        _promotionsFuture.then((promos) {
          if (nextPage >= promos.length) nextPage = 0;
          _promoPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        });
      }
    });

    // Listener para esconder/mostrar logo baseado no scroll
    _scrollController.addListener(() {
      setState(() {
        _showLogo = _scrollController.offset < 380;
      });
    });

    // Carregar dados do catálogo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalog = context.read<CatalogProvider>();
      catalog.loadRestaurants();
      catalog.loadRandomProducts(); // Carrega produtos da API
    });
  }

  /// 🔄 Método para pull-to-refresh
  Future<void> _onRefresh() async {
    debugPrint('🔄 [HomePage] Pull-to-refresh iniciado');
    
    // Atualiza horários de funcionamento
    final hoursUpdated = await OperatingHoursService.refreshOperatingHours(force: true);
    debugPrint('🕒 [HomePage] Horários ${hoursUpdated ? "atualizados" : "não atualizados"}');
    
    // Recarrega dados do catálogo
    if (mounted) {
      final catalog = context.read<CatalogProvider>();
      await Future.wait([
        catalog.loadRestaurants(),
        catalog.loadRandomProducts(force: true),
      ]);
    }
    
    // Recarrega promoções
    setState(() {
      _promotionsFuture = _fetchPromotions();
    });
    
    debugPrint('✅ [HomePage] Refresh completo');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _promoPageController.dispose();
    _promoAutoPlayTimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchPromotions() async {
    try {
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/promotions/active'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Erro ao carregar promoções: $e');
      return [];
    }
  }

  List<RestaurantModel> _filterRestaurants(List<RestaurantModel> restaurants) {
    if (_searchQuery.isEmpty) return restaurants;
    return restaurants.where((r) {
      final query = _searchQuery.toLowerCase();
      return r.name.toLowerCase().contains(query) ||
          r.address.toLowerCase().contains(query) ||
          (r.email?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D3B3B),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFFE39110),
              backgroundColor: const Color(0xFF022E28),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ), // ✅ Permite pull-to-refresh
                slivers: [
                // Promotional Carousel
                SliverToBoxAdapter(
                  child: _buildPromotionalCarousel(),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
                
                // Search Bar
                SliverToBoxAdapter(
                  child: _buildSearchBar(),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
                
                // Restaurant Section
                SliverToBoxAdapter(
                  child: _buildRestaurantSection(),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
                
                // Produtos em Destaque
                SliverToBoxAdapter(
                  child: _buildProdutosEmDestaque(),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 8), // ✅ Reduzido de 16 para 8
                ),
                
                // Farmácia & Mercado
                SliverToBoxAdapter(
                  child: _buildFarmaciaEMercado(),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
          ),
          
          // Header overlay
          _buildHeader(),
        ],
      ),
    );
  }

  Widget _buildPromotionalCarousel() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _promotionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 380,
            decoration: const BoxDecoration(
              color: Color(0xFF022E28),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE39110),
              ),
            ),
          );
        }

        final promotions = snapshot.data ?? [];
        if (promotions.isEmpty) {
          return Container(
            height: 380,
            decoration: const BoxDecoration(
              color: Color(0xFF022E28),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: const Center(
              child: Text(
                'Nenhuma promoção disponível',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return SizedBox(
          height: 380,
          child: Stack(
            children: [
              PageView.builder(
                controller: _promoPageController,
                itemCount: promotions.length,
                itemBuilder: (context, index) {
                  final promo = promotions[index];
                  String imageUrl = promo['imageUrl'] ?? '';
                  
                  if (!imageUrl.startsWith('http')) {
                    imageUrl = 'https://api-pedeja.vercel.app$imageUrl';
                  }

                  return ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF022E28),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE39110),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF022E28),
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.white54,
                              size: 64,
                            ),
                          ),
                        ),
                        
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.black.withValues(alpha: 0.55),
                              ],
                            ),
                          ),
                        ),
                        
                        // Texto centralizado
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                promo['title'] ?? '',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.8),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                promo['description'] ?? '',
                                style: TextStyle(
                                  color: const Color(0xFFFFD27A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Dot indicators
              Positioned(
                bottom: 80,
                left: 16,
                child: Row(
                  children: List.generate(
                    promotions.length,
                    (index) => AnimatedBuilder(
                      animation: _promoPageController,
                      builder: (context, child) {
                        double selectedness = 1.0;
                        if (_promoPageController.hasClients) {
                          selectedness = ((_promoPageController.page ?? 0) - index).abs();
                          selectedness = (1.0 - selectedness).clamp(0.0, 1.0);
                        }
                        
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: selectedness > 0.5 ? 16 : 16,
                          height: 4,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: selectedness > 0.5
                                ? const Color(0xFFE39110)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF033D35),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFFE39110),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'O que você quer comer hoje?',
            hintStyle: const TextStyle(
              color: Color(0x9AFFFFFF),
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFFE39110),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: Color(0xFFE39110),
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Restaurantes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Consumer<CatalogProvider>(
          builder: (context, catalog, child) {
            if (catalog.restaurantsLoading) {
              return const SizedBox(
                height: 250,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFE39110),
                  ),
                ),
              );
            }

            if (catalog.restaurantsError != null) {
              return SizedBox(
                height: 250,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Erro ao carregar restaurantes',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => catalog.loadRestaurants(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE39110),
                        ),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final filteredRestaurants = _filterRestaurants(catalog.restaurants);

            if (filteredRestaurants.isEmpty) {
              return const SizedBox(
                height: 250,
                child: Center(
                  child: Text(
                    'Nenhum restaurante encontrado',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              );
            }

            return SizedBox(
              height: 250,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: filteredRestaurants.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final restaurant = filteredRestaurants[index];
                  
                  return SizedBox(
                    width: 260,
                    child: RestaurantCard(
                      restaurant: restaurant,
                      width: 260,
                      height: 160,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RestaurantDetailPage(
                              restaurant: restaurant,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProdutosEmDestaque() {
    return Consumer<CatalogProvider>(
      builder: (context, catalog, child) {
        // FILTRA APENAS PRODUTOS DE COMIDA (exclui farmácia/mercado)
        final foodProducts = catalog.randomProducts.where((product) {
          final category = product.category?.toLowerCase() ?? '';
          
          // Retorna TRUE se NÃO for farmácia/mercado
          return !_pharmacyMarketCategories.any((pharmaCategory) => 
            category.contains(pharmaCategory)
          );
        }).toList();

        // Aplica filtro de categoria selecionada
        final filteredProducts = catalog.selectedCategory == 'Todos'
            ? foodProducts
            : foodProducts.where((p) => p.category == catalog.selectedCategory).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Produtos em Destaque',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Filtros de categoria dinâmicos
            if (catalog.availableCategories.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: catalog.availableCategories.length,
                  itemBuilder: (context, index) {
                    final category = catalog.availableCategories[index];
                    final isSelected = catalog.selectedCategory == category;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(category),
                        onSelected: (selected) {
                          catalog.selectCategory(category);
                        },
                        backgroundColor: const Color(0xFF033D35),
                        selectedColor: const Color(0xFF74241F),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFE39110),
                          fontWeight: FontWeight.w500,
                        ),
                        side: const BorderSide(
                          color: Color(0xFFE39110),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Loading
            if (catalog.randomProductsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE39110),
                  ),
                ),
              )
            
            // Error
            else if (catalog.randomProductsError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Color(0xFFE39110),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        catalog.randomProductsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          catalog.loadRandomProducts(force: true);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar Novamente'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF74241F),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            
            // Carrossel de produtos de comida
            else if (filteredProducts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Nenhum produto encontrado',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ),
              )
            else
              _buildProductCarousel(filteredProducts, catalog),
          ],
        );
      },
    );
  }

  Widget _buildFarmaciaEMercado() {
    return Consumer<CatalogProvider>(
      builder: (context, catalog, child) {
        // FILTRA APENAS PRODUTOS DE FARMÁCIA/MERCADO
        final pharmacyProducts = catalog.randomProducts.where((product) {
          final category = product.category?.toLowerCase() ?? '';
          
          // Retorna TRUE se FOR farmácia/mercado
          return _pharmacyMarketCategories.any((pharmaCategory) => 
            category.contains(pharmaCategory)
          );
        }).toList();

        // Se não tem produtos dessa categoria, não mostra seção
        if (pharmacyProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Aplica filtro de categoria selecionada
        final filteredProducts = catalog.selectedCategory == 'Todos'
            ? pharmacyProducts
            : pharmacyProducts.where((p) => p.category == catalog.selectedCategory).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título com ícone
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: const [
                  Icon(Icons.local_pharmacy, color: Color(0xFFE39110), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Farmácia & Mercado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filtros de categoria dinâmicos
            if (catalog.availableCategories.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: catalog.availableCategories.length,
                  itemBuilder: (context, index) {
                    final category = catalog.availableCategories[index];
                    final isSelected = catalog.selectedCategory == category;

                    // Mostra apenas categorias de farmácia
                    final isFarmaciaCategory = _pharmacyMarketCategories.any(
                      (pharma) => category.toLowerCase().contains(pharma)
                    );

                    if (!isFarmaciaCategory && category != 'Todos') {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(category),
                        onSelected: (selected) {
                          catalog.selectCategory(category);
                        },
                        backgroundColor: const Color(0xFF033D35),
                        selectedColor: const Color(0xFF74241F),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFE39110),
                          fontWeight: FontWeight.w500,
                        ),
                        side: const BorderSide(
                          color: Color(0xFFE39110),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Loading
            if (catalog.randomProductsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE39110),
                  ),
                ),
              )
            
            // Error
            else if (catalog.randomProductsError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Color(0xFFE39110),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        catalog.randomProductsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              )
            
            // Carrossel de produtos de farmácia
            else if (filteredProducts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Nenhum produto encontrado',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ),
              )
            else
              _buildProductCarousel(filteredProducts, catalog),
          ],
        );
      },
    );
  }

  /// Carrossel de produtos com 6 produtos por página (2 colunas x 3 linhas)
  Widget _buildProductCarousel(List<dynamic> products, CatalogProvider catalog) {
    const int productsPerPage = 6; // 2 colunas x 3 linhas
    final int totalPages = (products.length / productsPerPage).ceil();
    
    // Se tiver poucos produtos (até 6), mostra grid normal sem carrossel
    if (totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final restaurantName = catalog.getRestaurantName(product.restaurantId);
            
            final restaurant = catalog.restaurants.firstWhere(
              (r) => r.id == product.restaurantId,
              orElse: () => RestaurantModel(
                id: '',
                name: '',
                address: '',
                isActive: true,
                approved: true,
                paymentStatus: 'adimplente',
              ),
            );
            return ProductCard(
              product: product,
              restaurantName: restaurantName,
              hero: true,
              heroTag: 'product_${product.id}',
              isRestaurantOpen: restaurant.isOpen,
            );
          },
        ),
      );
    }

    // Cria páginas com até 6 produtos cada
    final List<List<dynamic>> pages = [];
    for (int i = 0; i < products.length; i += productsPerPage) {
      final end = (i + productsPerPage < products.length) 
          ? i + productsPerPage 
          : products.length;
      pages.add(products.sublist(i, end));
    }

    return StatefulBuilder(
      builder: (context, setState) {
        int currentPage = 0;
        
        return Column(
          children: [
            SizedBox(
              height: 840, // ✅ Reduzido para 840
              child: PageView.builder(
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() {
                    currentPage = index;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final pageProducts = pages[pageIndex];
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: pageProducts.length,
                      itemBuilder: (context, index) {
                        final product = pageProducts[index];
                        final restaurantName = catalog.getRestaurantName(product.restaurantId);
                        
                        final restaurant = catalog.restaurants.firstWhere(
                          (r) => r.id == product.restaurantId,
                          orElse: () => RestaurantModel(
                            id: '',
                            name: '',
                            address: '',
                            isActive: true,
                            approved: true,
                            paymentStatus: 'adimplente',
                          ),
                        );
                        return ProductCard(
                          product: product,
                          restaurantName: restaurantName,
                          hero: true,
                          heroTag: 'product_page${pageIndex}_${product.id}',
                          isRestaurantOpen: restaurant.isOpen,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 8), // ✅ Reduzido de 16 para 8
            
            // Indicadores de página (bolinhas)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: currentPage == index ? 12 : 8,
                  height: currentPage == index ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentPage == index
                        ? const Color(0xFF74241F) // Vinho vermelho quando ativo
                        : const Color(0xFFE39110).withValues(alpha: 0.3), // Dourado transparente
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu button
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(
                      Icons.menu,
                      color: Color(0xFFE39110),
                    ),
                    onPressed: () {
                      Scaffold.of(ctx).openDrawer();
                    },
                  ),
                ),
              ),
              
              // Logo ou botão "Todos os Parceiros"
              Expanded(
                child: Center(
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _showLogo
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Image.asset(
                      'assets/images/logo-pede-ja.png',
                      width: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'PedeJá',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    secondChild: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoriesPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.restaurant_menu,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Todos os Parceiros',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF74241F),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: const BorderSide(
                            color: Color(0xFFE39110),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Cart button com badge
              Consumer<CartState>(
                builder: (context, cart, child) {
                  return badges.Badge(
                    showBadge: cart.itemCount > 0,
                    badgeContent: Text(
                      cart.itemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    badgeStyle: const badges.BadgeStyle(
                      badgeColor: Color(0xFFE39110),
                      elevation: 3,
                      padding: EdgeInsets.all(6),
                    ),
                    position: badges.BadgePosition.topEnd(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.shopping_cart,
                          color: Color(0xFFE39110),
                        ),
                        onPressed: () {
                          CartPage.show(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 👋 Retorna saudação baseada no horário de Belém (UTC-3)
  String _getGreeting() {
    final belemTime = OperatingHoursService.getBelemTime();
    final hour = belemTime.hour;
    
    if (hour >= 6 && hour < 12) {
      return 'Bom dia!';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde!';
    } else {
      return 'Boa noite!';
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF0D3B3B),
        child: SafeArea(
          child: Column(
            children: [
              // Header do drawer
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF022E28),
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFE39110),
                      width: 2,
                    ),
                  ),
                ),
                child: Consumer<AuthState>(
                  builder: (context, authState, child) {
                    // Pega o nome do usuário (prioriza displayName, depois nome dos userData)
                    final userName = authState.currentUser?.displayName ?? 
                                     authState.userData?['name'] ?? 
                                     authState.userData?['displayName'] ?? 
                                     'Usuário';
                    
                    return Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFFE39110),
                          child: Icon(
                            Icons.person,
                            color: Color(0xFF0D3B3B),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getGreeting(),
                                style: const TextStyle(
                                  color: Color(0xFFE39110),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    );
                  },
                ),
              ),
              
              // Menu items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.home,
                      title: 'Home',
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      icon: Icons.search,
                      title: 'Buscar',
                      onTap: () {},
                    ),
                    _buildDrawerItem(
                      icon: Icons.favorite,
                      title: 'Favoritos',
                      onTap: () {},
                    ),
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: 'Editar Perfil',
                      onTap: () async {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompleteProfilePage(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.receipt_long,
                      title: 'Meus Pedidos',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrdersPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(color: Color(0xFFE39110)),
                    _buildDrawerItem(
                      icon: Icons.settings,
                      title: 'Configurações',
                      onTap: () {},
                    ),
                    _buildDrawerItem(
                      icon: Icons.help,
                      title: 'Ajuda',
                      onTap: () {},
                    ),
                    _buildDrawerItem(
                      icon: Icons.logout,
                      title: 'Sair',
                      textColor: Colors.red,
                      onTap: () async {
                        // Mostrar diálogo de confirmação
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text(
                              'Sair da Conta',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: const Text(
                              'Deseja realmente sair da sua conta?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Sair'),
                              ),
                            ],
                          ),
                        );

                        if (shouldLogout == true && mounted) {
                          // Fechar drawer
                          Navigator.pop(context);
                          
                          // Fazer logout
                          final authState = Provider.of<AuthState>(context, listen: false);
                          await authState.signOut();
                          
                          // Navegar para página de login
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                              (route) => false,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: textColor ?? const Color(0xFFE39110),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      hoverColor: const Color(0xFFE39110).withValues(alpha: 0.1),
    );
  }
}