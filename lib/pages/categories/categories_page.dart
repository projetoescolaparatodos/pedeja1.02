import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../categories/category_establishments_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  Map<String, int> _typeCounts = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api-pedeja.vercel.app/api/restaurants'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        final List<dynamic> restaurants =
            decoded is List ? decoded : (decoded['data'] as List);

        // Conta quantos de cada tipo
        final Map<String, int> counts = {};

        for (var r in restaurants) {
          if (r is Map) {
            // 🐴 OPERAÇÃO CAVALO DE TROIA: Só conta restaurantes ativos
            if (r['isActive'] != true) continue;
            
            String type = (r['type']?.toString() ?? 'outros').toLowerCase();
            if (type.isNotEmpty) {
              type = type[0].toUpperCase() + type.substring(1);
            } else {
              type = 'Outros';
            }

            counts[type] = (counts[type] ?? 0) + 1;
          }
        }

        setState(() {
          _typeCounts = counts;
          _loading = false;
        });
      } else {
        throw Exception('Erro ao carregar restaurantes: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar categorias: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ordena tipos por quantidade (decrescente)
    final sorted = _typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: const Color(0xFF022E28), // Verde lodo mais escuro
      appBar: AppBar(
        title: const Text(
          'Estabelecimentos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF022E28),
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
                        onPressed: _loadTypes,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF74241F),
                        ),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, i) {
                    final type = sorted[i].key;
                    final count = sorted[i].value;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryEstablishmentsPage(
                              categoryName: type,
                              categoryEmoji: _getEmoji(type),
                            ),
                          ),
                        );
                      },
                      child: _buildCategoryCard(type, count),
                    );
                  },
                ),
    );
  }

  Widget _buildCategoryCard(String type, int count) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF74241F), Color(0xFF5A1C18)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE39110),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF74241F).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Badge de contagem (top-right)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE39110),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Emoji e nome (centro)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getEmoji(type),
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    type,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
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

  String _getEmoji(String type) {
    final typeLower = type.toLowerCase();
    const map = {
      'pizza': '🍕',
      'pizzaria': '🍕',
      'hamburgueria': '🍔',
      'hamburguer': '🍔',
      'lanchonete': '🌭',
      'açai': '🍨',
      'açaí': '🍨',
      'sorvete': '🍦',
      'sorveteria': '🍦',
      'farmácia': '💊',
      'farmacia': '💊',
      'mercado': '🛒',
      'supermercado': '🛒',
      'padaria': '🥖',
      'restaurante': '🍽️',
      'cafeteria': '☕',
      'cafe': '☕',
      'café': '☕',
      'bar': '🍺',
      'petshop': '🐾',
      'pet': '🐾',
    };
    return map[typeLower] ?? '🏪';
  }
}
