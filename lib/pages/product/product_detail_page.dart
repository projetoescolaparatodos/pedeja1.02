import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/product_model.dart';
import '../../models/brand_variant.dart';
import '../../models/topping_section.dart';
import '../../state/cart_state.dart';
import '../cart/cart_page.dart';
import '../../services/product_suggestions_service.dart';
import '../../widgets/suggestions/product_suggestions_bottom_sheet.dart';
import '../../widgets/advanced_toppings_builder.dart';

class ProductDetailPage extends StatefulWidget {
  final ProductModel product;

  const ProductDetailPage({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  final Map<String, bool> _selectedAddons = {};
  Map<String, dynamic>? _productData;
  bool _isLoading = true;
  BrandVariant? _selectedBrand;
  
  // 🍕 ADICIONAIS AVANÇADOS
  List<SelectedTopping> _advancedToppingsSelections = [];
  double _advancedToppingsTotalPrice = 0.0;
  bool _advancedToppingsValid = false;
  String? _advancedToppingsErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    print('📦 [PRODUCT DETAIL] Iniciando carregamento de dados');
    print('📦 [PRODUCT DETAIL] Restaurant ID: ${widget.product.restaurantId}');
    print('📦 [PRODUCT DETAIL] Product ID: ${widget.product.id}');
    
    try {
      final url =
          'https://api-pedeja.vercel.app/api/restaurants/${widget.product.restaurantId}/products';
      
      print('📦 [PRODUCT DETAIL] Chamando: $url');
      
      final response = await http.get(Uri.parse(url));

      print('📦 [PRODUCT DETAIL] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> products = json.decode(response.body);
        
        print('📦 [PRODUCT DETAIL] Recebeu ${products.length} produtos');

        final productData = products.firstWhere(
          (p) => p['id'] == widget.product.id,
          orElse: () => null,
        );

        if (productData != null) {
          print('📦 [PRODUCT DETAIL] Produto encontrado!');
          print('📦 [PRODUCT DETAIL] hasMultipleBrands: ${productData['hasMultipleBrands']}');
          print('📦 [PRODUCT DETAIL] brands: ${productData['brands']?.length ?? 0}');
          
          setState(() {
            _productData = productData as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          print('❌ [PRODUCT DETAIL] Produto não encontrado na lista');
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ [PRODUCT DETAIL] Erro: $e');
      setState(() => _isLoading = false);
    }
  }

  List<String> get _badges {
    if (_productData == null) return [];
    final badges = _productData!['badges'];
    if (badges is List) {
      return badges.map((e) => e.toString()).toList();
    }
    return [];
  }
  
  /// 🎯 Mostra sugestões de produtos relacionados
  Future<void> _showProductSuggestions(CartState cart) async {
    if (!mounted) return;
    
    try {
      // Buscar IDs dos produtos no carrinho
      final cartProductIds = cart.items.map((item) => item.id).toList();
      
      // Buscar sugestões do backend
      final suggestionsService = ProductSuggestionsService();
      final suggestions = await suggestionsService.getProductSuggestions(
        restaurantId: widget.product.restaurantId,
        cartProductIds: cartProductIds,
      );
      
      // Se não há sugestões, não mostrar bottom sheet
      if (suggestions.isEmpty || !mounted) {
        return;
      }
      
      // Marcar que sugestões foram mostradas
      cart.markSuggestionsAsShown();
      
      // Mostrar bottom sheet
      ProductSuggestionsBottomSheet.show(
        context,
        suggestions: suggestions,
        onAddToCart: (product) {
          // Adicionar produto sugerido ao carrinho
          cart.addItem(
            productId: product.id,
            name: product.name,
            price: product.price,
            imageUrl: product.displayImage,
            restaurantId: product.restaurantId,
            restaurantName: product.restaurantName ?? 'Restaurante',
            hasMultipleBrands: product.hasMultipleBrands,
            pickupOnly: product.pickupOnly, // 🏪 PICKUP ONLY
          );
          
          // Feedback de sucesso
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ ${product.name} adicionado ao carrinho!'),
                duration: const Duration(seconds: 2),
                backgroundColor: const Color(0xFF74241F),
              ),
            );
          }
        },
      );
    } catch (e) {
      print('❌ Erro ao mostrar sugestões: $e');
    }
  }

  List<Map<String, dynamic>> get _addons {
    if (_productData == null) return [];
    final addons = _productData!['addons'];
    if (addons is List) {
      return addons.map((addon) {
        return {
          'name': addon['name']?.toString() ?? '',
          'price': (addon['price'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    }
    return [];
  }
  
  // 🍕 GETTERS PARA ADICIONAIS AVANÇADOS
  bool get _useAdvancedToppings {
    if (_productData == null) return false;
    return _productData!['useAdvancedToppings'] == true;
  }
  
  List<ToppingSection> get _advancedToppings {
    if (_productData == null || !_useAdvancedToppings) return [];
    
    final toppings = _productData!['advancedToppings'];
    if (toppings is List) {
      return toppings
          .map((section) => ToppingSection.fromJson(section as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  List<BrandVariant> get _brands {
    if (!widget.product.hasMultipleBrands) return [];
    return widget.product.brands;
  }

  double get _currentPrice {
    if (_selectedBrand != null) {
      return _selectedBrand!.brandPrice;
    }
    return widget.product.price;
  }

  int get _currentStock {
    if (_selectedBrand != null) {
      return _selectedBrand!.brandStock;
    }
    return 999; // Estoque padrão para produtos sem variantes
  }

  double get _totalPrice {
    double total = _currentPrice * _quantity;

    // 🍕 Se usa adicionais avançados, soma o preço deles
    if (_useAdvancedToppings) {
      total += _advancedToppingsTotalPrice * _quantity;
    } else {
      // Sistema simples de addons
      for (var addon in _addons) {
        if (_selectedAddons[addon['name']] == true) {
          total += (addon['price'] as double) * _quantity;
        }
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D3B3B), // Verde escuro sólido igual home
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE39110)),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D3B3B), // Verde escuro sólido igual home
              ),
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductInfo(),
                        if (_badges.isNotEmpty) _buildBadgesSection(),
                        _buildDescription(),
                        if (_brands.isNotEmpty) _buildBrandSelector(),
                        _buildAddonsOrAdvancedToppings(), // 🍕 INTEGRAÇÃO CIRÚRGICA
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.transparent,
      actions: [
        // 🛒 Badge do carrinho
        Consumer<CartState>(
          builder: (context, cart, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  color: Colors.white,
                  onPressed: () {
                    CartPage.show(context);
                  },
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE39110),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF5D1C17), Color(0xFF0D3B3B)],
            stops: [0.0, 1.0],
          ),
        ),
        child: FlexibleSpaceBar(
          background: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.product.displayImage ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5D1C17), Color(0xFF0D3B3B)],
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFE39110),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5D1C17), Color(0xFF0D3B3B)],
                      ),
                    ),
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.white54,
                    ),
                  );
                },
                maxWidthDiskCache: 1000,
                maxHeightDiskCache: 1000,
              ),
              // Gradiente para melhor legibilidade
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.6, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              
              // 🏪 Badge "Somente Retirada" (se pickupOnly)
              if (widget.product.pickupOnly)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.store, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        const Text(
                          'Somente retirada no local',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.name,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 🔒 Não mostrar preço quando usa adicionais avançados (preço varia conforme seleções)
          if (!_useAdvancedToppings)
            Text(
              widget.product.formattedPrice,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE39110),
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        children: _badges.map((badge) => _buildBadge(badge)).toList(),
      ),
    );
  }

  Widget _buildBadge(String badge) {
    final Map<String, Map<String, dynamic>> badgeConfig = {
      'sem_gluten': {
        'label': 'Sem Glúten',
        'icon': Icons.health_and_safety,
        'color': const Color(0xFF4CAF50),
      },
      'vegano': {
        'label': 'Vegano',
        'icon': Icons.eco,
        'color': const Color(0xFF8BC34A),
      },
      'vegetariano': {
        'label': 'Vegetariano',
        'icon': Icons.eco,
        'color': const Color(0xFF8BC34A),
      },
      'promo': {
        'label': 'Promoção',
        'icon': Icons.local_fire_department,
        'color': const Color(0xFFFF5722),
      },
      'novo': {
        'label': 'Novo',
        'icon': Icons.fiber_new,
        'color': const Color(0xFFE39110),
      },
      'picante': {
        'label': 'Picante',
        'icon': Icons.whatshot,
        'color': const Color(0xFFFF5722),
      },
    };

    final config = badgeConfig[badge] ?? {
      'label': badge,
      'icon': Icons.star,
      'color': const Color(0xFFDA9528),
    };

    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (config['color'] as Color).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'] as IconData, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descrição',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.product.description ?? '',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.6,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          
          // 🏪 Motivo do pickup-only (se houver)
          if (widget.product.pickupOnly && widget.product.pickupOnlyReason != null)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100.withValues(alpha: 0.2),
                border: Border.all(color: Colors.orange.shade200, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.product.pickupOnlyReason!,
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBrandSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione a Marca',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Dynamic text box showing selected brand name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D3B3B).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedBrand != null 
                    ? const Color(0xFFE39110).withValues(alpha: 0.5)
                    : const Color(0xFFE39110).withValues(alpha: 0.3),
                width: _selectedBrand != null ? 1.5 : 1,
              ),
            ),
            child: Text(
              _selectedBrand != null 
                  ? _selectedBrand!.brandName 
                  : 'Selecione uma marca',
              style: TextStyle(
                color: _selectedBrand != null ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: _selectedBrand != null ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          // Horizontal carousel with brand cards
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _brands.length,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              itemBuilder: (context, index) {
                final brand = _brands[index];
                final isSelected = _selectedBrand == brand;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedBrand = brand;
                    });
                  },
                  child: Container(
                    width: 160,
                    margin: EdgeInsets.only(
                      right: index < _brands.length - 1 ? 12 : 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE39110)
                            : const Color(0xFFE39110).withValues(alpha: 0.3),
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFE39110).withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          // Brand image
                          if (brand.brandImageUrl != null && brand.brandImageUrl!.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: brand.brandImageUrl!,
                              width: 160,
                              height: 220,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF0D3B3B).withValues(alpha: 0.6),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFE39110),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(0xFF0D3B3B).withValues(alpha: 0.6),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.white38,
                                    size: 48,
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              color: const Color(0xFF0D3B3B).withValues(alpha: 0.6),
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white38,
                                  size: 48,
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
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                          
                          // Price tag at bottom
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'R\$ ${brand.brandPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                                  style: const TextStyle(
                                    color: Color(0xFFE39110),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (brand.brandStock != null && brand.brandStock! > 0)
                                  Text(
                                    'Estoque: ${brand.brandStock}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          
                          // Selection indicator
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE39110),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedBrand != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Estoque: $_currentStock unidades',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddonsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adicionais',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._addons.map((addon) => _buildAddonItem(addon)),
        ],
      ),
    );
  }

  Widget _buildAddonItem(Map<String, dynamic> addon) {
    final name = addon['name'] as String;
    final price = addon['price'] as double;
    final isSelected = _selectedAddons[name] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected 
              ? const Color(0xFFE39110)
              : Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            _selectedAddons[name] = value ?? false;
          });
        },
        activeColor: const Color(0xFFE39110),
        checkColor: Colors.white,
        tileColor: Colors.transparent,
        title: Text(
          name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        subtitle: Text(
          'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}',
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFFE39110),
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
  
  // 🍕 MÉTODO CIRÚRGICO: Decide qual sistema de adicionais mostrar
  Widget _buildAddonsOrAdvancedToppings() {
    if (_useAdvancedToppings && _advancedToppings.isNotEmpty) {
      // Sistema novo: Adicionais avançados (seções)
      return AdvancedToppingsBuilder(
        sections: _advancedToppings,
        onSelectionsChanged: (selections, totalPrice, isValid, errorMessage) {
          setState(() {
            _advancedToppingsSelections = selections;
            _advancedToppingsTotalPrice = totalPrice;
            _advancedToppingsValid = isValid;
            _advancedToppingsErrorMessage = errorMessage;
          });
        },
        accentColor: const Color(0xFFE39110),
      );
    } else if (_addons.isNotEmpty) {
      // Sistema antigo: Adicionais simples (checkboxes)
      return _buildAddonsSection();
    }
    
    // Nenhum sistema de adicionais
    return const SizedBox.shrink();
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D3B3B), // Verde lodo escuro
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Controle de quantidade - esconde quando usa adicionais avançados
            if (!_useAdvancedToppings)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white, size: 22),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _quantity.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 22),
                    onPressed: () => setState(() => _quantity++),
                  ),
                ],
              ),
            ),
            if (!_useAdvancedToppings) const SizedBox(width: 16),
            // Botão adicionar ao carrinho
            Expanded(
              child: Opacity(
                opacity: (_useAdvancedToppings && !_advancedToppingsValid) ? 0.5 : 1.0, // ⚙️ Visual feedback
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE39110), Color(0xFFDA8520)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: (!_useAdvancedToppings || _advancedToppingsValid)
                        ? Border.all(
                            color: const Color(0xFF5A1C18), // Vermelho vinho
                            width: 2,
                          )
                        : null, // Sem borda quando desabilitado
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE39110).withValues(alpha: 0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (_useAdvancedToppings && !_advancedToppingsValid)
                        ? null // ❌ Desabilitado quando adicionais avançados estão incompletos
                        : () {
                    final cart = context.read<CartState>();

                    // Validar seleção de marca se necessário
                    if (widget.product.hasMultipleBrands && _selectedBrand == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Selecione uma marca antes de adicionar ao carrinho'),
                          backgroundColor: Color(0xFF74241F),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    // Validar estoque
                    if (_currentStock < _quantity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⚠️ Estoque insuficiente. Disponível: $_currentStock'),
                          backgroundColor: const Color(0xFF74241F),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    // Coleta adicionais selecionados
                    final selectedAddonsList = <Map<String, dynamic>>[];

                    for (var addon in _addons) {
                      if (_selectedAddons[addon['name']] == true) {
                        selectedAddonsList.add({
                          'id': addon['id'] ?? addon['name'],
                          'name': addon['name'],
                          'price': addon['price'],
                        });
                      }
                    }
                    
                    // 🍕 Prepara seleções de adicionais avançados (se houver)
                    List<Map<String, dynamic>>? advancedSelectionsJson;
                    if (_useAdvancedToppings && _advancedToppingsSelections.isNotEmpty) {
                      advancedSelectionsJson = _advancedToppingsSelections
                          .map((s) => s.toJson())
                          .toList();
                    }

                    // ✅ Adiciona ao carrinho
                    for (int i = 0; i < _quantity; i++) {
                      cart.addItem(
                        productId: widget.product.id,
                        name: widget.product.name,
                        price: _currentPrice,
                        imageUrl: widget.product.displayImage,
                        addons: selectedAddonsList,
                        restaurantId: widget.product.restaurantId,
                        restaurantName: widget.product.restaurantName ?? 'Restaurante',
                        brandName: _selectedBrand?.brandName,
                        hasMultipleBrands: widget.product.hasMultipleBrands,
                        advancedToppingsSelections: advancedSelectionsJson, // 🍕 CIRÚRGICO
                        pickupOnly: widget.product.pickupOnly, // 🏪 PICKUP ONLY
                      );
                    }

                    // ✅ Feedback visual
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ ${_quantity}x ${widget.product.name} adicionado ao carrinho!',
                        ),
                        backgroundColor: const Color(0xFF74241F),
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'Ver Carrinho',
                          textColor: const Color(0xFFE39110),
                          onPressed: () {
                            CartPage.show(context);
                          },
                        ),
                      ),
                    );
                    
                    // 🎯 Mostrar sugestões de produtos (após 1 segundo)
                    // Condição: primeira vez OU carrinho tem menos de 3 itens
                    if (!cart.hasShownSuggestions || cart.itemCount < 3) {
                      Future.delayed(const Duration(seconds: 1), () {
                        _showProductSuggestions(cart);
                      });
                    }

                    // Reset quantidade e seleções
                    setState(() {
                      _quantity = 1;
                      _selectedAddons.clear();
                      _advancedToppingsSelections = []; // 🍕 RESET ADICIONAIS AVANÇADOS
                      _advancedToppingsTotalPrice = 0.0;
                      _advancedToppingsValid = false; // ⚠️ RESETAR VALIDAÇÃO
                      _advancedToppingsErrorMessage = null; // ⚠️ LIMPAR MENSAGEM DE ERRO
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent, // ⚙️ Transparente quando desabilitado
                    disabledForegroundColor: Colors.white, // ⚙️ Texto branco mesmo quando desabilitado para facilitar leitura
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _useAdvancedToppings && !_advancedToppingsValid && _advancedToppingsErrorMessage != null
                              ? _advancedToppingsErrorMessage!
                              : 'Adicionar • R\$ ${_totalPrice.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
