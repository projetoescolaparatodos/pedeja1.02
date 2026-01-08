# Guia de Implementação - Sistema de Taxa de Entrega Variável

**Data:** 07/01/2026  
**Versão da API:** v3_with_delivery_fee  
**Status:** Mudanças aplicadas na API ✅

---

## 📋 SUMÁRIO EXECUTIVO

Este documento detalha as mudanças implementadas na API PedeJá para suportar **taxas de entrega variáveis por restaurante** e fornece orientações completas para atualização do **App Flutter** e do **Site de Parceiros (Admin)**.

### O que mudou?
- ✅ API agora aceita `deliveryFee` como campo opcional no pedido
- ✅ Split de pagamento atualizado: `marketplace_fee = (subtotal × 12%) + deliveryFee`
- ✅ Restaurante recebe 88% do subtotal (sem a taxa de entrega)
- ✅ Plataforma recebe 12% do subtotal + 100% da taxa de entrega
- ✅ Taxa de entrega será repassada manualmente ao entregador
- ✅ Retrocompatibilidade garantida: pedidos sem `deliveryFee` funcionam normalmente (taxa = R$ 0,00)

---

## 🔄 MUDANÇAS NA API (JÁ IMPLEMENTADAS)

### 1. Endpoint: `POST /api/orders/create`

#### O que mudou:
- Agora aceita campo **`deliveryFee`** (opcional, número)
- Valida se `totalAmount = subtotal + deliveryFee`
- Salva `subtotal`, `deliveryFee` e `totalAmount` separadamente

#### Novo payload esperado:
```json
{
  "restaurantId": "abc123",
  "items": [...],
  "deliveryAddress": {...},
  "paymentMethod": "credit_card",
  "subtotal": 45.00,          // NOVO: total dos produtos
  "deliveryFee": 5.00,        // NOVO: taxa de entrega (pode ser 0)
  "totalAmount": 50.00        // subtotal + deliveryFee
}
```

#### Retrocompatibilidade:
Se `deliveryFee` não for enviado:
- API assume `deliveryFee = 0`
- `subtotal = totalAmount`
- Pedido é criado normalmente

---

### 2. Endpoint: `POST /api/payments/mp/create-with-split` (Cartão)

#### O que mudou:
- Busca `deliveryFee` e `subtotal` do pedido
- Calcula marketplace_fee: `(subtotal × 0.12) + deliveryFee`
- Restaurante recebe 88% do **subtotal** (não do total)
- Plataforma recebe 12% do subtotal + 100% da taxa de entrega

#### Nova estrutura de split:
```javascript
{
  subtotal: 45.00,              // Soma dos produtos
  deliveryFee: 5.00,            // Taxa de entrega
  total: 50.00,                 // subtotal + deliveryFee
  platformFee: 10.40,           // (45 × 12%) + 5 = 5.40 + 5.00
  platformFeeFromSubtotal: 5.40,
  platformFeeFromDelivery: 5.00,
  restaurantAmount: 39.60,      // 45 × 88%
  restaurantPercent: 88,
  splitVersion: 'v3_with_delivery_fee'
}
```

---

### 3. Endpoint: `POST /api/payment/create` (Alias Flutter)

#### O que mudou:
- Mesmas mudanças do endpoint principal
- Resposta agora inclui `subtotal` e `deliveryFee` separados

#### Nova resposta:
```json
{
  "success": true,
  "paymentId": "pref_123",
  "initPoint": "https://...",
  "subtotal": 45.00,
  "deliveryFee": 5.00,
  "total": 50.00,
  "platformFee": 10.40,
  "restaurantAmount": 39.60,
  "splitVersion": "v3_with_delivery_fee"
}
```

---

### 4. Endpoint: `POST /api/payments/create-pix` (PIX)

#### O que mudou:
- Busca `deliveryFee` e `subtotal` do pedido
- Aplica mesma lógica de split do cartão
- Metadados incluem informações de taxa de entrega

---

## 📱 MUDANÇAS NECESSÁRIAS NO APP FLUTTER

### PRIORIDADE: ALTA ⚠️

### 1. Buscar Taxa de Entrega do Restaurante

**Onde:** Tela de detalhes do restaurante / Antes de abrir o carrinho

**O que fazer:**
1. Ao carregar dados do restaurante, buscar campo `deliveryFee` do Firestore
2. Exibir a taxa de entrega na tela do restaurante
3. Armazenar essa informação para usar no checkout

**Exemplo de estrutura Firestore:**
```
restaurants/{restaurantId}
  ├─ name: "Pizzaria Xingu"
  ├─ address: "..."
  ├─ deliveryFee: 5.00  ← NOVO CAMPO (cada restaurante define o seu)
  └─ ...
```

**Como exibir:**
```
Nome: Pizzaria Xingu
Taxa de entrega: R$ 5,00
Tempo de entrega: 30-40 min
```

---

### 2. Atualizar Tela do Carrinho

**Onde:** Checkout / Carrinho de compras

**O que fazer:**
1. Calcular subtotal (soma dos produtos)
2. Adicionar taxa de entrega do restaurante
3. Exibir separadamente:
   - Subtotal dos produtos
   - Taxa de entrega
   - Total a pagar

**Layout sugerido:**
```
┌─────────────────────────────────────┐
│ Resumo do Pedido                     │
├─────────────────────────────────────┤
│ Subtotal (produtos)    R$ 45,00     │
│ Taxa de entrega        R$  5,00     │
├─────────────────────────────────────┤
│ TOTAL A PAGAR          R$ 50,00     │
└─────────────────────────────────────┘
```

**Observação importante:**
- Se `deliveryFee = 0`, exibir "Entrega grátis!" ou ocultar a linha
- Sempre mostrar o subtotal separado do total

---

### 3. Modificar Criação de Pedido

**Onde:** Ao confirmar pedido (antes de enviar para API)

**Payload atualizado para `POST /api/orders/create`:**
```dart
final orderPayload = {
  'restaurantId': restaurantId,
  'items': cartItems,
  'deliveryAddress': address,
  'paymentMethod': selectedPaymentMethod,
  'subtotal': calculateSubtotal(),      // NOVO: soma dos produtos
  'deliveryFee': restaurant.deliveryFee, // NOVO: taxa do restaurante
  'totalAmount': calculateTotal(),       // subtotal + deliveryFee
};
```

**Funções auxiliares:**
```dart
double calculateSubtotal() {
  return cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
}

double calculateTotal() {
  return calculateSubtotal() + (restaurant.deliveryFee ?? 0.0);
}
```

---

### 4. Atualizar Processamento de Pagamento

**Onde:** Ao criar pagamento (cartão ou PIX)

**Observações:**
- **Não é necessário enviar** `deliveryFee` novamente no pagamento
- A API busca automaticamente do pedido
- Payload de pagamento continua igual:
  ```dart
  {
    'orderId': orderId,
    'paymentMethod': 'credit_card'
  }
  ```

---

### 5. Exibir Detalhes do Pagamento

**Onde:** Tela de confirmação / Histórico de pedidos

**O que fazer:**
1. Ao buscar detalhes do pedido, mostrar:
   - Subtotal
   - Taxa de entrega
   - Total pago
2. Usar informações do campo `payment.split`

**Exemplo de exibição:**
```
Pedido #12345 - Confirmado

Produtos:           R$ 45,00
Taxa de entrega:    R$  5,00
─────────────────────────────
Total pago:         R$ 50,00

Forma de pagamento: Cartão de crédito
```

---

### 6. Tratamento de Casos Especiais

#### Entrega Grátis (deliveryFee = 0):
```dart
if (restaurant.deliveryFee == null || restaurant.deliveryFee == 0) {
  // Exibir badge "ENTREGA GRÁTIS"
  // Ou mostrar "Taxa de entrega: Grátis"
}
```

#### Restaurante sem taxa configurada:
```dart
// Se deliveryFee não existe no Firestore, assumir 0
final deliveryFee = restaurant.deliveryFee ?? 0.0;
```

#### Validação antes de enviar:
```dart
// Garantir que total está correto
assert(totalAmount == subtotal + deliveryFee, 'Total inválido!');
```

---

## 🌐 MUDANÇAS NECESSÁRIAS NO SITE DE PARCEIROS (ADMIN)

### PRIORIDADE: MÉDIA

### 1. Adicionar Campo de Configuração

**Onde:** Painel do restaurante / Configurações / Dados do estabelecimento

**O que fazer:**
1. Criar formulário para configurar taxa de entrega
2. Permitir que restaurante defina valor de 0 (grátis) até qualquer valor

**Interface sugerida:**
```
┌─────────────────────────────────────────────────────┐
│ Configurações de Entrega                             │
├─────────────────────────────────────────────────────┤
│                                                       │
│ Taxa de Entrega:                                     │
│ ┌──────────────┐                                     │
│ │ R$ [  5.00 ] │  (Digite 0 para entrega grátis)    │
│ └──────────────┘                                     │
│                                                       │
│ ℹ️ Esta taxa será cobrada em todos os pedidos       │
│    e você não receberá este valor (vai para          │
│    plataforma repassar ao entregador).               │
│                                                       │
│ Exemplos:                                            │
│ • R$ 0,00 = Entrega grátis                          │
│ • R$ 3,00 = Taxa de R$ 3 por pedido                 │
│ • R$ 5,00 = Taxa de R$ 5 por pedido                 │
│                                                       │
│ [ Salvar Configuração ]                              │
└─────────────────────────────────────────────────────┘
```

---

### 2. Atualizar Firestore

**Onde:** Ao salvar configurações

**Operação:**
```javascript
// Exemplo de atualização
await db.collection('restaurants').doc(restaurantId).update({
  deliveryFee: parseFloat(deliveryFeeInput) // Ex: 5.00
});
```

**Validações:**
- Valor mínimo: 0 (grátis)
- Valor máximo: sugerido 20.00 (opcional)
- Aceitar apenas números com até 2 casas decimais

---

### 3. Exibir em Relatórios Financeiros

**Onde:** Relatórios / Histórico de vendas / Dashboard

**O que mostrar:**
Ao exibir detalhes de um pedido no painel admin:

```
Pedido #12345 - 07/01/2026

┌─────────────────────────────────────────────┐
│ Valores do Pedido                            │
├─────────────────────────────────────────────┤
│ Subtotal (produtos):        R$ 45,00        │
│ Taxa de entrega:            R$  5,00        │
│ Total pago pelo cliente:    R$ 50,00        │
├─────────────────────────────────────────────┤
│ Divisão de Pagamento                         │
├─────────────────────────────────────────────┤
│ Você recebe (88% produtos): R$ 39,60        │
│ Taxa plataforma (12%):      R$  5,40        │
│ Taxa entrega (plataforma):  R$  5,00        │
│ Taxa Mercado Pago (~5%):    R$  2,50        │
└─────────────────────────────────────────────┘

ℹ️ A taxa de entrega vai para a plataforma
   e será repassada ao entregador.
```

---

### 4. Dashboard de Estatísticas

**Onde:** Página inicial do painel / Analytics

**Métricas sugeridas:**
- Total arrecadado (apenas do subtotal, excluindo taxa de entrega)
- Número de entregas realizadas
- Taxa de entrega média configurada

**Exemplo:**
```
Resumo Mensal - Janeiro 2026

Vendas (produtos):        R$ 4.500,00
Entregas realizadas:      150 pedidos
Sua taxa de entrega:      R$ 5,00
Total em entregas:        R$ 750,00 (vai para plataforma)
─────────────────────────────────────────────
Você recebeu:            R$ 3.960,00 (88%)
Taxa da plataforma:      R$ 540,00 (12%)
```

---

## 🔒 VALIDAÇÕES E SEGURANÇA

### No App Flutter:
1. ✅ Validar que `subtotal + deliveryFee = totalAmount` antes de enviar
2. ✅ Não permitir valores negativos
3. ✅ Exibir erro claro se API rejeitar por total inválido

### No Site Admin:
1. ✅ Validar que deliveryFee >= 0
2. ✅ Limitar a 2 casas decimais
3. ✅ Confirmar antes de salvar mudanças

### Segurança (já implementado na API):
- ✅ API valida total do pedido no backend
- ✅ API recalcula split no backend (não confia no cliente)
- ✅ Logs detalhados de cálculos de split

---

## 📊 EXEMPLOS PRÁTICOS

### Exemplo 1: Restaurante com taxa de R$ 5,00
```
Cliente pede:
- Pizza G (R$ 35,00)
- Refrigerante (R$ 10,00)
────────────────────────
Subtotal:           R$ 45,00
Taxa de entrega:    R$  5,00
────────────────────────
TOTAL:              R$ 50,00

Divisão:
- Restaurante:      R$ 39,60 (88% de R$ 45)
- Plataforma:       R$  5,40 (12% de R$ 45)
- Taxa entrega:     R$  5,00 (100% plataforma)
- MP fee (~5%):     R$  2,50 (descontado automaticamente)
```

### Exemplo 2: Restaurante com entrega grátis (R$ 0,00)
```
Cliente pede:
- Lanche (R$ 25,00)
────────────────────────
Subtotal:           R$ 25,00
Taxa de entrega:    GRÁTIS
────────────────────────
TOTAL:              R$ 25,00

Divisão:
- Restaurante:      R$ 22,00 (88%)
- Plataforma:       R$  3,00 (12%)
- Taxa entrega:     R$  0,00
- MP fee (~5%):     R$  1,25
```

### Exemplo 3: Restaurante com taxa de R$ 8,00
```
Cliente pede:
- Produtos diversos (R$ 100,00)
────────────────────────
Subtotal:           R$ 100,00
Taxa de entrega:    R$   8,00
────────────────────────
TOTAL:              R$ 108,00

Divisão:
- Restaurante:      R$  88,00 (88% de R$ 100)
- Plataforma:       R$  12,00 (12% de R$ 100)
- Taxa entrega:     R$   8,00 (100% plataforma)
- MP fee (~5%):     R$   5,40 (descontado automaticamente)
```

---

## ⚠️ PONTOS DE ATENÇÃO

### CRÍTICO - NÃO QUEBRAR FLUXO EXISTENTE:

1. **Pedidos antigos sem deliveryFee:**
   - API assume `deliveryFee = 0` automaticamente
   - App deve tratar `deliveryFee` como campo opcional
   - Exibir "Entrega grátis" se não houver taxa

2. **Restaurantes sem taxa configurada:**
   - Tratar como `deliveryFee = 0`
   - Permitir criar pedidos normalmente
   - Não bloquear compra

3. **Compatibilidade PIX e Cartão:**
   - Ambos endpoints atualizados
   - Mesmo cálculo de split
   - Mesma estrutura de dados

4. **Logs e Debug:**
   - API gera logs detalhados de cálculo de split
   - Incluem breakdown de `platformFeeFromSubtotal` e `platformFeeFromDelivery`
   - Facilita auditoria

---

## 🧪 TESTES SUGERIDOS

### App Flutter:
1. ✅ Criar pedido com taxa de R$ 5,00
2. ✅ Criar pedido com entrega grátis (R$ 0,00)
3. ✅ Validar exibição de subtotal + taxa + total
4. ✅ Testar pagamento com PIX e Cartão
5. ✅ Verificar histórico de pedidos exibe taxa corretamente

### Site Admin:
1. ✅ Configurar taxa de entrega
2. ✅ Salvar valor 0 (entrega grátis)
3. ✅ Validar que aceita apenas números válidos
4. ✅ Ver relatórios com split correto
5. ✅ Confirmar que deliveryFee é salvo no Firestore

### API (já testada internamente):
- ✅ Endpoint `/api/orders/create` aceita deliveryFee
- ✅ Endpoint `/api/payment/create` calcula split corretamente
- ✅ Endpoint PIX aplica marketplace_fee
- ✅ Retrocompatibilidade com pedidos antigos

---

## 📞 SUPORTE E DÚVIDAS

### Para desenvolvedores do App:
- Verificar campo `deliveryFee` em `restaurants/{id}` no Firestore
- Usar `subtotal` + `deliveryFee` = `totalAmount`
- Não confiar em cálculos do cliente, API valida tudo

### Para desenvolvedores do Admin:
- Campo `deliveryFee` é número (float) com 2 decimais
- Valor mínimo: 0 (grátis)
- Salvar diretamente no documento do restaurante

### Campos Firestore atualizados:
```javascript
// Collection: restaurants
{
  deliveryFee: 5.00  // NOVO CAMPO
}

// Collection: orders
{
  subtotal: 45.00,         // NOVO CAMPO
  deliveryFee: 5.00,       // NOVO CAMPO
  totalAmount: 50.00,      // Mantido
  payment: {
    split: {
      subtotal: 45.00,
      deliveryFee: 5.00,
      total: 50.00,
      platformFee: 10.40,
      platformFeeFromSubtotal: 5.40,
      platformFeeFromDelivery: 5.00,
      restaurantAmount: 39.60,
      restaurantPercent: 88,
      splitVersion: 'v3_with_delivery_fee'
    }
  }
}
```

---

## 🚀 CRONOGRAMA SUGERIDO

### Fase 1 - App Flutter (1-2 dias):
1. Buscar `deliveryFee` do restaurante
2. Exibir no carrinho (subtotal + taxa + total)
3. Enviar payload atualizado para API
4. Testar fluxo completo

### Fase 2 - Site Admin (1 dia):
1. Criar campo de configuração
2. Salvar no Firestore
3. Atualizar relatórios para mostrar split

### Fase 3 - Testes (1 dia):
1. Testar com restaurantes reais
2. Validar cálculos de split
3. Confirmar compatibilidade

---

## ✅ CHECKLIST FINAL

### App Flutter:
- [ ] Busca `deliveryFee` do restaurante no Firestore
- [ ] Exibe taxa de entrega na tela do restaurante
- [ ] Calcula subtotal separadamente
- [ ] Exibe subtotal + taxa + total no carrinho
- [ ] Envia `subtotal` e `deliveryFee` no payload
- [ ] Trata entrega grátis (R$ 0,00) corretamente
- [ ] Histórico mostra split detalhado

### Site Admin:
- [ ] Campo para configurar taxa de entrega
- [ ] Validação de valores (≥ 0)
- [ ] Salva `deliveryFee` no Firestore
- [ ] Relatórios mostram split correto
- [ ] Dashboard exibe estatísticas de entrega

### API (já concluído):
- [x] Endpoint `/api/orders/create` aceita deliveryFee
- [x] Endpoint `/api/payments/mp/create-with-split` calcula split
- [x] Endpoint `/api/payment/create` (alias) atualizado
- [x] Endpoint `/api/payments/create-pix` inclui marketplace_fee
- [x] Retrocompatibilidade garantida
- [x] Logs detalhados de cálculos

---

**Fim do documento**

*Última atualização: 07/01/2026*  
*Versão: 1.0*  
*Status: Mudanças de API aplicadas, aguardando implementação nos clientes*
