# 🔴 CORREÇÕES CRÍTICAS APLICADAS + PENDÊNCIAS

**Data:** 16 de janeiro de 2026  
**Status:** ✅ Flutter CORRIGIDO | ⚠️ Backend PENDENTE

---

## ✅ CONFIRMADO: App USA API, NÃO Firestore

### Como funciona:
```
PaymentMethodPage (Flutter)
  └─ BackendOrderService.createOrder()
     └─ POST https://api-pedeja.vercel.app/api/orders
        └─ Backend Node.js (index.js)
           └─ Cria pedido + Split + Mercado Pago
```

**Arquivo:** `lib/pages/checkout/payment_method_page.dart` (linha 307)
```dart
final orderId = await _backendOrderService.createOrder(
  token: token,
  restaurantId: widget.restaurantId,
  // ... dados do pedido
);
```

✅ **NÃO usa Firestore diretamente no Flutter!**

---

## ✅ CORREÇÃO 1: Removido campo `subsidy` do modelo

### ❌ ANTES (ERRADO):
```dart
class DeliveryFeeTier {
  final double minValue;
  final double maxValue;
  final double customerPays;
  final double subsidy;  // ❌ ESTAVA SALVANDO NO BANCO!
}
```

### ✅ DEPOIS (CORRETO):
```dart
class DeliveryFeeTier {
  final double minValue;
  final double maxValue;
  final double customerPays;
  // subsidy NÃO é campo!
  
  /// ✅ Subsídio é CALCULADO, não salvo!
  double calculateSubsidy(double realDeliveryFee) {
    return realDeliveryFee - customerPays;
  }
}
```

**Arquivo modificado:** `lib/models/dynamic_delivery_fee_model.dart`

**Por quê?**
- Subsídio deve ser SEMPRE calculado: `deliveryFee - customerPays`
- Se estiver salvo no banco e a taxa real mudar, fica inconsistente!
- Backend calcula automaticamente ao criar pedido

---

## ✅ CORREÇÃO 2: Recalcular subsídio SEMPRE

### ❌ ANTES (ERRADO):
```dart
double calculateRestaurantSubsidy(restaurant, subtotal) {
  final tier = findTier(subtotal);
  return tier.subsidy; // ❌ Lia do banco!
}
```

### ✅ DEPOIS (CORRETO):
```dart
double calculateRestaurantSubsidy(restaurant, subtotal) {
  final customerPays = calculateRestaurantDeliveryFee(restaurant, subtotal);
  final realDeliveryFee = restaurant.deliveryFee;
  
  // ✅ SEMPRE calcula: taxa real - taxa que cliente paga
  return realDeliveryFee - customerPays;
}
```

**Arquivo modificado:** `lib/state/cart_state.dart`

**Por quê?**
- Garante que subsídio está SEMPRE correto
- Mesmo se banco tiver dados antigos/errados
- Fonte única de verdade: `deliveryFee` do restaurante

---

## ✅ CORREÇÃO 3: Fallback sem `subsidy`

### ❌ ANTES:
```dart
orElse: () => DeliveryFeeTier(
  minValue: 0,
  customerPays: restaurant.deliveryFee,
  subsidy: 0,  // ❌ Campo que não existe mais!
),
```

### ✅ DEPOIS:
```dart
orElse: () => DeliveryFeeTier(
  minValue: 0,
  customerPays: restaurant.deliveryFee,
  // subsidy é calculado dinamicamente!
),
```

**Arquivo modificado:** `lib/state/cart_state.dart`

---

## 🔴 PENDÊNCIAS CRÍTICAS (Backend)

### ⚠️ FALTA: Validações completas no endpoint

**Endpoint:** `POST /api/restaurants/:restaurantId/dynamic-delivery-fee`  
**Arquivo:** `index.js` (linha ~16055)

#### Validações que FALTAM:

```javascript
app.post('/api/restaurants/:restaurantId/dynamic-delivery-fee', async (req, res) => {
  const { enabled, tiers } = req.body;
  const restaurant = await getRestaurant(restaurantId);
  const deliveryFee = restaurant.deliveryFee || 0;
  
  if (enabled && (!tiers || !Array.isArray(tiers) || tiers.length === 0)) {
    return res.status(400).json({ error: 'tiers obrigatório quando enabled=true' });
  }
  
  if (enabled) {
    // ✅ JÁ TEM: Validação de array vazio
    
    // ❌ FALTA 1: Primeira faixa deve começar em 0
    if (tiers[0].minValue !== 0) {
      return res.status(400).json({ 
        error: 'Primeira faixa deve começar em R$ 0,00' 
      });
    }
    
    // ❌ FALTA 2: Última faixa deve ter maxValue: null
    if (tiers[tiers.length - 1].maxValue !== null) {
      return res.status(400).json({ 
        error: 'Última faixa deve ter maxValue: null (sem limite)' 
      });
    }
    
    // ❌ FALTA 3: Validar cada faixa
    for (let i = 0; i < tiers.length; i++) {
      const tier = tiers[i];
      
      // Validar que cliente não paga mais que taxa real
      if (tier.customerPays > deliveryFee) {
        return res.status(400).json({ 
          error: `Faixa ${i + 1}: Cliente não pode pagar mais que taxa real (R$ ${deliveryFee})` 
        });
      }
      
      // Validar que customerPays é >= 0
      if (tier.customerPays < 0) {
        return res.status(400).json({ 
          error: `Faixa ${i + 1}: customerPays não pode ser negativo` 
        });
      }
      
      // ❌ FALTA 4: Validar continuidade (não sobreposição)
      if (i < tiers.length - 1) {
        const next = tiers[i + 1];
        
        if (tier.maxValue !== next.minValue) {
          return res.status(400).json({ 
            error: `Faixas ${i + 1} e ${i + 2} não são contínuas (gap ou sobreposição)` 
          });
        }
      }
      
      // ❌ FALTA 5: Validar ordem crescente
      if (tier.minValue >= tier.maxValue && tier.maxValue !== null) {
        return res.status(400).json({ 
          error: `Faixa ${i + 1}: minValue deve ser menor que maxValue` 
        });
      }
    }
    
    // ✅ CRÍTICO: Calcular subsídio automaticamente (NÃO confiar no cliente!)
    for (let tier of tiers) {
      tier.subsidy = deliveryFee - tier.customerPays; // ← Recalcula sempre!
    }
  }
  
  // Salvar no Firestore...
});
```

---

## 🔴 PENDÊNCIA MÁXIMA: Painel dos Parceiros

### ❌ SEM PAINEL = FUNCIONALIDADE INUTILIZADA

**Situação atual:**
- ✅ Backend tem endpoint pronto
- ✅ Flutter implementado e corrigido
- ❌ **FALTA:** Interface para restaurantes configurarem faixas

**O que precisa:**

```
Site dos Parceiros
└─ Menu: Configurações
   └─ Submenu: Taxa de Entrega
      └─ Página: Configurar Taxa Dinâmica
         ├─ Toggle: Ativar/Desativar
         ├─ Lista de Faixas:
         │  ├─ Faixa 1: R$ 0-20 → Cliente paga R$ 5
         │  ├─ Faixa 2: R$ 20-50 → Cliente paga R$ 3
         │  └─ Faixa 3: R$ 50+ → Cliente paga R$ 0 (grátis)
         ├─ Botão: [+ Adicionar Faixa]
         ├─ Simulador: "Pedido de R$ 35 → Taxa R$ 3"
         └─ Botão: [💾 Salvar]
```

**Tecnologias sugeridas:**
- React.js ou Vue.js
- Formulário com validação client-side
- Chama `POST /api/restaurants/:id/dynamic-delivery-fee`

**Validações no front-end:**
```javascript
function validateTiers(tiers, deliveryFee) {
  if (tiers.length === 0) {
    return 'Adicione pelo menos 1 faixa';
  }
  
  if (tiers[0].minValue !== 0) {
    return 'Primeira faixa deve começar em R$ 0';
  }
  
  if (tiers[tiers.length - 1].maxValue !== null) {
    return 'Última faixa deve ser "Sem limite"';
  }
  
  for (let tier of tiers) {
    if (tier.customerPays > deliveryFee) {
      return `Cliente não pode pagar mais que R$ ${deliveryFee}`;
    }
  }
  
  // Validar continuidade...
  
  return null; // OK
}
```

---

## 📊 COMPARAÇÃO: Antes vs Depois

### Campo `subsidy`:

| Aspecto | ❌ ANTES (Errado) | ✅ DEPOIS (Correto) |
|---------|------------------|---------------------|
| **Armazenamento** | Salvo no Firestore | NÃO salvo |
| **Origem** | Vem do banco | Calculado dinamicamente |
| **Cálculo** | `tier.subsidy` | `deliveryFee - customerPays` |
| **Consistência** | ❌ Pode ficar desatualizado | ✅ Sempre correto |
| **Performance** | Leitura direta | Cálculo leve (subtração) |

### Exemplo prático:

**Cenário:** Restaurante muda `deliveryFee` de R$ 5 para R$ 6

❌ **ANTES (com subsidy salvo):**
```javascript
// Firestore (dados antigos):
{
  deliveryFee: 6.00,  // ← Atualizado
  dynamicDeliveryFee: {
    tiers: [
      { minValue: 0, maxValue: 20, customerPays: 5, subsidy: 0 },   // ← ERRADO!
      { minValue: 20, maxValue: 50, customerPays: 3, subsidy: 2 },  // ← ERRADO!
      { minValue: 50, maxValue: null, customerPays: 0, subsidy: 5 } // ← ERRADO!
    ]
  }
}

// Flutter lê subsidy do banco:
// Pedido R$ 35 → subsidy = 2 (errado! deveria ser 3)
```

✅ **DEPOIS (subsidy calculado):**
```javascript
// Firestore (apenas necessário):
{
  deliveryFee: 6.00,
  dynamicDeliveryFee: {
    tiers: [
      { minValue: 0, maxValue: 20, customerPays: 5 },   // subsidy calculado: 6-5=1
      { minValue: 20, maxValue: 50, customerPays: 3 },  // subsidy calculado: 6-3=3 ✅
      { minValue: 50, maxValue: null, customerPays: 0 } // subsidy calculado: 6-0=6
    ]
  }
}

// Flutter calcula:
// Pedido R$ 35 → subsidy = 6 - 3 = 3 ✅ CORRETO!
```

---

## ✅ CHECKLIST FINAL

### Flutter (App Mobile)
- [x] ✅ Modelo sem campo `subsidy`
- [x] ✅ Cálculo dinâmico de subsídio
- [x] ✅ Fallback correto sem `subsidy`
- [x] ✅ Usa API (BackendOrderService)
- [x] ✅ Sem erros de compilação

### Backend (API Node.js)
- [x] ✅ Endpoint criado
- [x] ✅ Validação de array vazio
- [ ] ❌ Validar primeira faixa = 0
- [ ] ❌ Validar última faixa = null
- [ ] ❌ Validar customerPays <= deliveryFee
- [ ] ❌ Validar continuidade (sem gaps)
- [ ] ❌ Recalcular subsídio ao salvar

### Painel Parceiros (Web)
- [ ] ❌ Página de configuração de taxa
- [ ] ❌ Formulário com validações
- [ ] ❌ Simulador de cálculo
- [ ] ❌ Integração com API

---

## 🚀 PRÓXIMOS PASSOS (Prioridade)

### 1. 🔴 URGENTE: Completar validações backend
**Tempo estimado:** 30 minutos  
**Arquivo:** `index.js` (linha ~16055)  
**Ação:** Adicionar validações faltantes

### 2. 🔴 CRÍTICO: Criar Painel dos Parceiros
**Tempo estimado:** 4-6 horas  
**Tecnologia:** React/Vue  
**Ação:** Interface completa de configuração

### 3. 🟡 Testar fluxo completo
**Tempo estimado:** 1 hora  
**Ação:** 
- Configurar faixas no painel
- Fazer pedido no app
- Verificar valores corretos

---

## 📝 RESUMO EXECUTIVO

### O que foi corrigido agora:
✅ Flutter não salva/lê `subsidy` do banco  
✅ Subsídio SEMPRE calculado dinamicamente  
✅ Código mais robusto e consistente  

### O que ainda falta:
❌ Validações completas no backend  
❌ Painel dos parceiros para configurar  

### Status atual:
**Flutter:** ✅ Pronto e corrigido  
**Backend:** ⚠️ Funcional mas falta validações  
**Painel:** ❌ Não existe ainda  

**Conclusão:** Sistema tecnicamente correto no Flutter, mas **INUTILIZÁVEL EM PRODUÇÃO** sem o painel dos parceiros!

---

