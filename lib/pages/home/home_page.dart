import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../providers/catalog_provider.dart';
import '../../models/restaurant_model.dart';
import '../../models/promotion_model.dart';
import '../../widgets/common/restaurant_card.dart';
import '../../widgets/common/product_card.dart';
import '../../widgets/home/promotional_carousel_item.dart';
import '../categories/categories_page.dart';
import '../restaurant/restaurant_detail_page.dart';
import '../product/product_detail_page.dart'; // ✅ Import para navegação manual
import '../../state/cart_state.dart';
import '../cart/cart_page.dart';
import '../profile/complete_profile_page.dart';
import '../orders/orders_page.dart';
import '../auth/login_page.dart';
import '../settings/settings_page.dart';
import '../../core/services/operating_hours_service.dart';
import '../../state/auth_state.dart';
import '../../core/cache/video_cache_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _promoPageController = PageController();
  final Map<int, GlobalKey<PromotionalCarouselItemState>> _carouselKeys = {}; // ✅ Keys para controlar vídeos
  final GlobalKey _searchFieldKey = GlobalKey(); // ✅ Key para scroll até o campo de busca
  
  String _searchQuery = '';
  bool _showLogo = true;
  Timer? _promoAutoPlayTimer;
  
  late Future<List<PromotionModel>> _promotionsFuture;
  int _currentPromoIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ✅ Observar ciclo de vida
    _promotionsFuture = _fetchPromotions();
    
    // ⏱️ Timer dinâmico (será cancelado e recriado quando vídeos terminarem)
    _startAutoPlayTimer();

    // ✅ Listener para controlar exibição do logo
    _scrollController.addListener(() {
      setState(() {
        _showLogo = _scrollController.offset < 380;
      });
    });

    // ⚡ Carregar dados do catálogo em paralelo
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('🚀 [HomePage] Iniciando carregamento das 3 seções...');
      final catalog = context.read<CatalogProvider>();
      
      try {
        // Carregar 3 seções em paralelo para economizar tempo
        await Future.wait([
          catalog.loadRestaurants(),
          catalog.loadFeaturedProducts(),
          catalog.loadPharmacyProducts(),
          catalog.loadMarketProducts(),
        ]);
        debugPrint('✅ [HomePage] 3 seções carregadas com sucesso!');
      } catch (e) {
        debugPrint('❌ [HomePage] Erro ao carregar seções: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ✅ Remover observador
    _pauseAllVideos(); // ✅ Pausar vídeos ao sair da página
    _promoAutoPlayTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _promoPageController.dispose();
    super.dispose();
  }

  /// ✅ Detectar quando app vai para background OU quando navega para outra tela
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('🔄 [HomePage] App lifecycle mudou: $state');
    
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // App foi para background OU perdeu foco (navegação interna)
      debugPrint('⏸️ [HomePage] App pausado/inativo - pausando vídeos');
      _pauseAllVideos();
      _promoAutoPlayTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // App voltou para foreground
      debugPrint('▶️ [HomePage] App retomado - iniciando timer');
      _startAutoPlayTimer();
    }
  }

  /// ✅ Inicia timer de autoplay (mínimo 45 segundos)
  void _startAutoPlayTimer() {
    _promoAutoPlayTimer?.cancel();
    _promoAutoPlayTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (_promoPageController.hasClients) {
        _promotionsFuture.then((promos) {
          if (promos.isEmpty) return;
          
          final nextPage = (_currentPromoIndex + 1) % promos.length;
          _promoPageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  /// ✅ Pausa todos os vídeos
  void _pauseAllVideos() {
    for (var key in _carouselKeys.values) {
      key.currentState?.pauseVideo();
    }
  }

  /// ✅ Callback quando vídeo termina
  void _onVideoEnd() {
    debugPrint('🏁 [HomePage] Vídeo terminou, avançando para próximo slide...');
    _promoAutoPlayTimer?.cancel();
    
    // Avançar para próximo slide
    _promotionsFuture.then((promos) {
      if (promos.isEmpty) return;
      
      final nextPage = (_currentPromoIndex + 1) % promos.length;
      _promoPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      
      // Reiniciar timer
      _startAutoPlayTimer();
    });
  }

  /// 🔄 Método para pull-to-refresh
  Future<void> _onRefresh() async {
    debugPrint('🔄 [HomePage] Pull-to-refresh iniciado');
    
    // Atualiza horários de funcionamento
    final hoursUpdated = await OperatingHoursService.refreshOperatingHours(force: true);
    debugPrint('🕒 [HomePage] Horários ${hoursUpdated ? "atualizados" : "não atualizados"}');
    
    // Recarrega dados do catálogo (3 seções em paralelo)
    if (mounted) {
      final catalog = context.read<CatalogProvider>();
      await Future.wait([
        catalog.loadRestaurants(),
        catalog.loadFeaturedProducts(force: true),
        catalog.loadPharmacyProducts(force: true),
        catalog.loadMarketProducts(force: true),
      ]);
    }
    
    // Recarrega promoções
    setState(() {
      _promotionsFuture = _fetchPromotions();
    });
    
    debugPrint('✅ [HomePage] Refresh completo');
  }

  Future<List<PromotionModel>> _fetchPromotions() async {
    try {
      debugPrint('🎯 [Promotions] Buscando promoções ativas...');
      
      // ✅ Buscar diretamente do Firestore
      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('promotions')
          .where('isActive', isEqualTo: true)
          .get();

      // Filtrar promoções por data no código (não no Firestore)
      final promotions = snapshot.docs
          .map((doc) => PromotionModel.fromFirestore(doc.data(), doc.id))
          .where((promo) {
            try {
              final isInPeriod = now.isAfter(promo.startDate) && now.isBefore(promo.endDate);
              
              if (isInPeriod) {
                debugPrint('✅ [Promotion] ${promo.title} está ativa');
              } else {
                debugPrint('⏰ [Promotion] ${promo.title} fora do período');
              }
              
              return isInPeriod;
            } catch (e) {
              debugPrint('❌ [Promotion] Erro ao verificar datas: $e');
              return false;
            }
          })
          .toList();

      // Ordenar por prioridade
      promotions.sort((a, b) => b.priority.compareTo(a.priority));

      debugPrint('✅ [Promotions] ${promotions.length} promoções ativas encontradas');
      
      // 🚀 Pré-carregar vídeos em cache (não bloqueia UI)
      _precacheVideos(promotions);
      
      return promotions;
    } catch (e) {
      debugPrint('❌ [Promotions] Erro ao carregar promoções: $e');
      return [];
    }
  }

  /// 🚀 Pré-carrega vídeos em segundo plano para transições fluidas
  void _precacheVideos(List<PromotionModel> promotions) {
    for (final promo in promotions) {
      if (promo.isVideo) {
        VideoCacheManager.precacheVideo(promo.mediaUrl).then((_) {
          debugPrint('✅ [Cache] Vídeo pré-carregado: ${promo.title}');
        }).catchError((e) {
          debugPrint('⚠️ [Cache] Erro ao pré-carregar vídeo ${promo.title}: $e');
        });
      }
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

  /// ✅ Filtrar produtos em destaque pela busca
  List<dynamic> _filterFeaturedProducts(List<dynamic> products) {
    if (_searchQuery.isEmpty) return products;
    return products.where((p) {
      final query = _searchQuery.toLowerCase();
      
      // ✅ Pesquisar nos badges/tags (normalizar _ para espaço)
      final badges = p.badges as List<dynamic>? ?? [];
      final badgesText = badges
          .map((badge) => badge.toString().toLowerCase().replaceAll('_', ' '))
          .join(' ');
      
      // Normalizar query também
      final normalizedQuery = query.trim();
      
      return (p.name?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (p.description?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (p.category?.toLowerCase().contains(normalizedQuery) ?? false) ||
          badgesText.contains(normalizedQuery);
    }).toList();
  }

  /// ✅ Filtrar produtos de farmácia pela busca
  List<dynamic> _filterPharmacyProducts(List<dynamic> products) {
    if (_searchQuery.isEmpty) return products;
    return products.where((p) {
      final query = _searchQuery.toLowerCase();
      
      // ✅ Pesquisar nos badges/tags (normalizar _ para espaço)
      final badges = p.badges as List<dynamic>? ?? [];
      final badgesText = badges
          .map((badge) => badge.toString().toLowerCase().replaceAll('_', ' '))
          .join(' ');
      
      // Normalizar query também
      final normalizedQuery = query.trim();
      
      return (p.name?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (p.description?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (p.category?.toLowerCase().contains(normalizedQuery) ?? false) ||
          badgesText.contains(normalizedQuery);
    }).toList();
  }

  /// ✅ Filtrar produtos de mercado pela busca
  List<dynamic> _filterMarketProducts(List<dynamic> products) {
    if (_searchQuery.isEmpty) return products;
    return products.where((p) {
      final query = _searchQuery.toLowerCase();
      
      // ✅ Pesquisar nos badges/tags (normalizar _ para espaço)
      final badges = p.badges as List<dynamic>? ?? [];
      final badgesText = badges
          .map((badge) => badge.toString().toLowerCase().replaceAll('_', ' '))
          .join(' ');
      
      // Normalizar query também
      final normalizedQuery = query.trim();
      
      return (p.name?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (p.description?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (p.category?.toLowerCase().contains(normalizedQuery) ?? false) ||
          badgesText.contains(normalizedQuery);
    }).toList();
  }

  /// Scroll suave para o topo da página
  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  /// Scroll suave para uma seção específica (0=Destaque, 1=Farmácia, 2=Mercado)
  void _scrollToSection(int section) {
    // Estimativas de posição (ajuste conforme necessário)
    double targetOffset = 0;
    switch (section) {
      case 0: // Produtos em Destaque
        targetOffset = 900;
        break;
      case 1: // Farmácia
        targetOffset = 1600;
        break;
      case 2: // Mercado
        targetOffset = 2400;
        break;
    }
    
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
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
                  parent: ClampingScrollPhysics(),
                ), // ✅ Scroll suave com momentum/fling + pull-to-refresh
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
                  child: SizedBox(height: 32),
                ),
                
                // Farmácia
                SliverToBoxAdapter(
                  child: _buildFarmacia(),
                ),
                
                const SliverToBoxAdapter(
                  child: SizedBox(height: 32),
                ),
                
                // Mercado
                SliverToBoxAdapter(
                  child: _buildMercado(),
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
    return FutureBuilder<List<PromotionModel>>(
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
                onPageChanged: (index) {
                  setState(() {
                    _currentPromoIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final promotion = promotions[index];
                  
                  // ✅ Criar key para controlar cada item
                  if (!_carouselKeys.containsKey(index)) {
                    _carouselKeys[index] = GlobalKey<PromotionalCarouselItemState>();
                  }
                  
                  return PromotionalCarouselItem(
                    key: _carouselKeys[index],
                    promotion: promotion,
                    isActive: _currentPromoIndex == index,
                    onVideoEnd: _onVideoEnd, // ✅ Callback de fim de vídeo
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
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPromoIndex == index ? 16 : 16,
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: _currentPromoIndex == index
                            ? const Color(0xFFE39110)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
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
      key: _searchFieldKey, // ✅ Key para scroll
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
            hintText: 'Do que você precisa hoje?',
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
            'Estabelecimentos',
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

            // Se busca ativa e nenhum resultado, esconde a seção
            if (_searchQuery.isNotEmpty && filteredRestaurants.isEmpty) {
              return const SizedBox.shrink();
            }

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
                    child: RepaintBoundary(
                      child: RestaurantCard(
                        restaurant: restaurant,
                        width: 260,
                        height: 160,
                        onTap: () {
                          _pauseAllVideos(); // ✅ Pausar vídeos ao navegar
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
        // Usa a nova lista de produtos em destaque
        final featuredProducts = catalog.featuredProducts;

        // ✅ Aplica filtro de busca
        final searchFilteredProducts = _filterFeaturedProducts(featuredProducts);

        // Aplica filtro de categoria selecionada
        final filteredProducts = catalog.selectedCategory == 'Todos'
            ? searchFilteredProducts
            : searchFilteredProducts.where((p) => p.category == catalog.selectedCategory).toList();

        // Se busca ativa e nenhum resultado, esconde a seção
        if (_searchQuery.isNotEmpty && filteredProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.restaurant, color: Color(0xFFE39110), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Produtos em Destaque',
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
            if (catalog.featuredProductsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE39110),
                  ),
                ),
              )
            
            // Error
            else if (catalog.featuredProductsError != null)
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
                        catalog.featuredProductsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          catalog.loadFeaturedProducts(force: true);
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
            
            // Carrossel de produtos em destaque
            else if (filteredProducts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Color(0xFFE39110),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty 
                            ? 'Nenhum produto encontrado para "$_searchQuery"'
                            : 'Nenhum produto encontrado',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
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

  Widget _buildFarmacia() {
    return Consumer<CatalogProvider>(
      builder: (context, catalog, child) {
        // Usa a nova lista de produtos de farmácia
        final pharmacyProducts = catalog.pharmacyProducts;

        // ✅ Aplica filtro de busca
        final searchFilteredProducts = _filterPharmacyProducts(pharmacyProducts);

        // Aplica filtro de categoria selecionada
        final filteredProducts = catalog.selectedCategory == 'Todos'
            ? searchFilteredProducts
            : searchFilteredProducts.where((p) => p.category == catalog.selectedCategory).toList();

        // Se busca ativa e nenhum resultado, esconde a seção
        if (_searchQuery.isNotEmpty && filteredProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Se não tem produtos dessa categoria, não mostra seção
        if (pharmacyProducts.isEmpty && !catalog.pharmacyProductsLoading) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título com ícone
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.local_pharmacy, color: Color(0xFFE39110), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Farmácia',
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
            if (catalog.pharmacyProductsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE39110),
                  ),
                ),
              )
            
            // Error
            else if (catalog.pharmacyProductsError != null)
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
                        catalog.pharmacyProductsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          catalog.loadPharmacyProducts(force: true);
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
            
            // Carrossel de produtos de farmácia
            else if (filteredProducts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Color(0xFFE39110),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty 
                            ? 'Nenhum produto encontrado para "$_searchQuery"'
                            : 'Nenhum produto encontrado',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
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

  Widget _buildMercado() {
    return Consumer<CatalogProvider>(
      builder: (context, catalog, child) {
        // Usa a nova lista de produtos de mercado
        final marketProducts = catalog.marketProducts;

        // ✅ Aplica filtro de busca
        final searchFilteredProducts = _filterMarketProducts(marketProducts);

        // Aplica filtro de categoria selecionada
        final filteredProducts = catalog.selectedCategory == 'Todos'
            ? searchFilteredProducts
            : searchFilteredProducts.where((p) => p.category == catalog.selectedCategory).toList();

        // Se busca ativa e nenhum resultado, esconde a seção
        if (_searchQuery.isNotEmpty && filteredProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Se não tem produtos dessa categoria, não mostra seção
        if (marketProducts.isEmpty && !catalog.marketProductsLoading) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título com ícone
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.shopping_cart, color: Color(0xFFE39110), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Mercado',
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
            if (catalog.marketProductsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    color: Color(0xFFE39110),
                  ),
                ),
              )
            
            // Error
            else if (catalog.marketProductsError != null)
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
                        catalog.marketProductsError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          catalog.loadMarketProducts(force: true);
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
            
            // Carrossel de produtos de mercado
            else if (filteredProducts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Color(0xFFE39110),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty 
                            ? 'Nenhum produto encontrado para "$_searchQuery"'
                            : 'Nenhum produto encontrado',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
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
            return RepaintBoundary(
              child: ProductCard(
                product: product,
                restaurantName: restaurantName,
                hero: true,
                heroTag: 'product_${product.id}',
                isRestaurantOpen: restaurant.isOpen,
                onTap: () {
                  debugPrint('🎬 [HomePage] Produto clicado - pausando vídeos!');
                  _pauseAllVideos(); // ✅ Pausar vídeos antes de navegar
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailPage(product: product),
                    ),
                  );
                },
              ),
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
                        return RepaintBoundary(
                          child: ProductCard(
                            product: product,
                            restaurantName: restaurantName,
                            hero: true,
                            heroTag: 'product_page${pageIndex}_${product.id}',
                            isRestaurantOpen: restaurant.isOpen,
                            onTap: () {
                              _pauseAllVideos(); // ✅ Pausar vídeos antes de navegar
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailPage(product: product),
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
                        _pauseAllVideos(); // ✅ Pausar vídeos ao navegar
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
                      icon: Icons.grid_view,
                      title: 'Catálogo',
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      icon: Icons.search,
                      title: 'Buscar',
                      onTap: () {
                        Navigator.pop(context);
                        // Scroll até o campo de busca após fechar o drawer
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          final searchContext = _searchFieldKey.currentContext;
                          if (searchContext != null) {
                            Scrollable.ensureVisible(
                              searchContext,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                              alignment: 0.2, // Posiciona 20% do topo
                            );
                            // Limpar campo de busca
                            _searchController.clear();
                          }
                        });
                      },
                    ),
                    const Divider(color: Color(0xFFE39110), height: 32),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text(
                        'Navegar para',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildDrawerItem(
                      icon: Icons.restaurant,
                      title: 'Estabelecimentos',
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToTop();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.star,
                      title: 'Produtos em Destaque',
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToSection(0);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.local_pharmacy,
                      title: 'Farmácia',
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToSection(1);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.shopping_cart,
                      title: 'Mercado',
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToSection(2);
                      },
                    ),
                    const Divider(color: Color(0xFFE39110), height: 32),
                    _buildDrawerItem(
                      icon: Icons.restaurant_menu,
                      title: 'Estabelecimentos',
                      onTap: () {
                        _pauseAllVideos(); // ✅ Pausar vídeos ao navegar
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoriesPage(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.person,
                      title: 'Editar Perfil',
                      onTap: () async {
                        _pauseAllVideos(); // ✅ Pausar vídeos ao navegar
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
                        _pauseAllVideos(); // ✅ Pausar vídeos ao navegar
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
                      onTap: () {
                        _pauseAllVideos(); // ✅ Pausar vídeos ao navegar
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.help,
                      title: 'Ajuda',
                      onTap: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        navigator.pop();
                        
                        final url = Uri.parse('https://pedejatermos.vercel.app/support.html');
                        try {
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url); // Modo padrão - funciona melhor no Android
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Não foi possível abrir a página de ajuda'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Erro ao abrir link: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
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
                          // Fechar drawer IMEDIATAMENTE
                          Navigator.pop(context);
                          
                          // Aguardar navegação completar antes de fazer logout
                          await Future.delayed(const Duration(milliseconds: 100));
                          
                          try {
                            // Fazer logout
                            final authState = Provider.of<AuthState>(context, listen: false);
                            
                            // Navegar ANTES do logout (evita race condition no iOS)
                            if (mounted) {
                              await Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                                (route) => false,
                              );
                            }
                            
                            // DEPOIS fazer logout em background
                            authState.signOut().catchError((e) {
                              debugPrint('❌ Erro ao fazer logout em background: $e');
                            });
                          } catch (e) {
                            debugPrint('❌ Erro ao processar logout: $e');
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