# 📊 ANÁLISE: Implementação de Taxa de Entrega Dinâmica

**Data:** 16 de janeiro de 2026  
**Documento:** Análise técnica do plano de taxa dinâmica  
**Status:** ✅ Pronto para implementação

---

## 🎯 OBJETIVO PRINCIPAL

Implementar um sistema de **taxa de entrega variável** conforme o valor do pedido, permitindo que restaurantes ofereçam:
- ✅ Desconto na entrega para pedidos pequenos
- ✅ Frete grátis para pedidos acima de um valor
- ✅ Estratégia comercial customizada por faixa de valor

---

## 📋 RESUMO DO QUE VAI MUDAR

### ❌ O QUE **NÃO** MUDA
1. **Sistema de split financeiro** - Continua 88/12 + débitos
2. **Débitos automáticos** - Continuam funcionando igual
3. **Taxas dinâmicas (PIX 11%, Cartão 12%)** - Não mudam
4. **Sistema antigo de taxa parcial** - Mantém compatibilidade

### ✅ O QUE VAI MUDAR
1. **Configuração de faixas de taxa** - Restaurante configura via painel
2. **Cálculo de taxa no momento da criação do pedido** - Dinâmico por valor
3. **UI do carrinho no app** - Mostra taxa atualizada em tempo real
4. **Dados no Firestore** - Novo campo `dynamicDeliveryFee` em restaurants

---

## 🏗️ ARQUITETURA TÉCNICA ATUAL DO PROJETO

### Estrutura de Pastas (Flutter)

```
lib/
├── models/
│   ├── restaurant_model.dart       ← Dados do restaurante
│   ├── cart_item.dart              ← Item no carrinho
│   ├── product_model.dart          ← Produto
│   ├── order_model.dart            ← Pedido
│   └── ...
├── pages/
│   ├── cart/
│   │   └── cart_page.dart          ← Tela do carrinho
│   ├── checkout/
│   │   ├── checkout_page.dart      ← Tela de checkout
│   │   └── payment_method_page.dart
│   ├── restaurant/
│   │   └── restaurant_detail_page.dart
│   └── ...
├── providers/
│   └── catalog_provider.dart
├── state/
│   ├── auth_state.dart             ← Estado de autenticação
│   ├── cart_state.dart             ← Estado do carrinho
│   └── ...
├── services/
│   ├── order_service.dart          ← Serviço de pedidos
│   ├── payment_service.dart        ← Serviço de pagamento
│   └── ...
└── main.dart
```

### Como Funciona Atualmente

```
1. PRODUTO → Usuário adiciona ao carrinho
   └─ CartState armazena: id, name, price, addons, restaurantId

2. CARRINHO → Mostra subtotal e taxa fixa
   └─ Calcula: subtotal + deliveryFee = total

3. CHECKOUT → Coleta endereço e método de pagamento
   └─ Envia para API: items, total, deliveryFee

4. API (Backend) → Cria pedido e split financeiro
   └─ Calcula: restaurante (88%), plataforma (12%)
```

---

## 🔧 O QUE PRECISA SER IMPLEMENTADO

### PARTE 1: Modelos de Dados (Dart) - 🟢 CRÍTICA

#### 1.1 Novo Arquivo: `lib/models/dynamic_delivery_fee_model.dart`

**Responsabilidade:** Definir estrutura de taxa dinâmica

```dart
// Configuração de taxa dinâmica
class DynamicDeliveryFeeConfig {
  final bool enabled;
  final List<DeliveryFeeTier> tiers;
  
  DynamicDeliveryFeeConfig({
    required this.enabled,
    required this.tiers,
  });
  
  factory DynamicDeliveryFeeConfig.fromMap(Map<String, dynamic> map) {
    return DynamicDeliveryFeeConfig(
      enabled: map['enabled'] ?? false,
      tiers: (map['tiers'] as List<dynamic>?)
          ?.map((t) => DeliveryFeeTier.fromMap(t))
          .toList() ?? [],
    );
  }
}

// Faixa de taxa (ex: R$ 0-20 = R$ 5, R$ 20-50 = R$ 3)
class DeliveryFeeTier {
  final double minValue;
  final double? maxValue;  // null = infinito
  final double customerPays;
  final double subsidy;
  
  DeliveryFeeTier({
    required this.minValue,
    this.maxValue,
    required this.customerPays,
    required this.subsidy,
  });
  
  factory DeliveryFeeTier.fromMap(Map<String, dynamic> map) {
    return DeliveryFeeTier(
      minValue: (map['minValue'] ?? 0).toDouble(),
      maxValue: map['maxValue']?.toDouble(),
      customerPays: (map['customerPays'] ?? 0).toDouble(),
      subsidy: (map['subsidy'] ?? 0).toDouble(),
    );
  }
  
  // Verifica se o valor do pedido está nesta faixa
  bool matches(double orderValue) {
    final minMatch = orderValue >= minValue;
    final maxMatch = maxValue == null || orderValue < maxValue!;
    return minMatch && maxMatch;
  }
}
```

**Localização:** Criar novo arquivo  
**Tamanho:** ~60 linhas  
**Complexidade:** 🟢 Baixa

---

#### 1.2 Modificar: `lib/models/restaurant_model.dart`

**O que muda:** Adicionar campo `dynamicDeliveryFee`

**Antes:**
```dart
class RestaurantModel {
  // ... campos existentes ...
  final double deliveryFee;
  final double? customerDeliveryFee;
}
```

**Depois:**
```dart
class RestaurantModel {
  // ... campos existentes ...
  final double deliveryFee;
  final double? customerDeliveryFee;
  final DynamicDeliveryFeeConfig? dynamicDeliveryFee;  // ← NOVO
  
  // factory RestaurantModel.fromJson() TAMBÉM MUDA
  // para parsear: data['dynamicDeliveryFee']
}
```

**Localização:** Linha ~15-80 do arquivo  
**Tamanho:** ~10 linhas de mudanças  
**Complexidade:** 🟢 Baixa

---

### PARTE 2: Lógica de Cálculo (CartState) - 🟠 IMPORTANTE

#### 2.1 Modificar: `lib/state/cart_state.dart`

**Responsabilidade:** Calcular taxa dinâmica ao adicionar/remover itens

**O que será adicionado:**

```dart
class CartState extends ChangeNotifier {
  // ... código existente ...
  
  // 💰 Calcula subtotal sem taxa de entrega
  double calculateSubtotal() {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }
  
  // 🚚 Calcula taxa de entrega (NOVA LÓGICA)
  double calculateDeliveryFee(RestaurantModel? restaurant) {
    if (restaurant == null) return 0;
    
    final subtotal = calculateSubtotal();
    
    // 1. VERIFICAR TAXA DINÂMICA (prioridade)
    if (restaurant.dynamicDeliveryFee?.enabled == true) {
      final tiers = restaurant.dynamicDeliveryFee!.tiers;
      
      // Encontrar faixa que corresponde ao valor
      final matchedTier = tiers.firstWhere(
        (tier) => tier.matches(subtotal),
        orElse: () => DeliveryFeeTier(
          minValue: 0,
          customerPays: restaurant.deliveryFee,
          subsidy: 0,
        ),
      );
      
      return matchedTier.customerPays;
    }
    
    // 2. SISTEMA ANTIGO (compatibilidade)
    if (restaurant.customerDeliveryFee != null && 
        restaurant.customerDeliveryFee! < restaurant.deliveryFee) {
      return restaurant.customerDeliveryFee!;
    }
    
    // 3. TAXA PADRÃO
    return restaurant.deliveryFee;
  }
  
  // 💰 Calcula subsídio do restaurante
  double calculateSubsidy(RestaurantModel? restaurant) {
    if (restaurant == null) return 0;
    
    final customerPays = calculateDeliveryFee(restaurant);
    final totalFee = restaurant.deliveryFee;
    
    return totalFee - customerPays;
  }
  
  // 💰 Calcula total que cliente paga (subtotal + entrega)
  double calculateTotal(RestaurantModel? restaurant) {
    final subtotal = calculateSubtotal();
    final deliveryFee = calculateDeliveryFee(restaurant);
    
    return subtotal + deliveryFee;
  }
}
```

**Localização:** Adicionar após método `getRestaurantSubtotal()`  
**Tamanho:** ~50 linhas de código novo  
**Complexidade:** 🟠 Média

---

### PARTE 3: Interface do Carrinho - 🟡 ESTÉTICA

#### 3.1 Modificar: `lib/pages/cart/cart_page.dart`

**Responsabilidade:** Exibir taxa atualizada em tempo real + indicador de frete grátis

**Mudanças principais:**

1. **Mostrar taxa dinâmica no resumo final:**
   - Ao lado da taxa, adicionar ícone 🔄 indicando que varia
   - Tooltip: "Taxa varia com o valor do pedido"

2. **Adicionar barra de progresso (se próximo de frete grátis):**
   - "Faltam R$ 25,00 para frete grátis! 🚀"
   - Mostra quanto cliente economizaria

3. **Atualizar em tempo real:**
   - Quando subtotal muda → taxa recalcula
   - Quando taxa muda → total atualiza

**Exemplo de UI:**
```
┌─────────────────────────────────────────┐
│ Subtotal              R$ 35,00           │
├─────────────────────────────────────────┤
│ Taxa de Entrega  🔄  R$ 3,00             │
│ (varia com pedido)                       │
├─────────────────────────────────────────┤
│ 📊 Faltam R$ 15,00 para frete grátis!  │
│    Você economizaria R$ 3,00             │
├─────────────────────────────────────────┤
│ TOTAL                 R$ 38,00           │
└─────────────────────────────────────────┘
```

**Localização:** Método `_buildCartSummary()`, linha ~350  
**Tamanho:** ~30-40 linhas de mudanças  
**Complexidade:** 🟡 Média (CSS/Layout)

---

### PARTE 4: Serviço de Pedidos - 🟠 CRÍTICA

#### 4.1 Modificar: `lib/services/order_service.dart`

**Responsabilidade:** Enviar valores corretos para API

**O que muda:**

```dart
class OrderService {
  Future<String> createOrder({
    required RestaurantModel restaurant,
    required List<CartItem> items,
    required String paymentMethod,
    required String deliveryAddress,
  }) async {
    // ... código existente ...
    
    // NOVO: Calcular taxa dinâmica
    final subtotal = _calculateSubtotal(items);
    final deliveryFee = _calculateDeliveryFee(restaurant, subtotal);
    final restaurantSubsidy = _calculateSubsidy(restaurant, subtotal);
    
    // Montar objeto completo para API
    final deliveryData = {
      'totalFee': restaurant.deliveryFee,     // Taxa REAL (entregador)
      'customerPaid': deliveryFee,            // Taxa que cliente paga
      'restaurantSubsidy': restaurantSubsidy, // Quanto restaurante subsidia
    };
    
    // Enviar para API
    final response = await http.post(
      Uri.parse('$API_BASE/api/orders/create'),
      body: jsonEncode({
        'items': items,
        'subtotal': subtotal,
        'delivery': deliveryData,  // ← IMPORTANTE: incluir tudo
        'paymentMethod': paymentMethod,
        // ... outros campos ...
      }),
    );
    
    // ... resto do código ...
  }
}
```

**Localização:** Método `createOrder()`, linha ~50-120  
**Tamanho:** ~20 linhas de mudanças  
**Complexidade:** 🟠 Média

---

## 📱 RESUMO: Arquivos a Modificar

### ✨ Novos Arquivos (criar)
| Arquivo | Propósito | Linhas |
|---------|-----------|--------|
| `lib/models/dynamic_delivery_fee_model.dart` | Classes DynamicDeliveryFeeConfig e DeliveryFeeTier | ~60 |

### 🔧 Arquivos a Modificar (Flutter)
| Arquivo | Seção | Linhas | Dificuldade |
|---------|-------|--------|-------------|
| `lib/models/restaurant_model.dart` | Adicionar campo `dynamicDeliveryFee` | ~10 | 🟢 Fácil |
| `lib/state/cart_state.dart` | Adicionar métodos de cálculo | ~50 | 🟠 Média |
| `lib/pages/cart/cart_page.dart` | Mostrar taxa dinâmica e progresso | ~40 | 🟡 Estética |
| `lib/services/order_service.dart` | Enviar dados corretos para API | ~20 | 🟠 Média |

### ✅ Arquivos JÁ Implementados (Backend)
```
✅ index.js (linha ~7365)    - Cálculo de taxa dinâmica ao criar pedido
✅ index.js (linha ~13012)   - GET /api/restaurants/:id com config
✅ index.js (linha ~16055)   - POST /api/restaurants/:id/dynamic-delivery-fee
```

---

## 🔄 FLUXO DE FUNCIONAMENTO

### 1️⃣ USUÁRIO ADICIONA PRODUTOS

```
App (Flutter)
└─ Usuario adiciona 3 produtos (R$ 35 subtotal)
   └─ CartState.addItem() chamado
      └─ CartState._items atualizado
         └─ notifyListeners() ← UI se atualiza
```

### 2️⃣ CARRINHO RECALCULA TAXA

```
CartPage (consome CartState)
└─ Rebuilda lista
   └─ Lê restaurant.dynamicDeliveryFee (se existe)
      └─ Chama cart.calculateDeliveryFee(restaurant)
         └─ Encontra faixa: R$ 20-50 → R$ 3,00
            └─ Mostra taxa atualizada na UI
```

### 3️⃣ USUÁRIO FINALIZA PEDIDO

```
CheckoutPage
└─ Chama OrderService.createOrder()
   └─ Calcula delivery novamente
      └─ Envia para API:
         {
           items: [...],
           subtotal: 35.00,
           delivery: {
             totalFee: 5.00,      (taxa real)
             customerPaid: 3.00,  (taxa que cliente paga)
             restaurantSubsidy: 2.00  (subsídio)
           }
         }
```

### 4️⃣ API CALCULA SPLIT

```
Backend (index.js - já feito)
└─ Recebe pedido com delivery data
   └─ Entregador recebe: R$ 5,00
      └─ Restaurante paga: R$ 2,00 de subsídio
         └─ Cliente paga: R$ 3,00 de entrega
            └─ Split calcula corretamente:
               Restaurante: 88% - R$ 2,00 = X
               Plataforma: 12% + R$ 5,00 - R$ 2,00 = Y
               Soma: X + Y + MP = Total ✅
```

---

## 🎯 VALIDAÇÕES IMPORTANTES

### No Flutter (Client-side)
- ✅ Verificar se `restaurant.dynamicDeliveryFee` existe
- ✅ Verificar se está `enabled: true`
- ✅ Encontrar faixa correta baseado em `subtotal`
- ✅ Fallback: usar `deliveryFee` padrão se não encontrar faixa

### No Backend (já implementado)
- ✅ Primeira faixa começa em 0
- ✅ Última faixa tem maxValue: null (infinito)
- ✅ Cliente não paga mais que taxa real
- ✅ Calcular subsídio automaticamente

---

## 📊 EXEMPLO PRÁTICO COMPLETO

### Cenário: Restaurante com Taxa Dinâmica

**Configuração no Firestore:**
```javascript
restaurants/{id}: {
  name: "Burger King",
  deliveryFee: 5.00,  // Taxa REAL
  dynamicDeliveryFee: {
    enabled: true,
    tiers: [
      { minValue: 0,  maxValue: 20, customerPays: 5.00, subsidy: 0 },
      { minValue: 20, maxValue: 50, customerPays: 3.00, subsidy: 2.00 },
      { minValue: 50, maxValue: null, customerPays: 0, subsidy: 5.00 }
    ]
  }
}
```

### Usuário 1: Pede R$ 15 de hambúrguer

```
1. Adiciona ao carrinho (subtotal: R$ 15)
2. CartPage calcula taxa:
   - Busca faixa com minValue ≤ 15 e maxValue > 15
   - Encontra: { minValue: 0, maxValue: 20, customerPays: 5.00 }
   - Taxa = R$ 5,00

3. Mostra no carrinho:
   Subtotal: R$ 15,00
   Taxa:     R$ 5,00  ← Cliente paga tudo
   Total:    R$ 20,00

4. Finaliza, API recebe:
   - deliveryFee: 5.00 (taxa real)
   - customerPaid: 5.00 (cliente paga)
   - restaurantSubsidy: 0 (não subsidia)

5. Split:
   - Restaurante: 15 × 0.88 = R$ 13,20
   - Plataforma: 15 × 0.12 + 5 = R$ 6,80
   - MP: 20,00 × 0.99% ≈ R$ 0,20
   ✅ Total: R$ 13,20 + R$ 6,80 + R$ 0,20 = R$ 20,00
```

### Usuário 2: Pede R$ 35 de hambúrguer

```
1. Adiciona ao carrinho (subtotal: R$ 35)
2. CartPage calcula taxa:
   - Busca faixa com minValue ≤ 35 e maxValue > 35
   - Encontra: { minValue: 20, maxValue: 50, customerPays: 3.00 }
   - Taxa = R$ 3,00

3. Mostra no carrinho:
   Subtotal: R$ 35,00
   Taxa:     R$ 3,00  ← Cliente paga menos!
   Total:    R$ 38,00
   
   💡 "Faltam R$ 15,00 para frete grátis! 🚀"

4. Finaliza, API recebe:
   - deliveryFee: 5.00 (taxa real)
   - customerPaid: 3.00 (cliente paga)
   - restaurantSubsidy: 2.00 (restaurante subsidia)

5. Split:
   - Restaurante: 35 × 0.88 - 2.00 = R$ 28,80
   - Plataforma: 35 × 0.12 + 5.00 - 2.00 = R$ 8,80
   - MP: 38,00 × 0.99% ≈ R$ 0,38
   ✅ Total: R$ 28,80 + R$ 8,80 + R$ 0,38 = R$ 38,00
```

### Usuário 3: Pede R$ 60 de hambúrguer

```
1. Adiciona ao carrinho (subtotal: R$ 60)
2. CartPage calcula taxa:
   - Busca faixa com minValue ≤ 60
   - Encontra: { minValue: 50, maxValue: null, customerPays: 0 }
   - Taxa = R$ 0,00

3. Mostra no carrinho:
   Subtotal: R$ 60,00
   Taxa:     GRÁTIS! 🎉
   Total:    R$ 60,00

4. Finaliza, API recebe:
   - deliveryFee: 5.00 (taxa real)
   - customerPaid: 0 (cliente não paga)
   - restaurantSubsidy: 5.00 (restaurante paga tudo)

5. Split:
   - Restaurante: 60 × 0.88 - 5.00 = R$ 47,80
   - Plataforma: 60 × 0.12 + 5.00 - 5.00 = R$ 7,20
   - MP: 60,00 × 0.99% ≈ R$ 0,60
   ✅ Total: R$ 47,80 + R$ 7,20 + R$ 0,60 = R$ 60,00
```

---

## ⚠️ PONTOS CRÍTICOS

### 1. Compatibilidade com Sistema Antigo
- Se `dynamicDeliveryFee` não existe → usar `customerDeliveryFee`
- Se `customerDeliveryFee` não existe → usar `deliveryFee`
- **Cascata de fallback:** dinâmica → parcial → padrão

### 2. Precisão de Cálculo
- Sempre usar `.toDouble()` para conversões
- Arredondar para 2 casas decimais: `.toStringAsFixed(2)`
- **Nunca** fazer cálculos com String

### 3. Sincronização Entrega ↔ UI
- Quando usuário adiciona/remove item → taxa pode mudar
- CartState notifica → CartPage rebuilda
- Total é recalculado automaticamente

### 4. Dados Corretos para API
- Enviar sempre `deliveryFee` (taxa real)
- Enviar sempre `customerDeliveryFee` (o que cliente paga)
- Enviar sempre `restaurantSubsidy` (diferença)

---

## 🚀 PRÓXIMOS PASSOS RECOMENDADOS

### Ordem de Implementação
1. ✅ **Criar modelo de dados** (`dynamic_delivery_fee_model.dart`)
2. ✅ **Modificar RestaurantModel** (adicionar campo)
3. ✅ **Atualizar CartState** (adicionar cálculos)
4. ✅ **Modificar CartPage** (exibir taxa dinâmica)
5. ✅ **Atualizar OrderService** (enviar dados corretos)
6. ✅ **Testar fluxo completo**

### Testes Sugeridos
```
Teste 1: Carrinho com pedido de R$ 15
├─ Taxa deve ser R$ 5,00 ✅
├─ Total deve ser R$ 20,00 ✅
└─ API deve receber: customerPaid: 5, subsidy: 0 ✅

Teste 2: Carrinho com pedido de R$ 35
├─ Taxa deve ser R$ 3,00 ✅
├─ Mostrar "Faltam R$ 15 para grátis" ✅
├─ Total deve ser R$ 38,00 ✅
└─ API deve receber: customerPaid: 3, subsidy: 2 ✅

Teste 3: Carrinho com pedido de R$ 60
├─ Taxa deve ser GRÁTIS ✅
├─ Total deve ser R$ 60,00 ✅
└─ API deve receber: customerPaid: 0, subsidy: 5 ✅
```

---

## 📚 DOCUMENTAÇÃO DE REFERÊNCIA

- **Plano completo:** [PLANO_TAXA_ENTREGA_DINAMICA.md](PLANO_TAXA_ENTREGA_DINAMICA.md)
- **Backend já implementado:** `index.js` (verificado ✅)
- **API endpoint:** `POST /api/restaurants/:restaurantId/dynamic-delivery-fee`

---

## ✅ CONCLUSÃO

O backend está **100% pronto**. A implementação no Flutter é **direta e modular**:

- ✅ Sem mudanças complexas
- ✅ Compatível com sistema existente
- ✅ Fácil de testar
- ✅ Pronto para deploy

**Tempo estimado:** 3-4 horas para implementação completa + testes.

---

