import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';

/// Service para buscar sugestões de produtos baseado nos relacionamentos
/// configurados no painel admin (campo suggestedWith)
class ProductSuggestionsService {
  static const String baseUrl = 'https://api-pedeja.vercel.app';
  
  /// Busca produtos sugeridos baseado nos produtos do carrinho
  /// 
  /// [restaurantId] - ID do restaurante (obrigatório)
  /// [cartProductIds] - IDs dos produtos no carrinho (opcional)
  /// 
  /// Retorna até 3 produtos sugeridos configurados no backend
  /// Sistema bidirecional: se Pastel sugere Coca, Coca também sugere Pastel
  Future<List<ProductModel>> getProductSuggestions({
    required String restaurantId,
    List<String>? cartProductIds,
  }) async {
    try {
      // Montar query params
      String url = '$baseUrl/api/products/suggestions?restaurantId=$restaurantId';
      
      // Adicionar IDs dos produtos do carrinho (se houver)
      if (cartProductIds != null && cartProductIds.isNotEmpty) {
        final productIdsParam = cartProductIds.join(',');
        url += '&productIds=$productIdsParam';
      }
      
      print('🎯 [SUGGESTIONS] Chamando: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('🎯 [SUGGESTIONS] Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final List suggestionsJson = data['data'] ?? [];
          
          print('🎯 [SUGGESTIONS] Recebeu ${suggestionsJson.length} produtos');
          
          // DEBUG: Ver primeiro produto
          if (suggestionsJson.isNotEmpty) {
            print('🎯 [SUGGESTIONS DEBUG] Primeiro produto: ${jsonEncode(suggestionsJson[0])}');
          }
          
          return suggestionsJson
              .map((json) => ProductModel.fromJson(json))
              .toList();
        }
      }
      
      print('⚠️ [SUGGESTIONS] Sem sugestões ou erro na resposta');
      return [];
      
    } catch (e) {
      print('❌ [SUGGESTIONS] Erro ao buscar sugestões: $e');
      return [];
    }
  }
}
