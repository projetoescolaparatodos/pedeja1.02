import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/product_model.dart';
import '../../models/brand_variant.dart';
import '../../state/cart_state.dart';
import '../cart/cart_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    try {
      final url =
          'https://api-pedeja.vercel.app/api/restaurants/${widget.product.restaurantId}/products';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> products = json.decode(response.body);

        final productData = products.firstWhere(
          (p) => p['id'] == widget.product.id,
          orElse: () => null,
        );

        if (productData != null) {
          setState(() {
            _productData = productData as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
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

    for (var addon in _addons) {
      if (_selectedAddons[addon['name']] == true) {
        total += (addon['price'] as double) * _quantity;
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5D1C17), Color(0xFF0D3B3B)], // Vinho escuro → Verde lodo
                  stops: [0.0, 1.0],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE39110)),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5D1C17), Color(0xFF0D3B3B)], // Vinho escuro → Verde lodo
                  stops: [0.0, 1.0],
                ),
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
                        if (_addons.isNotEmpty) _buildAddonsSection(),
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
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE39110)
                            : const Color(0xFFE39110).withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D3B3B), // Verde lodo escuro
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Controle de quantidade
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
            const SizedBox(width: 16),
            // Botão adicionar ao carrinho
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE39110), Color(0xFFDA8520)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE39110).withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
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

                    // Reset quantidade
                    setState(() {
                      _quantity = 1;
                      _selectedAddons.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
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
                          'Adicionar • R\$ ${_totalPrice.toStringAsFixed(2).replaceAll('.', ',')}',
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
          ],
        ),
      ),
    );
  }
}
