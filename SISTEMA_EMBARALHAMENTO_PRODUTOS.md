# 🎲 Sistema de Embaralhamento de Produtos

## 📍 Localização: **LOCAL (Flutter App)**

O embaralhamento é feito **inteiramente no app Flutter**, não na API.

**Arquivo:** `lib/providers/catalog_provider.dart`

---

## 🔄 Como Funciona

### 1️⃣ **Recebe Produtos da API** (Ordenados)
```dart
// Linha ~250
final response = await http.get(
  Uri.parse('https://api-pedeja.vercel.app/api/products/featured')
);

final products = productsJson.map((json) => ProductModel.fromJson(json)).toList();
// ↑ Produtos vêm ordenados da API
```

### 2️⃣ **Embaralha Localmente** (Único para cada usuário)
```dart
// Linha 259-260
// 🎲 Shuffle local (personalizado por usuário)
products.shuffle();
```

### 3️⃣ **Salva no Estado**
```dart
// Linha 269
_featuredProducts = products;
debugPrint('✅ ${_featuredProducts.length} produtos em destaque carregados e embaralhados!');
```

---

## ⏱️ **TEMPO ENTRE EMBARALHAMENTOS: 5 MINUTOS**

### Sistema de Auto-Refresh

**Arquivo:** `lib/providers/catalog_provider.dart` (Linhas 112-116)

```dart
void _startAutoRefresh() {
  _refreshTimer?.cancel();
  _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
    debugPrint('🔄 [CatalogProvider] Auto-refresh ativado (5min)');
    // Recarrega restaurantes e produtos silenciosamente
    _silentRefreshRestaurants();
    _silentRefreshProducts();
  });
}
```

### Ciclo de Vida:

```
App Abre
   ↓
[CatalogProvider criado]
   ↓
Produtos baixados da API
   ↓
🎲 SHUFFLE #1
   ↓
⏳ Espera 5 minutos
   ↓
🔄 Auto-refresh (Timer dispara)
   ↓
Produtos baixados novamente
   ↓
🎲 SHUFFLE #2 (nova ordem!)
   ↓
⏳ Espera 5 minutos
   ↓
🔄 Auto-refresh...
   ↓
🎲 SHUFFLE #3
   ↓
(E assim por diante...)
```

---

## 📊 Onde o Shuffle Acontece

### Todos os Tipos de Produto São Embaralhados:

1. **Produtos em Destaque** (Comida)
   - Linha 260: `products.shuffle();`
   - Endpoint: `/api/products/featured`

2. **Produtos de Farmácia**
   - Linha 327: `products.shuffle();`
   - Endpoint: `/api/products/pharmacy`

3. **Produtos de Mercado**
   - Linha 394: `products.shuffle();`
   - Endpoint: `/api/products/market`

4. **Produtos de Bebidas**
   - Linha 461: `products.shuffle();`
   - Endpoint: `/api/products/drinks`

5. **Produtos de Cuidados Pessoais**
   - Linha 528: `products.shuffle();`
   - Endpoint: `/api/products/personal-care`

6. **Produtos de Perfumaria**
   - Linha 595: `products.shuffle();`
   - Endpoint: `/api/products/perfumery`

---

## 🎯 Por Que Isso Foi Implementado?

### Vantagens do Shuffle Local:

1. **Equidade**: Todos os produtos têm chance de aparecer em destaque
2. **Variação**: A cada 5 minutos, usuários veem produtos diferentes
3. **Personalização**: Cada usuário vê uma ordem diferente
4. **Descoberta**: Usuários encontram produtos que não veriam normalmente

### Exemplo Visual:

**João abre o app às 10:00:**
```
[Pizza 🍕] [Hambúrguer 🍔] [Sushi 🍣] [Lasanha 🍝]
```

**Maria abre o app às 10:00 (mesmo momento):**
```
[Sushi 🍣] [Lasanha 🍝] [Pizza 🍕] [Hambúrguer 🍔]
```

**João mantém o app aberto até 10:05 (5 min depois):**
```
[Lasanha 🍝] [Sushi 🍣] [Hambúrguer 🍔] [Pizza 🍕]
```
↑ Nova ordem após auto-refresh!

---

## 🔧 Como Modificar o Tempo

Se quiser mudar de **5 minutos** para outro intervalo:

**Linha 114 do `catalog_provider.dart`:**

```dart
// Atual: 5 minutos
_refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {

// Exemplos de mudança:
_refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) { // 10 min
_refreshTimer = Timer.periodic(const Duration(minutes: 3), (_) {  // 3 min
_refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {    // 1 hora
_refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) { // 30 seg
```

---

## ⚠️ Comportamentos Importantes

### 1. **Shuffle Acontece Sempre Que a Lista é Carregada**
- Ao abrir o app
- Ao fazer pull-to-refresh
- A cada 5 minutos (auto-refresh)

### 2. **É Aleatório (Não Previsível)**
```dart
products.shuffle(); // Usa Math.random() internamente
```
Não há controle de seed, então cada shuffle é completamente aleatório.

### 3. **Silencioso (Não Mostra Loading)**
O auto-refresh é "silencioso" - não mostra spinner de loading para não atrapalhar a UX:

```dart
Future<void> _silentRefreshProducts() async {
  debugPrint('🔄 Refresh silencioso de produtos');
  // Recarrega sem mostrar loading na UI
  await loadFeaturedProducts(force: true);
  // ...
}
```

---

## 📱 Impacto no Usuário

### Cenário Real:

**Usuário navegando no app:**
- 10:00 → Vê produtos na ordem A
- 10:04 → Ainda vê produtos na ordem A
- 10:05 → **Timer dispara!** Produtos recarregam e embaralham
- 10:05:01 → Vê produtos na ordem B (nova!)
- 10:10 → **Timer dispara novamente!** Ordem C

Se o usuário estiver vendo a lista neste momento, pode notar que os produtos "pularam" de posição. Isso é intencional.

---

## 🎲 Resumo Executivo

| Aspecto | Valor |
|---------|-------|
| **Local/API** | 🟢 **LOCAL (Flutter)** |
| **Intervalo** | ⏱️ **5 minutos** |
| **Arquivo** | `lib/providers/catalog_provider.dart` |
| **Linha (Timer)** | 114 |
| **Linhas (Shuffles)** | 260, 327, 394, 461, 528, 595 |
| **Método** | `products.shuffle()` (Dart built-in) |
| **Automático?** | ✅ Sim (Timer periódico) |
| **Afeta todos produtos?** | ✅ Sim (6 categorias) |

---

## 🔍 Como Desativar (Se Necessário)

### Opção 1: Remover Shuffle Completamente
Comentar as linhas de shuffle:
```dart
// products.shuffle(); // ← Comentar esta linha
```

### Opção 2: Desativar Auto-Refresh (Manter shuffle inicial)
Comentar a inicialização do timer:
```dart
CatalogProvider() {
  // _startAutoRefresh(); // ← Comentar esta linha
}
```

### Opção 3: Aumentar Intervalo (Ex: 1 hora)
```dart
_refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
```

---

**Status Atual:** 
- ✅ Shuffle ATIVO 
- ⏱️ Intervalo: 5 minutos
- 📍 Local: Flutter App
- 🎲 Aleatório: Sim
