# Changelog - Versão 1.0.15+16

## 🚀 Principais Mudanças

### 1. Reestruturação da Página Home: 3 Seções Independentes

**ANTES:**
- 2 seções: "Produtos em Destaque" e "Farmácia & Mercado" (combinada)
- Cliente-side filtering (filtrava produtos após carregar)
- Limite backend de 50 produtos total
- Distribuição desigual (restaurantes populares dominavam)

**DEPOIS:**
- 3 seções separadas:
  1. **Produtos em Destaque** (Comida/Restaurantes) - ícone restaurante
  2. **Farmácia** (Remédios/Suplementos) - ícone farmácia
  3. **Mercado** (Perfumaria/Higiene/Pet) - ícone carrinho
- Server-side filtering (backend filtra por categoria)
- 130 produtos total (50+40+40)
- Distribuição justa com limite `perRestaurant`

---

## 📦 Backend API - Novos Parâmetros

### Endpoints Especializados:

```http
# Produtos em Destaque (50 produtos)
GET /api/products/all?limit=50&perRestaurant=10&excludeCategories=remedio,suplementos,medicamento,perfumaria,varejinho,higiene,beleza,cosmeticos,limpeza,pet&shuffle=true&seed=featured

# Farmácia (40 produtos)
GET /api/products/all?limit=40&perRestaurant=40&categories=remedio,suplementos,medicamento,vitamina&shuffle=true&seed=pharmacy

# Mercado (40 produtos)
GET /api/products/all?limit=40&perRestaurant=40&categories=perfumaria,varejinho,higiene,beleza,cosmeticos,limpeza,pet,mercearia&shuffle=true&seed=market
```

### Parâmetros Utilizados:

- **limit**: Número máximo de produtos retornados
- **perRestaurant**: Máximo de produtos por restaurante (distribuição justa)
- **categories**: Filtra produtos que pertencem a essas categorias
- **excludeCategories**: Exclui produtos dessas categorias
- **shuffle**: Embaralha resultados para variedade
- **seed**: Semente para shuffle consistente

---

## 🔧 Mudanças Técnicas

### CatalogProvider (`lib/providers/catalog_provider.dart`)

#### Novos States:
```dart
// 3 listas independentes
List<ProductModel> _featuredProducts = [];
List<ProductModel> _pharmacyProducts = [];
List<ProductModel> _marketProducts = [];

// Estados de loading independentes
bool _featuredProductsLoading = false;
bool _pharmacyProductsLoading = false;
bool _marketProductsLoading = false;

// Estados de erro independentes
String? _featuredProductsError;
String? _pharmacyProductsError;
String? _marketProductsError;
```

#### Novos Métodos:
- `loadFeaturedProducts({bool force = false})` - Carrega produtos em destaque
- `loadPharmacyProducts({bool force = false})` - Carrega produtos de farmácia
- `loadMarketProducts({bool force = false})` - Carrega produtos de mercado
- `_silentRefreshProducts()` - Refresh automático das 3 listas a cada 5 minutos

#### Getters Públicos:
```dart
List<ProductModel> get featuredProducts => _featuredProducts;
List<ProductModel> get pharmacyProducts => _pharmacyProducts;
List<ProductModel> get marketProducts => _marketProducts;

bool get featuredProductsLoading => _featuredProductsLoading;
bool get pharmacyProductsLoading => _pharmacyProductsLoading;
bool get marketProductsLoading => _marketProductsLoading;

String? get featuredProductsError => _featuredProductsError;
String? get pharmacyProductsError => _pharmacyProductsError;
String? get marketProductsError => _marketProductsError;
```

#### Compatibilidade:
- Método `loadRandomProducts()` marcado como `@Deprecated` mas funcional
- Getter `randomProducts` retorna união das 3 listas
- Código antigo continua funcionando

---

### HomePage (`lib/pages/home/home_page.dart`)

#### Novos Widgets:
1. **`_buildProdutosEmDestaque()`**
   - Usa `catalog.featuredProducts`
   - Estados independentes de loading/error
   - Filtro de busca com `_filterFeaturedProducts()`

2. **`_buildFarmacia()`** (NOVO)
   - Usa `catalog.pharmacyProducts`
   - Ícone: `Icons.local_pharmacy`
   - Título: "Farmácia"
   - Mesmo padrão visual das outras seções

3. **`_buildMercado()`** (NOVO)
   - Usa `catalog.marketProducts`
   - Ícone: `Icons.shopping_cart`
   - Título: "Mercado"
   - Mesmo padrão visual das outras seções

#### Novos Métodos de Filtro:
```dart
List<dynamic> _filterFeaturedProducts(List<dynamic> products)
List<dynamic> _filterPharmacyProducts(List<dynamic> products)
List<dynamic> _filterMarketProducts(List<dynamic> products)
```

#### CustomScrollView Atualizado:
```dart
slivers: [
  // ...promotional carousel, search, restaurants
  
  SliverToBoxAdapter(child: _buildProdutosEmDestaque()),
  const SliverToBoxAdapter(child: SizedBox(height: 32)),
  
  SliverToBoxAdapter(child: _buildFarmacia()),
  const SliverToBoxAdapter(child: SizedBox(height: 32)),
  
  SliverToBoxAdapter(child: _buildMercado()),
  const SliverToBoxAdapter(child: SizedBox(height: 100)),
]
```

#### Carregamento Inicial:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  final catalog = context.read<CatalogProvider>();
  Future.wait([
    catalog.loadRestaurants(),
    catalog.loadFeaturedProducts(),
    catalog.loadPharmacyProducts(),
    catalog.loadMarketProducts(),
  ]);
});
```

#### Pull-to-Refresh:
```dart
Future<void> _onRefresh() async {
  await Future.wait([
    catalog.loadRestaurants(),
    catalog.loadFeaturedProducts(force: true),
    catalog.loadPharmacyProducts(force: true),
    catalog.loadMarketProducts(force: true),
  ]);
}
```

---

## ✅ Benefícios da Nova Arquitetura

### 1. **Distribuição Justa de Produtos**
- Limite `perRestaurant` evita que restaurantes populares dominem todas as seções
- Produtos em Destaque: max 10 produtos/restaurante
- Farmácia/Mercado: max 40 produtos/restaurante

### 2. **Mais Produtos Visíveis**
- ANTES: 50 produtos total
- DEPOIS: 130 produtos total (50+40+40)

### 3. **Melhor UX/UI**
- Separação clara entre categorias
- Usuário encontra produtos específicos mais facilmente
- Cada seção tem seu próprio ícone visual

### 4. **Performance**
- Carregamento paralelo das 3 listas
- Estados de loading independentes (uma falha não afeta as outras)
- Auto-refresh inteligente a cada 5 minutos

### 5. **Escalabilidade**
- Fácil adicionar novas seções
- Fácil ajustar categorias/limites
- Backend preparado para paginação futura

### 6. **Manutenibilidade**
- Código modular e reutilizável
- Cada seção funciona independentemente
- Compatibilidade mantida com código antigo

---

## 🎯 Próximos Passos (Futuro)

### Possíveis Melhorias:
1. **Paginação**: Carregar mais produtos ao rolar a seção
2. **Filtros Avançados**: Preço, distância, rating
3. **Ordenação**: Mais relevante, menor preço, maior rating
4. **Favoritos**: Salvar produtos favoritos
5. **Histórico**: Mostrar produtos visualizados recentemente
6. **Recomendações**: IA para sugerir produtos baseado em histórico

---

## 📝 Versão

- **Versão Anterior**: 1.0.14+15
- **Versão Atual**: 1.0.15+16
- **Data**: 22 de Dezembro de 2025

---

## 👨‍💻 Desenvolvido por

PedeJá Team
