import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../models/product_model.dart';
import '../../models/restaurant_model.dart';
import '../../widgets/common/product_card.dart';
import '../restaurant/restaurant_detail_page.dart';

class CategoryEstablishmentsPage extends StatefulWidget {
  final String categoryName;
  final String categoryEmoji;

  const CategoryEstablishmentsPage({
    super.key,
    required this.categoryName,
    required this.categoryEmoji,
  });

  @override
  State<CategoryEstablishmentsPage> createState() =>
      _CategoryEstablishmentsPageState();
}

class _CategoryEstablishmentsPageState
    extends State<CategoryEstablishmentsPage> {
  List<Map<String, dynamic>> _establishments = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  bool _isRestaurantOpen(dynamic apiIsOpen) {
    if (apiIsOpen == null) return true;
    if (apiIsOpen is bool) return apiIsOpen;
    if (apiIsOpen is String) return apiIsOpen.toLowerCase() == 'true';
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadEstablishments();
    // Atualiza automaticamente a cada 5 minutos para sincronizar com mudanças de status
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _loadEstablishments(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEstablishments({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Busca todos os restaurantes
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/restaurants'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        final responseList =
            decoded is List ? decoded : (decoded['data'] as List? ?? []);

        // Filtra por tipo
        final filtered = responseList.where((r) {
          if (r is! Map) return false;

          // 🐴 OPERAÇÃO CAVALO DE TROIA: Só mostra restaurantes ativos
          if (r['isActive'] != true) return false;

          final type = (r['type']?.toString() ?? '').toLowerCase();
          if (type.isEmpty) return false;

          final normalizedType = type[0].toUpperCase() + type.substring(1);

          return normalizedType == widget.categoryName;
        }).toList();

        // Para cada restaurante, busca produtos
        final List<Map<String, dynamic>> establishments = [];

        for (var restaurant in filtered) {
          final restaurantId = restaurant['id'];
          final restaurantName = restaurant['name'] ?? 'Sem nome';

          try {
            // Normaliza o campo isOpen para apiIsOpen (compatibilidade com RestaurantModel)
            Map<String, dynamic> restaurantData = Map.from(restaurant);
            if (restaurant.containsKey('isOpen')) {
              restaurantData['apiIsOpen'] = restaurant['isOpen'];
            }

            final productsResponse = await http.get(
              Uri.parse('https://api-pedeja.vercel.app/api/restaurants/$restaurantId/products'),
            );

            List<dynamic> products = [];
            if (productsResponse.statusCode == 200) {
              final productsData = json.decode(productsResponse.body);

              if (productsData is List) {
                products = productsData;
              } else if (productsData['data'] is List) {
                products = productsData['data'];
              }
            }

            // 🐴 OPERAÇÃO CAVALO DE TROIA: Só adiciona se tiver produtos disponíveis
            if (products.isNotEmpty) {
              establishments.add({
                'id': restaurantId,
                'name': restaurantName,
                'data': restaurantData,
                'products': products,
              });
            }

          } catch (e) {
            // 🐴 OPERAÇÃO CAVALO DE TROIA: Se erro ao buscar produtos, não adiciona
            // (restaurante sem produtos não deve aparecer)
            debugPrint('⚠️ Erro ao carregar produtos de $restaurantName: $e');
          }
        }

        setState(() {
          _establishments = establishments;
          _loading = false;
        });
      } else {
        throw Exception('Erro ao carregar restaurantes: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar estabelecimentos: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF022E28),
      appBar: AppBar(
        title: Text(
          '${widget.categoryEmoji} ${widget.categoryName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF74241F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE39110),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white54,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEstablishments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF74241F),
                        ),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : _establishments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.categoryEmoji,
                            style: const TextStyle(fontSize: 64),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum ${widget.categoryName.toLowerCase()} encontrado',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _establishments.length,
                      itemBuilder: (context, index) {
                        final establishment = _establishments[index];
                        final name = establishment['name'];
                        final products = establishment['products'] as List;
                        final restaurantData = establishment['data'];

                        return _buildRestaurantSection(
                          name,
                          products,
                          restaurantData,
                        );
                      },
                    ),
    );
  }

  Widget _buildRestaurantSection(
    String name,
    List products,
    Map<String, dynamic> restaurantData,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do restaurante (clicável)
          GestureDetector(
            onTap: () {
              try {
                final restaurantModel = RestaurantModel.fromJson(
                  restaurantData,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RestaurantDetailPage(
                      restaurant: restaurantModel,
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Erro ao abrir restaurante'),
                    backgroundColor: Color(0xFF74241F),
                  ),
                );
              }
            },
            child: Builder(
              builder: (context) {
                final restaurantModel = RestaurantModel.fromJson(restaurantData);
                final imageUrl = restaurantModel.displayImage;

                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE39110),
                      width: 2,
                    ),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.6),
                              BlendMode.darken,
                            ),
                          )
                        : null,
                    gradient: imageUrl == null
                        ? const LinearGradient(
                            colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Badge de status
                        // Lógica robusta para status aberto/fechado
                        (() {
                          final isOpen = _isRestaurantOpen(restaurantData['apiIsOpen']);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
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
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? const Color(0xFFE39110)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isOpen ? 'Aberto' : 'Fechado',
                                  style: TextStyle(
                                    color: isOpen
                                        ? const Color(0xFFE39110)
                                        : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Carrossel de produtos
          products.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Nenhum produto disponível',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                )
              : SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    itemBuilder: (context, prodIndex) {
                      final product = products[prodIndex];
                      try {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 160,
                            child: ProductCard(
                              product: ProductModel.fromJson(product),
                              isRestaurantOpen: _isRestaurantOpen(restaurantData['apiIsOpen']),
                            ),
                          ),
                        );
                      } catch (e) {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
