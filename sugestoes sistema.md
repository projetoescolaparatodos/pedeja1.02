 Sistema de Sugestões de Produtos - App Flutter

## ⚠️ ANTES DE COMEÇAR - LEIA ISTO

### ✅ O QUE JÁ ESTÁ PRONTO NO BACKEND:

1. **Campo no produto:** `suggestedWith` (array de IDs de produtos)
   - Exemplo: `{"id": "ABC123", "name": "Pastel", "suggestedWith": ["COCA_ID", "GUARANA_ID"]}`
   
2. **Endpoint de sugestões:** `GET /api/products/suggestions`
   - URL completa: `https://api-pedeja.vercel.app/api/products/suggestions?restaurantId=XXX&productIds=YYY,ZZZ`
   - Retorna: `{"success": true, "data": [ProductModel, ProductModel, ...]}`
   - Limite: até 3 produtos
   - Sistema bidirecional: se Pastel sugere Coca, Coca também sugere Pastel

3. **Endpoints de criar/editar produto:** Aceitam campo `suggestedWith`
   - `POST /api/partners/products` 
   - `PATCH /api/partners/products/:id`

### ❌ O QUE VOCÊ PRECISA IMPLEMENTAR NO FLUTTER:

1. **Adicionar campo `suggestedWith` no ProductModel** (se ainda não existe)
2. **Criar service para chamar endpoint de sugestões**
3. **Criar bottom sheet de sugestões**
4. **Integrar no CartState após adicionar produto**

---

## Visão Geral

Este guia explica como implementar o **Bottom Sheet de Sugestões** no app Flutter. Quando o usuário adicionar um produto ao carrinho, aparecerá uma sugestão flutuante com até 3 produtos relacionados para aumentar o ticket médio.

**Sistema Bidirecional:** Se Pastel sugere Coca, então Coca também sugere Pastel automaticamente! 🔄

---

## 📋 Comportamento Esperado

### Fluxo do Usuário

1. **Usuário adiciona produto ao carrinho**
   - Exemplo: Adiciona "Pastel de Carne"
   - Produto vai para o carrinho ✅

2. **Bottom sheet aparece automaticamente**
   - Aguarda 1 segundo
   - Sobe da parte inferior da tela
   - Mostra até 3 produtos sugeridos

3. **Usuário pode:**
   - ✅ Adicionar produto sugerido ao carrinho (botão "+")
   - ❌ Fechar o bottom sheet ("Não, obrigado")
   - ⏱️ Deixar fechar automaticamente (após 8 segundos)

4. **Bottom sheet fecha**
   - Produto sugerido foi adicionado OU
   - Usuário clicou em "Não, obrigado" OU
   - 8 segundos passaram

---

## 🔧 Implementação

### 0. Atualizar ProductModel (SE NECESSÁRIO)

**Arquivo:** `lib/models/product_model.dart` ou similar

**Verificar se o campo `suggestedWith` já existe.** Se NÃO existir, adicionar:

#### Adicionar campo na classe:

```dart
class ProductModel {
  final String id;
  final String name;
  final double price;
  // ... outros campos existentes ...
  
  final List<String> suggestedWith; // ← ADICIONAR ISTO
  
  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    // ... outros campos ...
    this.suggestedWith = const [], // ← ADICIONAR ISTO (padrão: lista vazia)
  });
  
  // Atualizar fromJson
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      // ... outros campos ...
      
      // ← ADICIONAR ISTO
      suggestedWith: json['suggestedWith'] != null 
          ? List<String>.from(json['suggestedWith'])
          : [],
    );
  }
}
```

**Importante:** 
- Campo é **opcional** (pode ser vazio)
- É uma **lista de IDs** (strings), não objetos completos
- Backend já retorna esse campo nos produtos

---

### 1. Modificar `CartState` (ou equivalente)

**Arquivo:** `lib/state/cart_state.dart` ou similar

**Localização:** Método `addToCart()`

#### Adicionar após adicionar produto ao carrinho:

```dart
// Dentro do método addToCart()
void addToCart(ProductModel product, {List<ProductAddon>? addons, String? notes}) {
  // ... código existente de adicionar produto ...
  
  // ✅ PRODUTO ADICIONADO COM SUCESSO
  
  // 🎯 MOSTRAR SUGESTÕES (após 1 segundo)
  Future.delayed(Duration(seconds: 1), () {
    _showProductSuggestions(context, product.restaurantId);
  });
  
  notifyListeners();
}
```

---

### 2. Criar Service de Sugestões

**Arquivo:** `lib/services/product_service.dart` (adicionar método) ou criar novo `lib/services/suggestions_service.dart`

#### Método para chamar o endpoint:

```dart
class ProductService {
  final String baseUrl = 'https://api-pedeja.vercel.app'; // URL do backend
  
  /// Busca produtos sugeridos baseado nos produtos do carrinho
  /// 
  /// [restaurantId] - ID do restaurante (obrigatório)
  /// [cartProductIds] - IDs dos produtos no carrinho (opcional)
  /// 
  /// Retorna até 3 produtos sugeridos
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
          
          return suggestionsJson
              .map((json) => ProductModel.fromJson(json))
              .toList();
        }
      }
      
      print('⚠️ [SUGGESTIONS] Sem sugestões ou erro');
      return [];
      
    } catch (e) {
      print('❌ [SUGGESTIONS] Erro ao buscar sugestões: $e');
      return [];
    }
  }
}
```

**Notas importantes:**
- **URL:** `https://api-pedeja.vercel.app/api/products/suggestions`
- **Parâmetros obrigatórios:** `restaurantId`
- **Parâmetros opcionais:** `productIds` (IDs separados por vírgula)
- **Retorno:** JSON com `{success: true, data: [...]}`
- **Erro:** Retorna lista vazia (não quebra o fluxo)

---

### 3. Criar Bottom Sheet de Sugestões

**Arquivo:** `lib/widgets/product_suggestions_bottom_sheet.dart` (criar novo)

#### Widget Completo:

```dart
import 'package:flutter/material.dart';

class ProductSuggestionsBottomSheet extends StatefulWidget {
  final List<ProductModel> suggestions;
  final Function(ProductModel) onAddToCart;
  
  const ProductSuggestionsBottomSheet({
    Key? key,
    required this.suggestions,
    required this.onAddToCart,
  }) : super(key: key);
  
  @override
  State<ProductSuggestionsBottomSheet> createState() => 
      _ProductSuggestionsBottomSheetState();
}

class _ProductSuggestionsBottomSheetState 
    extends State<ProductSuggestionsBottomSheet> {
  
  @override
  void initState() {
    super.initState();
    
    // Auto-fechar após 8 segundos
    Future.delayed(Duration(seconds: 8), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Row(
            children: [
              Text(
                'Complete seu pedido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Text('🎯', style: TextStyle(fontSize: 20)),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Lista horizontal de produtos
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.suggestions.length,
              itemBuilder: (context, index) {
                final product = widget.suggestions[index];
                return _buildProductCard(product);
              },
            ),
          ),
          
          SizedBox(height: 16),
          
          // Botão "Não, obrigado"
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Não, obrigado',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductCard(ProductModel product) {
    return Container(
      width: 140,
      margin: EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Imagem
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: product.imageUrl != null
                ? Image.network(
                    product.imageUrl!,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          
          // Informações
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome (max 2 linhas)
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  Spacer(),
                  
                  // Preço
                  Text(
                    'R\$ ${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Botão adicionar
          Padding(
            padding: EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: () {
                widget.onAddToCart(product);
                Navigator.of(context).pop(); // Fecha após adicionar
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('+', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlaceholder() {
    return Container(
      height: 90,
      color: Colors.grey[200],
      child: Icon(Icons.image, color: Colors.grey[400], size: 40),
    );
  }
}
```

---

### 4. Integrar no CartState

**Arquivo:** `lib/state/cart_state.dart` (ou onde estiver o gerenciamento do carrinho)

#### Adicionar método para mostrar bottom sheet:

```dart
/// Mostra sugestões de produtos após adicionar item ao carrinho
/// 
/// [context] - BuildContext necessário para showModalBottomSheet
/// [restaurantId] - ID do restaurante dos produtos
void _showProductSuggestions(BuildContext context, String restaurantId) async {
  // Buscar IDs dos produtos no carrinho
  final cartProductIds = _items.map((item) => item.product.id).toList();
  
  print('🎯 [CART] Buscando sugestões para restaurante: $restaurantId');
  print('🛒 [CART] Produtos no carrinho: $cartProductIds');
  
  // Buscar sugestões do backend
  final suggestions = await ProductService().getProductSuggestions(
    restaurantId: restaurantId,
    cartProductIds: cartProductIds,
  );
  
  // Se não há sugestões, não mostrar bottom sheet
  if (suggestions.isEmpty) {
    print('ℹ️ [CART] Sem sugestões disponíveis');
    return;
  }
  
  print('✅ [CART] ${suggestions.length} sugestões encontradas');
  
  // Mostrar bottom sheet
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent, // Para bordas arredondadas funcionarem
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ProductSuggestionsBottomSheet(
      suggestions: suggestions,
      onAddToCart: (product) {
        // Adicionar produto sugerido ao carrinho
        addToCart(product);
        
        // Feedback de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} adicionado ao carrinho!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      },
    ),
  );
}
```

#### Modificar método addToCart existente:

```dart
void addToCart(ProductModel product, {List<ProductAddon>? addons, String? notes}) {
  // ... código existente de adicionar produto ...
  
  // ✅ PRODUTO ADICIONADO COM SUCESSO
  notifyListeners();
  
  // 🎯 MOSTRAR SUGESTÕES (após 1 segundo)
  // Importante: context precisa estar disponível aqui
  if (context != null) {
    Future.delayed(Duration(seconds: 1), () {
      // Só mostrar se ainda não mostrou ou se carrinho tem poucos itens
      if (!_hasShownSuggestions || _items.length <= 3) {
        _showProductSuggestions(context, product.restaurantId);
        _hasShownSuggestions = true; // Marcar como mostrado
      }
    });
  }
}
```

**⚠️ PROBLEMA DE CONTEXT:**

Se o `CartState` não tem acesso ao `BuildContext`, há 2 soluções:

**Solução 1 - Passar context ao addToCart:**
```dart
void addToCart(
  BuildContext context, // ← Adicionar parâmetro
  ProductModel product, 
  {List<ProductAddon>? addons, String? notes}
) {
  // ... resto do código
}
```

**Solução 2 - Chamar do widget (recomendado):**
Não modificar `addToCart`, mas chamar sugestões do widget que adiciona:

```dart
// No ProductDetailPage ou onde adiciona produto
onPressed: () {
  // Adicionar ao carrinho
  cart.addToCart(product);
  
  // Mostrar sugestões
  Future.delayed(Duration(seconds: 1), () {
    _showSuggestions(context, product.restaurantId);
  });
}
```

---

### 5. Controle de "Mostrar Apenas 1x"

Para não irritar o usuário, mostrar sugestões apenas em alguns cenários:

#### Opção 1: Apenas na primeira adição

```dart
bool _hasShownSuggestions = false;

void _showProductSuggestions(...) {
  if (_hasShownSuggestions) return; // Já mostrou uma vez
  
  _hasShownSuggestions = true;
  // ... resto do código
}

// Resetar ao limpar carrinho
void clearCart() {
  _items.clear();
  _hasShownSuggestions = false; // Resetar flag
  notifyListeners();
}
```

#### Opção 2: Apenas se carrinho tem poucos itens

```dart
void _showProductSuggestions(...) {
  // Só mostrar se tem menos de 3 itens no carrinho
  if (_items.length > 3) return;
  
  // ... resto do código
}
```

#### Opção 3: Apenas se ticket médio baixo

```dart
void _showProductSuggestions(...) {
  final subtotal = getSubtotal();
  
  // Só mostrar se subtotal < R$ 30
  if (subtotal >= 30.0) return;
  
  // ... resto do código
}
```

**Recomendação:** Combine as opções 1 e 3 (primeira vez + ticket baixo)

---

## 🎨 Design e UX

### Layout Responsivo

- **Largura do card:** 140px
- **Altura do card:** 180px
- **Espaçamento entre cards:** 12px
- **Padding do bottom sheet:** 20px

### Cores e Tipografia

```dart
// Título
fontSize: 18
fontWeight: FontWeight.bold

// Nome do produto
fontSize: 13
fontWeight: FontWeight.w500
maxLines: 2

// Preço
fontSize: 14
fontWeight: FontWeight.bold
color: primaryColor

// Botão "Não, obrigado"
color: Colors.grey[600]
```

### Animações

- **Entrada:** Bottom sheet sobe com animação padrão do Flutter
- **Saída:** Fade out suave
- **Auto-close:** 8 segundos após aparecer

---

## 📱 Testes Recomendados

### Cenários de Teste:

1. **Adicionar produto COM sugestões configuradas**
   - Bottom sheet deve aparecer ✅
   - Mostrar até 3 produtos

2. **Adicionar produto SEM sugestões**
   - Bottom sheet NÃO deve aparecer ✅
   - Carrinho funciona normalmente

3. **Adicionar produto sugerido ao carrinho**
   - Produto vai para o carrinho ✅
   - Bottom sheet fecha
   - SnackBar de confirmação aparece

4. **Clicar em "Não, obrigado"**
   - Bottom sheet fecha ✅
   - Carrinho permanece inalterado

5. **Deixar auto-fechar (8 segundos)**
   - Bottom sheet fecha automaticamente ✅

6. **Adicionar 2º produto (já mostrou uma vez)**
   - Bottom sheet NÃO aparece novamente ✅
   - (Se usar flag de "já mostrou")

7. **Produtos sem estoque**
   - Backend já filtra `stock > 0` ✅
   - Não aparecem nas sugestões

8. **Erro na API**
   - App não quebra ✅
   - Bottom sheet não aparece
   - Log de erro no console

---

## 🔄 Integrações Necessárias

### Model de Produto

Certifique-se que `ProductModel` tem todos os campos:

```dart
class ProductModel {
  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final String? imageThumbUrl;
  final String restaurantId;
  final String category;
  final List<String> badges;
  
  // ... fromJson, toJson
}
```

### Service de Produto

Se não existe, criar `lib/services/product_service.dart`:

```dart
class ProductService {
  final String baseUrl = 'https://seu-backend.com'; // Ajustar
  
  Future<List<ProductModel>> getProductSuggestions({...}) {
    // Código mostrado acima
  }
}
```

### Provider/State Management

Se usar Provider:

```dart
// main.dart
ChangeNotifierProvider(create: (_) => CartState()),
```

Se usar GetX, Riverpod, Bloc: adaptar conforme necessário

---

## ⚡ Otimizações Opcionais

### 1. Cache Local

Cachear sugestões para não buscar sempre:

```dart
Map<String, List<ProductModel>> _suggestionsCache = {};

Future<List<ProductModel>> getProductSuggestions({...}) async {
  final cacheKey = restaurantId;
  
  // Verificar cache
  if (_suggestionsCache.containsKey(cacheKey)) {
    return _suggestionsCache[cacheKey]!;
  }
  
  // Buscar do backend
  final suggestions = await _fetchFromAPI(...);
  
  // Salvar em cache
  _suggestionsCache[cacheKey] = suggestions;
  
  return suggestions;
}
```

### 2. Pré-carregar Imagens

Evitar loading de imagem visível:

```dart
void _preloadImages(List<ProductModel> suggestions) {
  for (final product in suggestions) {
    if (product.imageUrl != null) {
      precacheImage(NetworkImage(product.imageUrl!), context);
    }
  }
}
```

### 3. Analytics

Rastrear eventos importantes:

```dart
// Ao mostrar bottom sheet
analytics.logEvent(
  name: 'suggestions_shown',
  parameters: {
    'restaurant_id': restaurantId,
    'products_count': suggestions.length,
  },
);

// Ao adicionar produto sugerido
analytics.logEvent(
  name: 'suggestion_added_to_cart',
  parameters: {
    'product_id': product.id,
    'product_name': product.name,
  },
);
```

---

## 🆘 Troubleshooting

### Bottom sheet não aparece
- ✅ Verificar se endpoint retorna dados
- ✅ Verificar logs de erro no console
- ✅ Conferir se `context` é válido
- ✅ Verificar flags (já mostrou, ticket alto, etc)

### Imagens não carregam
- ✅ Verificar URL completa no log
- ✅ Adicionar `errorBuilder` no `Image.network()`
- ✅ Usar placeholder enquanto carrega

### Bottom sheet não fecha automaticamente
- ✅ Verificar se `mounted` está sendo checado
- ✅ Conferir timer de 8 segundos
- ✅ Testar em dispositivo real (não apenas simulador)

### Produto sugerido não adiciona ao carrinho
- ✅ Verificar se callback `onAddToCart` está conectado
- ✅ Conferir se `CartState.addToCart()` está sendo chamado
- ✅ Verificar regra de "um restaurante por carrinho"

---

## ✅ Checklist de Implementação

- [ ] Criar `ProductService.getProductSuggestions()`
- [ ] Criar `ProductSuggestionsBottomSheet` widget
- [ ] Modificar `CartState.addToCart()` para chamar sugestões
- [ ] Adicionar lógica de auto-close (8s)
- [ ] Implementar flag "já mostrou" ou outra otimização
- [ ] Adicionar tratamento de erro
- [ ] Testar com produtos que têm sugestões
- [ ] Testar com produtos sem sugestões
- [ ] Testar adicionar produto sugerido
- [ ] Testar auto-close
- [ ] Adicionar analytics (opcional)
- [ ] Documentar para equipe

---

## 🎯 Resultado Final

Quando tudo estiver implementado:

**Cenário 1: Adiciona Pastel**
1. Usuário adiciona "Pastel de Carne" ao carrinho
2. 1 segundo depois, bottom sheet aparece
3. Mostra: Coca-Cola, Guaraná, Suco
4. Usuário clica "+" na Coca-Cola
5. Coca vai para o carrinho
6. SnackBar confirma: "Coca-Cola adicionada!"
7. Bottom sheet fecha

**Cenário 2: Adiciona Coca (Bidirecional) 🔄**
1. Usuário adiciona "Coca-Cola" ao carrinho
2. 1 segundo depois, bottom sheet aparece
3. Mostra: Pastel de Carne (porque Pastel sugere Coca)
4. Usuário clica "+" no Pastel
5. Pastel vai para o carrinho
6. Ticket médio aumentou ainda mais! 🎉

---

**Documentação completa! Backend + Admin + Flutter prontos para implementação** ✅
