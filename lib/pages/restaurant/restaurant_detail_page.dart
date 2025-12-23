import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../models/restaurant_model.dart';
import '../../models/product_model.dart';
import '../../widgets/common/product_card.dart';
import '../../core/services/operating_hours_service.dart';

class RestaurantDetailPage extends StatefulWidget {
  final RestaurantModel restaurant;

  const RestaurantDetailPage({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailPage> createState() => _RestaurantDetailPageState();
}

class _RestaurantDetailPageState extends State<RestaurantDetailPage> {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  RestaurantModel? _currentRestaurant;
  String _selectedCategory = 'Todos';
  List<String> _availableCategories = ['Todos'];

  @override
  void initState() {
    super.initState();
    _currentRestaurant = widget.restaurant;
    _loadProducts();
    
    // ✅ Atualiza horários ao abrir a página
    OperatingHoursService.refreshOperatingHours().then((_) {
      // Depois de atualizar horários, recarrega o status do restaurante
      _refreshRestaurantStatus();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// 🔄 Atualiza apenas o status do restaurante sem recarregar produtos
  Future<void> _refreshRestaurantStatus() async {
    try {
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/restaurants/${widget.restaurant.id}'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final restaurantData = decoded is Map<String, dynamic> ? decoded : decoded['data'];
        
        if (mounted && restaurantData != null) {
          setState(() {
            _currentRestaurant = RestaurantModel.fromJson(restaurantData);
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao atualizar status do restaurante: $e');
    }
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final url = 'https://api-pedeja.vercel.app/api/restaurants/${widget.restaurant.id}/products';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> productsData = decoded is List ? decoded : (decoded['data'] as List? ?? []);

        if (mounted) {
          setState(() {
            _products = productsData
                .map((p) => ProductModel.fromJson(p))
                .toList();
            _isLoading = false;
            
            // Extrair categorias únicas dos produtos
            final categories = <String>{'Todos'};
            for (var product in _products) {
              if (product.category != null && product.category!.isNotEmpty) {
                categories.add(product.category!);
              }
            }
            _availableCategories = categories.toList();
          });
        }
      } else {
        throw Exception('Erro ao carregar produtos: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar produtos: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF022E28),
      body: CustomScrollView(
        slivers: [
          // AppBar com imagem de capa
          _buildSliverAppBar(),

          // Informações do restaurante
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRestaurantInfo(),
                const SizedBox(height: 24),
                _buildProductsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final imageUrl = widget.restaurant.displayImage;

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF74241F),
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem de capa
            Hero(
              tag: 'restaurant-${widget.restaurant.id}',
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF74241F),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF74241F),
                        child: const Icon(
                          Icons.restaurant,
                          size: 80,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF74241F),
                      child: const Icon(
                        Icons.restaurant,
                        size: 80,
                        color: Colors.white54,
                      ),
                    ),
            ),

            // Gradiente escuro
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantInfo() {
    // Sempre mostrar status usando a lógica do model
    final restaurant = _currentRestaurant ?? widget.restaurant;
    final isOpen = restaurant.isOpen;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome do restaurante
          Text(
            restaurant.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status e Endereço em linha
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOpen 
                      ? const Color(0xFF022E28) 
                      : const Color(0xFFFF5722),
                  borderRadius: BorderRadius.circular(8),
                  border: isOpen
                      ? Border.all(
                          color: const Color(0xFFE39110),
                          width: 2,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isOpen 
                            ? const Color(0xFFE39110)
                            : Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOpen ? 'Aberto' : 'Fechado',
                      style: TextStyle(
                        color: isOpen 
                            ? const Color(0xFFE39110)
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),              // Endereço
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFFE39110),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.restaurant.address,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            color: Color(0xFFE39110),
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 64,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum produto disponível',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filtros de categoria
        if (_availableCategories.length > 1)
          SizedBox(
            height: 48,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: _availableCategories.length,
              itemBuilder: (context, index) {
                final category = _availableCategories[index];
                final isSelected = _selectedCategory == category;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(category),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
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
        
        if (_availableCategories.length > 1)
          const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _filteredProducts.length,
          itemBuilder: (context, index) {
            final restaurant = _currentRestaurant ?? widget.restaurant;
            return ProductCard(
              product: _filteredProducts[index],
              isRestaurantOpen: restaurant.apiIsOpen == true,
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<ProductModel> get _filteredProducts {
    if (_selectedCategory == 'Todos') {
      return _products;
    }
    return _products.where((p) => p.category == _selectedCategory).toList();
  }
}
