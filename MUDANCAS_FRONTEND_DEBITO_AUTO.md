# 📱 Mudanças nos Frontends - Sistema de Débito Automático

**Data:** 08/01/2026  
**Versão:** 1.0  
**Status:** Especificação para Implementação

---

## 🎯 VISÃO GERAL

Com a implementação do **Sistema de Débito Automático** no backend, são necessárias atualizações nos frontends para que restaurantes e usuários possam visualizar e gerenciar débitos.

### ✅ Backend Implementado:
- [x] 5 endpoints de gestão de débitos
- [x] Lógica de criação de débito em pedidos cash
- [x] Desconto automático em pedidos cartão/PIX
- [x] Sistema de notificações

### 📝 Frontend Necessário:
- [ ] **App Flutter** - Nenhuma mudança necessária (transparente para usuário)
- [ ] **Painel dos Parceiros** - Dashboard financeiro completo
- [ ] **Painel Admin** - Dashboard de monitoramento

---

## 📱 APP FLUTTER (Cliente)

### ✅ NENHUMA MUDANÇA NECESSÁRIA! 

**Motivo:** O sistema de débito automático é **100% transparente** para o cliente final.

#### O que o cliente vê:
- ✅ Faz pedido normalmente
- ✅ Paga normalmente (dinheiro, cartão ou PIX)
- ✅ Recebe notificações de status do pedido

#### O que acontece nos bastidores:
- 🔒 Restaurante acumula débito (pedidos em dinheiro)
- 🔒 Restaurante paga automaticamente (pedidos em cartão)
- 🔒 Tudo gerenciado pela plataforma

**Conclusão:** ❌ Nenhuma modificação no app Flutter!

---

## 🏪 PAINEL DOS PARCEIROS (Restaurante)

### 📊 MUDANÇAS NECESSÁRIAS

O painel dos parceiros precisa de uma nova seção completa para gestão financeira.

---

### 1️⃣ NOVA ABA: "FINANCEIRO"

**Localização:** Menu lateral principal (mesmo nível de "Pedidos", "Produtos", etc.)

**Ícone sugerido:** 💰 ou 💳

**Estrutura:**
```
📱 Menu Lateral
├── 📦 Pedidos
├── 🍕 Produtos
├── 📊 Relatórios
├── 💰 Financeiro  ← NOVO!
│   ├── Resumo
│   ├── Débitos Pendentes
│   ├── Histórico
│   └── Configurações
└── ⚙️ Configurações
```

---

### 2️⃣ TELA: RESUMO FINANCEIRO

**Rota:** `/financeiro` ou `/financial`

**Endpoint Backend:**
```
GET /api/admin/debts/:restaurantId/summary
Authorization: Bearer {token}
```

**Resposta:**
```json
{
  "restaurant": {
    "id": "rest123",
    "name": "Pizzaria do João",
    "email": "joao@pizza.com"
  },
  "debt": {
    "current": 85.00,
    "limit": 150.00,
    "available": 65.00,
    "percentage": 56.67,
    "status": "ok"
  },
  "pendingOrders": {
    "count": 7,
    "total": 85.00,
    "list": [...]
  },
  "estimates": {
    "nextDeduction": 40.00,
    "debtAfterNext": 45.00
  },
  "settings": {
    "autoDebitEnabled": true,
    "preferredMethod": "auto-debit"
  }
}
```

**Layout da Tela:**

```
┌─────────────────────────────────────────────────────────────┐
│ 💰 SITUAÇÃO FINANCEIRA                                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐  ┌───────────────────────┐       │
│  │ 💳 CRÉDITOS          │  │ 📊 DÉBITOS            │       │
│  │ R$ 150,00            │  │ R$ 85,00              │       │
│  │ ✅ Disponível        │  │ de R$ 150,00 (57%)    │       │
│  │                      │  │                       │       │
│  │ [Recarregar]         │  │ ⚠️ Atenção            │       │
│  └──────────────────────┘  │ [Pagar Agora]         │       │
│                            └───────────────────────┘       │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │ 📈 PROGRESSO DO DÉBITO                       │          │
│  │                                               │          │
│  │ R$ 85 / R$ 150                                │          │
│  │ [████████████░░░░░░░░] 57%                   │          │
│  │                                               │          │
│  │ 💡 Faltam R$ 65 para o limite                │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
│  ┌──────────────────────────────────────────────┐          │
│  │ 📋 RESUMO DO MÊS                             │          │
│  │                                               │          │
│  │ Pedidos em dinheiro: 12                       │          │
│  │ Débitos gerados: R$ 144,00                    │          │
│  │ Descontados automaticamente: R$ 59,00         │          │
│  │ Saldo pendente: R$ 85,00                      │          │
│  │                                               │          │
│  │ 💰 Próximo desconto estimado: ~R$ 40          │          │
│  │ (No próximo pedido cartão de ~R$ 67)          │          │
│  └──────────────────────────────────────────────┘          │
│                                                              │
│  [Ver Débitos Pendentes] [Ver Histórico]                   │
└─────────────────────────────────────────────────────────────┘
```

**Cores do Card de Débitos:**
- **Verde** (< 67%): `status: "ok"` - Tudo tranquilo
- **Amarelo** (67-87%): `status: "warning"` - Atenção, chegando no limite
- **Vermelho** (> 87%): `status: "critical"` - Urgente! Pague ou próximo pedido cash será bloqueado
- **Vermelho Escuro** (100%): `status: "blocked"` - Bloqueado! Não pode receber pedidos em dinheiro

**Elementos Interativos:**
1. **Botão "Recarregar"** (Créditos)
   - Abre modal de recarga via PIX
   - Sistema existente (não precisa modificar)

2. **Botão "Pagar Agora"** (Débitos)
   - Abre modal de pagamento de débitos (ver seção 5)

3. **Botão "Ver Débitos Pendentes"**
   - Navega para `/financeiro/debitos`

4. **Botão "Ver Histórico"**
   - Navega para `/financeiro/historico`

---

### 3️⃣ TELA: DÉBITOS PENDENTES

**Rota:** `/financeiro/debitos`

**Endpoint Backend:**
```
GET /api/admin/debts/:restaurantId/summary
```

**Layout da Tela:**

```
┌─────────────────────────────────────────────────────────────┐
│ 📋 DÉBITOS PENDENTES                                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ 💰 Total: R$ 85,00  |  Limite: R$ 150,00  |  Disponível: R$ 65,00 │
│                                                              │
│ ┌──────────────────────────────────────────────────┐       │
│ │ 📦 Pedido #1234 - 08/01/2026 14:30               │       │
│ │                                                   │       │
│ │ Valor do pedido: R$ 50,00 (dinheiro 💵)          │       │
│ │ Débito gerado: R$ 12,00                          │       │
│ │   • Comissão (12%): R$ 6,00                      │       │
│ │   • Taxa de entrega: R$ 6,00                     │       │
│ │                                                   │       │
│ │ Status: ⏳ Aguardando desconto automático        │       │
│ │                                                   │       │
│ │ [Ver Pedido]                                     │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ ┌──────────────────────────────────────────────────┐       │
│ │ 📦 Pedido #1235 - 08/01/2026 16:15               │       │
│ │                                                   │       │
│ │ Valor do pedido: R$ 35,00 (dinheiro 💵)          │       │
│ │ Débito gerado: R$ 8,40                           │       │
│ │   • Comissão (12%): R$ 4,20                      │       │
│ │   • Taxa de entrega: R$ 4,20                     │       │
│ │                                                   │       │
│ │ Status: ⏳ Aguardando desconto automático        │       │
│ │                                                   │       │
│ │ [Ver Pedido]                                     │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ ... (mais 5 pedidos)                                        │
│                                                              │
│ ┌──────────────────────────────────────────────────┐       │
│ │ 💡 COMO FUNCIONA O DESCONTO AUTOMÁTICO?          │       │
│ │                                                   │       │
│ │ Quando você receber um pedido em CARTÃO ou PIX,  │       │
│ │ descontaremos automaticamente até 60% do valor   │       │
│ │ do pedido para pagar seus débitos pendentes.     │       │
│ │                                                   │       │
│ │ Exemplo: Pedido de R$ 100 → Desconta até R$ 60  │       │
│ │                                                   │       │
│ │ Quer pagar antes? [Pagar Agora via PIX]          │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ [← Voltar] [Pagar Tudo Agora] [Configurações]              │
└─────────────────────────────────────────────────────────────┘
```

**Funcionalidades:**

1. **Lista de Pedidos Pendentes**
   - Mostra todos os pedidos em dinheiro com débito `pending`
   - Ordenados por data (mais antigos primeiro - FIFO)
   - Cada card mostra:
     - Número e data/hora do pedido
     - Valor total do pedido
     - Breakdown do débito (comissão + entrega)
     - Status atual

2. **Botão "Ver Pedido"**
   - Abre modal ou navega para detalhes do pedido
   - Usa rota existente de visualização de pedidos

3. **Botão "Pagar Tudo Agora"**
   - Abre modal de pagamento (ver seção 5)

4. **Botão "Configurações"**
   - Navega para `/financeiro/configuracoes`

---

### 4️⃣ TELA: HISTÓRICO DE TRANSAÇÕES

**Rota:** `/financeiro/historico`

**Endpoint Backend:**
```
GET /api/admin/debts/:restaurantId/history?limit=50
```

**Resposta:**
```json
{
  "history": [
    {
      "orderId": "order456",
      "orderNumber": "1230",
      "createdAt": "2026-01-07T10:30:00Z",
      "paymentMethod": "credit_card",
      "subtotal": 100.00,
      "platformFee": 12.00,
      "status": "deducted",
      "deductedFrom": null,
      "deductedAt": null,
      "deductions": {
        "normalFee": 12.00,
        "deliveryFee": 6.00,
        "debtDeductions": [
          {
            "orderId": "order123",
            "amount": 12.00,
            "description": "Pedido em dinheiro #1220"
          },
          {
            "orderId": "order124",
            "amount": 12.00,
            "description": "Pedido em dinheiro #1221"
          }
        ],
        "totalDeducted": 36.00,
        "restaurantReceived": 76.00
      }
    }
  ],
  "stats": {
    "totalDebtsCreated": 12,
    "totalDebtsDeducted": 8,
    "totalPaidWithCredits": 2,
    "totalAmountDebts": 144.00,
    "totalAmountDeducted": 96.00
  }
}
```

**Layout da Tela:**

```
┌─────────────────────────────────────────────────────────────┐
│ 📊 HISTÓRICO DE TRANSAÇÕES                                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ 📈 Estatísticas do Período                                  │
│                                                              │
│ Débitos criados: 12  |  Descontados: 8  |  Com créditos: 2 │
│ Total gerado: R$ 144  |  Total descontado: R$ 96           │
│                                                              │
│ ────────────────────────────────────────────────────────── │
│                                                              │
│ ✅ Desconto aplicado - 07/01/2026 10:30                    │
│ ┌──────────────────────────────────────────────────┐       │
│ │ 💳 Pedido cartão: #1230 (R$ 100,00)              │       │
│ │                                                   │       │
│ │ Descontado: R$ 24,00 (24% do pedido)             │       │
│ │                                                   │       │
│ │ Débitos quitados:                                │       │
│ │ • Pedido #1220: R$ 12,00 ✅                      │       │
│ │ • Pedido #1221: R$ 12,00 ✅                      │       │
│ │                                                   │       │
│ │ Você recebeu: R$ 76,00                           │       │
│ │ (Em vez de R$ 88,00 normal)                      │       │
│ │                                                   │       │
│ │ [Ver Comprovante MP]                             │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ 💵 Débito criado - 06/01/2026 18:45                        │
│ ┌──────────────────────────────────────────────────┐       │
│ │ 💵 Pedido dinheiro: #1225 (R$ 45,00)             │       │
│ │                                                   │       │
│ │ Débito gerado: R$ 10,80                          │       │
│ │ • Comissão: R$ 5,40                              │       │
│ │ • Entrega: R$ 5,40                               │       │
│ │                                                   │       │
│ │ Status: ⏳ Pendente                              │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ 💳 Pagamento manual - 05/01/2026 14:00                     │
│ ┌──────────────────────────────────────────────────┐       │
│ │ 💰 Valor pago: R$ 50,00 (PIX)                    │       │
│ │                                                   │       │
│ │ Débitos zerados: 4 pedidos                       │       │
│ │                                                   │       │
│ │ [Ver Comprovante]                                │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ [Carregar Mais]                                             │
└─────────────────────────────────────────────────────────────┘
```

**Tipos de Transação:**

1. **✅ Desconto Automático** (`status: "deducted"`)
   - Cor: Verde
   - Ícone: 💳 ou ✅
   - Mostra pedido cartão/PIX que gerou o desconto
   - Lista débitos quitados
   - Mostra valor líquido recebido

2. **💵 Débito Criado** (`status: "pending"`)
   - Cor: Amarelo/Laranja
   - Ícone: 💵 ou ⏳
   - Mostra pedido dinheiro que gerou débito
   - Breakdown: comissão + entrega

3. **💳 Pagamento Manual**
   - Cor: Azul
   - Ícone: 💰
   - Mostra valor pago e método (PIX/Transferência)
   - Quantos débitos foram zerados

4. **💳 Pago com Créditos** (`status: "paid_with_credits"`)
   - Cor: Verde claro
   - Ícone: 💳
   - Mostra que foi descontado do saldo de créditos

**Filtros (opcional):**
```
[Período: Últimos 30 dias ▼] [Tipo: Todos ▼] [Buscar...]
```

---

### 5️⃣ MODAL: PAGAR DÉBITOS

**Quando aparece:**
- Botão "Pagar Agora" (tela Resumo)
- Botão "Pagar Tudo Agora" (tela Débitos Pendentes)

**Endpoint Backend:**
```
POST /api/admin/debts/:restaurantId/pay
Authorization: Bearer {token}
Content-Type: application/json

{
  "amount": 85.00,
  "method": "pix",
  "note": "Pagamento manual via PIX",
  "receiptUrl": "https://..."
}
```

**Resposta:**
```json
{
  "success": true,
  "payment": {
    "amount": 85.00,
    "method": "pix",
    "paidOrders": 7,
    "remainingDebt": 0
  },
  "message": "Pagamento de R$ 85.00 registrado com sucesso"
}
```

**Layout do Modal:**

```
┌────────────────────────────────────────────┐
│ 💳 PAGAR DÉBITOS                           │
├────────────────────────────────────────────┤
│                                             │
│ Débito atual: R$ 85,00                     │
│                                             │
│ ○ Pagar tudo (R$ 85,00)                    │
│ ○ Pagar parcial: R$ [____]                 │
│                                             │
│ Método de pagamento:                        │
│ ● PIX (instantâneo)                        │
│ ○ Transferência (até 24h)                  │
│                                             │
│ ┌─────────────────────────────────────┐   │
│ │ 📱 PIX COPIA E COLA                 │   │
│ │                                      │   │
│ │ Valor: R$ 85,00                     │   │
│ │ Favorecido: PedeJá Ltda             │   │
│ │ CNPJ: XX.XXX.XXX/XXXX-XX            │   │
│ │                                      │   │
│ │ Chave PIX:                          │   │
│ │ pedeja@pagamentos.com               │   │
│ │ [Copiar Chave]                      │   │
│ │                                      │   │
│ │ OU                                   │   │
│ │                                      │   │
│ │ [QR CODE]                           │   │
│ │ [Baixar QR Code]                    │   │
│ └─────────────────────────────────────┘   │
│                                             │
│ Após fazer o PIX:                           │
│ ☐ Já fiz o PIX                             │
│ ☐ Anexar comprovante                       │
│   [Escolher arquivo...]                    │
│                                             │
│ Observações (opcional):                     │
│ [_________________________________]        │
│                                             │
│ [Cancelar] [Confirmar Pagamento]           │
└────────────────────────────────────────────┘
```

**Fluxo:**

1. **Usuário escolhe valor**
   - Todo o débito (padrão)
   - Ou valor parcial (mínimo R$ 10)

2. **Usuário escolhe método**
   - PIX (recomendado - instantâneo)
   - Transferência bancária

3. **Sistema mostra dados para pagamento**
   - Chave PIX ou dados bancários
   - QR Code (se PIX)

4. **Usuário faz pagamento**
   - Copia chave PIX OU
   - Escaneia QR Code OU
   - Faz transferência manual

5. **Usuário confirma e anexa comprovante**
   - Marca checkbox "Já fiz o PIX"
   - Anexa print/PDF do comprovante
   - Adiciona observação (opcional)

6. **Sistema registra pagamento**
   - Chama endpoint POST
   - Mostra mensagem de sucesso
   - Atualiza telas automaticamente

**Validações:**
- ✅ Valor deve ser > R$ 0
- ✅ Valor não pode ser maior que débito atual
- ✅ Comprovante é opcional (pode validar depois no admin)
- ✅ Método obrigatório

---

### 6️⃣ TELA: CONFIGURAÇÕES DE DÉBITO

**Rota:** `/financeiro/configuracoes`

**Endpoints Backend:**

**GET (carregar configurações atuais):**
```
GET /api/admin/debts/:restaurantId/summary
```

**PUT (atualizar configurações):**
```
PUT /api/admin/debts/:restaurantId/settings
Authorization: Bearer {token}
Content-Type: application/json

{
  "autoDebitEnabled": true,
  "autoDebitLimit": 200,
  "preferredMethod": "hybrid"
}
```

**Layout da Tela:**

```
┌─────────────────────────────────────────────────────────────┐
│ ⚙️ CONFIGURAÇÕES DE DÉBITO AUTOMÁTICO                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ 🔧 MÉTODO DE PAGAMENTO PREFERIDO                            │
│                                                              │
│ ○ Créditos Pré-Pagos                                        │
│   Você recarrega antes, sem surpresas                       │
│   Ideal se você quer controle total                         │
│                                                              │
│ ● Débito Automático (RECOMENDADO)                           │
│   Paga depois, desconta automaticamente                     │
│   Ideal para começar rápido                                 │
│   Limite: R$ 150,00                                         │
│                                                              │
│ ○ Híbrido                                                   │
│   Usa créditos primeiro, depois débito                      │
│   Melhor dos dois mundos                                    │
│                                                              │
│ ────────────────────────────────────────────────────────── │
│                                                              │
│ ⚡ CONFIGURAÇÕES AVANÇADAS                                  │
│                                                              │
│ Débito automático:                                          │
│ [✓] Habilitado  [ ] Desabilitado                           │
│                                                              │
│ Limite de débito:                                           │
│ R$ [150] (Mínimo: R$ 50 | Máximo: R$ 500)                  │
│ [────────●───────────] R$ 150                              │
│                                                              │
│ Notificações:                                               │
│ [✓] Notificar quando atingir 70% do limite                 │
│ [✓] Bloquear pedidos em dinheiro ao atingir limite         │
│ [ ] Permitir ultrapassar limite (não recomendado)          │
│                                                              │
│ ────────────────────────────────────────────────────────── │
│                                                              │
│ 💡 COMO FUNCIONA?                                           │
│                                                              │
│ Quando HABILITADO:                                          │
│ • Você pode receber pedidos em dinheiro mesmo sem créditos │
│ • Débito acumula até o limite (R$ 150)                     │
│ • Desconta automaticamente dos próximos pedidos cartão/PIX │
│ • Desconto máximo: 60% por pedido                          │
│                                                              │
│ Quando DESABILITADO:                                        │
│ • Precisa ter créditos para receber pedidos em dinheiro    │
│ • Funciona como antes (sistema de créditos puro)           │
│                                                              │
│ ────────────────────────────────────────────────────────── │
│                                                              │
│ [Cancelar] [Salvar Configurações]                          │
└─────────────────────────────────────────────────────────────┘
```

**Opções de Método Preferido:**

1. **Créditos Pré-Pagos**
   - `preferredMethod: "credits"`
   - Desabilita débito automático
   - Sistema antigo (precisa ter saldo)

2. **Débito Automático** (Recomendado)
   - `preferredMethod: "auto-debit"`
   - Habilita débito automático
   - Não precisa de créditos

3. **Híbrido**
   - `preferredMethod: "hybrid"`
   - Tenta usar créditos primeiro
   - Se não tiver, usa débito automático

**Configurações Avançadas:**

1. **Toggle Débito Automático**
   - Liga/desliga sistema
   - Se desligar, volta ao modo créditos

2. **Slider de Limite**
   - Min: R$ 50
   - Max: R$ 500
   - Padrão: R$ 150
   - Atualiza em tempo real

3. **Checkboxes de Notificações**
   - Avisos quando chegar perto do limite
   - Bloqueio automático no limite
   - Opção de ultrapassar (não recomendado)

**Validações:**
- ✅ Limite entre R$ 50 e R$ 500
- ✅ Aviso se desabilitar com débito pendente
- ✅ Confirmação antes de salvar mudanças críticas

---

### 7️⃣ NOTIFICAÇÕES E ALERTAS

**Tipos de Notificação:**

#### 🔔 Push Notification (se implementado)

**Débito R$ 50 (33% do limite):**
```
💰 Débito acumulado
Você tem R$ 50,00 em débitos.
Será descontado automaticamente!
```

**Débito R$ 100 (67% do limite):**
```
⚠️ Débito em R$ 100
Você está com 67% do limite.
Faltam R$ 50 para o limite.
```

**Débito R$ 130 (87% do limite):**
```
🚨 ATENÇÃO: R$ 130 em débitos
Faltam apenas R$ 20 para bloquear
pedidos em dinheiro!
```

**Débito R$ 150 (100% - bloqueado):**
```
❌ Limite atingido!
Pague R$ 150 para voltar a aceitar
pedidos em dinheiro.
[Pagar Agora]
```

**Desconto aplicado:**
```
✅ Débito reduzido!
R$ 24 descontados do pedido #1230.
Débito atual: R$ 61
```

#### 📧 E-mail (se implementado)

Similar às push, mas com mais detalhes e links diretos para:
- Ver débitos pendentes
- Pagar via PIX
- Ver histórico

#### 🔴 Badge no Menu

No ícone "💰 Financeiro" do menu lateral:

- **Badge verde**: Tudo OK (débito < 67%)
- **Badge amarelo**: Atenção (débito 67-87%)
- **Badge vermelho**: Crítico (débito > 87%)
- **Badge vermelho piscando**: Bloqueado (débito = 100%)

```
💰 Financeiro [⚠️ 7]  ← Badge amarelo com número de débitos pendentes
```

---

### 8️⃣ COMPONENTES REUTILIZÁVEIS

**Componente: DebtStatusBadge**
```jsx
<DebtStatusBadge 
  current={85}
  limit={150}
  size="small|medium|large"
/>

// Renderiza:
// ⚠️ 57%  (amarelo se 67-87%)
// 🚨 92%  (vermelho se > 87%)
// ✅ 23%  (verde se < 67%)
```

**Componente: DebtProgressBar**
```jsx
<DebtProgressBar
  current={85}
  limit={150}
  showPercentage={true}
  showValue={true}
/>

// Renderiza:
// R$ 85 / R$ 150
// [████████████░░░░░░░░] 57%
```

**Componente: DebtSummaryCard**
```jsx
<DebtSummaryCard
  debt={debtData}
  onPayNow={() => openPaymentModal()}
/>
```

---

## 🖥️ PAINEL ADMIN (Gestão)

### 📊 MUDANÇAS NECESSÁRIAS

Dashboard de monitoramento para administradores da plataforma.

---

### 1️⃣ NOVA SEÇÃO: DÉBITOS (Dashboard)

**Localização:** Menu admin ou dashboard principal

**Endpoint Backend:**
```
GET /api/admin/debts/dashboard
Authorization: Bearer {admin_token}
```

**Resposta:**
```json
{
  "overview": {
    "totalRestaurants": 156,
    "totalDebt": 12450.00,
    "averageDebt": 79.81,
    "atLimit": 8,
    "nearLimit": 15
  },
  "today": {
    "debtsCreated": 45,
    "amountCreated": 540.00,
    "debtsDeducted": 32,
    "amountDeducted": 384.00
  },
  "topDebtors": [
    {
      "id": "rest123",
      "name": "Pizzaria do João",
      "debt": 145.00,
      "limit": 150.00,
      "percentage": 96.7,
      "status": "critical"
    }
  ]
}
```

**Layout:**

```
┌─────────────────────────────────────────────────────────────┐
│ 📊 DASHBOARD DE DÉBITOS AUTOMÁTICOS                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ 📈 VISÃO GERAL                                              │
│                                                              │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│ │ 🏪 156      │ │ 💰 R$ 12.4k │ │ 📊 R$ 79.81 │           │
│ │ Restaurantes│ │ Débito Total│ │ Média/Rest  │           │
│ └─────────────┘ └─────────────┘ └─────────────┘           │
│                                                              │
│ ┌─────────────┐ ┌─────────────┐                            │
│ │ 🚨 8        │ │ ⚠️ 15       │                            │
│ │ No Limite   │ │ Perto Limite│                            │
│ └─────────────┘ └─────────────┘                            │
│                                                              │
│ ────────────────────────────────────────────────────────── │
│                                                              │
│ 📅 HOJE                                                     │
│                                                              │
│ Débitos criados: 45 (R$ 540,00)                            │
│ Débitos descontados: 32 (R$ 384,00)                        │
│                                                              │
│ ────────────────────────────────────────────────────────── │
│                                                              │
│ 🔝 TOP 10 DEVEDORES                                        │
│                                                              │
│ ┌──────────────────────────────────────────────────┐       │
│ │ 🚨 Pizzaria do João               R$ 145 / R$ 150│       │
│ │    [████████████████████████░] 96.7%             │       │
│ │    [Ver Detalhes] [Entrar em Contato]           │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ ┌──────────────────────────────────────────────────┐       │
│ │ ⚠️ Lanchonete da Maria            R$ 132 / R$ 150│       │
│ │    [████████████████████░░░░] 88%                │       │
│ │    [Ver Detalhes] [Entrar em Contato]           │       │
│ └──────────────────────────────────────────────────┘       │
│                                                              │
│ ... (mais 8 restaurantes)                                   │
│                                                              │
│ [Exportar Relatório] [Filtros Avançados]                   │
└─────────────────────────────────────────────────────────────┘
```

**Funcionalidades:**

1. **Cards de Métricas**
   - Total de restaurantes usando débito
   - Soma de todos os débitos
   - Média por restaurante
   - Alertas (no limite / perto do limite)

2. **Estatísticas do Dia**
   - Novos débitos criados
   - Débitos descontados
   - Valores movimentados

3. **Top Devedores**
   - 10 restaurantes com maior débito
   - Status visual (cores)
   - Ações rápidas (ver detalhes, contatar)

4. **Botões de Ação**
   - Exportar relatório CSV/PDF
   - Filtros avançados (por região, status, etc.)

---

### 2️⃣ TELA: DETALHES DE RESTAURANTE (Débitos)

**Rota:** `/admin/restaurantes/:id/debitos`

**Endpoints:**
- GET `/api/admin/debts/:restaurantId/summary`
- GET `/api/admin/debts/:restaurantId/history`

**Funcionalidades:**

1. **Resumo do Restaurante**
   - Mesmo layout da tela do parceiro
   - Informações adicionais (data cadastro, etc.)

2. **Ações Admin**
   - Ajustar limite manualmente
   - Habilitar/desabilitar débito
   - Zerar débitos (em caso excepcional)
   - Enviar notificação/e-mail

3. **Histórico Completo**
   - Todas as transações
   - Filtros avançados
   - Exportação

---

## 📝 RESUMO DE ENDPOINTS

### Para Painel dos Parceiros:

| Endpoint | Método | Descrição | Usado em |
|----------|--------|-----------|----------|
| `/api/admin/debts/:restaurantId/summary` | GET | Resumo de débitos | Resumo Financeiro, Débitos Pendentes |
| `/api/admin/debts/:restaurantId/history` | GET | Histórico completo | Histórico de Transações |
| `/api/admin/debts/:restaurantId/pay` | POST | Pagar débitos manualmente | Modal Pagar Débitos |
| `/api/admin/debts/:restaurantId/settings` | PUT | Atualizar configurações | Configurações |

### Para Painel Admin:

| Endpoint | Método | Descrição | Usado em |
|----------|--------|-----------|----------|
| `/api/admin/debts/dashboard` | GET | Dashboard geral | Dashboard Admin |
| `/api/admin/debts/:restaurantId/summary` | GET | Detalhes do restaurante | Detalhes |
| `/api/admin/debts/:restaurantId/settings` | PUT | Ajustar configurações | Ações Admin |

---

## 🎨 GUIA DE DESIGN

### Cores Sugeridas:

**Status de Débito:**
- 🟢 Verde (`#10B981`): OK (< 67% do limite)
- 🟡 Amarelo (`#F59E0B`): Atenção (67-87%)
- 🔴 Vermelho (`#EF4444`): Crítico (> 87%)
- ⚫ Vermelho Escuro (`#991B1B`): Bloqueado (100%)

**Tipos de Transação:**
- 💳 Azul (`#3B82F6`): Pagamentos manuais
- 💵 Laranja (`#F97316`): Débitos criados
- ✅ Verde (`#10B981`): Descontos aplicados
- 💰 Roxo (`#8B5CF6`): Créditos

### Ícones:

- 💰 ou 💳: Financeiro (menu)
- 📊: Débitos/Gráficos
- 📋: Lista/Histórico
- ⚙️: Configurações
- 💵: Dinheiro/Cash
- 💳: Cartão
- ✅: Sucesso/Desconto
- ⚠️: Atenção
- 🚨: Crítico
- ❌: Bloqueado/Erro

---

## ✅ CHECKLIST DE IMPLEMENTAÇÃO

### Painel dos Parceiros:

**Estrutura:**
- [ ] Adicionar item "Financeiro" no menu lateral
- [ ] Criar rota `/financeiro`
- [ ] Criar rota `/financeiro/debitos`
- [ ] Criar rota `/financeiro/historico`
- [ ] Criar rota `/financeiro/configuracoes`

**Componentes:**
- [ ] Criar `DebtStatusBadge`
- [ ] Criar `DebtProgressBar`
- [ ] Criar `DebtSummaryCard`
- [ ] Criar `DebtTransactionCard`
- [ ] Criar `PaymentModal`

**Telas:**
- [ ] Implementar "Resumo Financeiro"
- [ ] Implementar "Débitos Pendentes"
- [ ] Implementar "Histórico de Transações"
- [ ] Implementar "Configurações de Débito"
- [ ] Implementar "Modal de Pagamento"

**Funcionalidades:**
- [ ] Integrar API de resumo
- [ ] Integrar API de histórico
- [ ] Integrar API de pagamento
- [ ] Integrar API de configurações
- [ ] Adicionar notificações (opcional)
- [ ] Adicionar badges no menu
- [ ] Adicionar validações de formulário

**Testes:**
- [ ] Testar fluxo completo de visualização
- [ ] Testar pagamento manual
- [ ] Testar alteração de configurações
- [ ] Testar responsividade mobile
- [ ] Testar com diferentes estados de débito

### Painel Admin:

**Telas:**
- [ ] Criar Dashboard de Débitos
- [ ] Criar tela de Detalhes do Restaurante
- [ ] Adicionar ações administrativas

**Funcionalidades:**
- [ ] Integrar API do dashboard
- [ ] Exportação de relatórios
- [ ] Filtros avançados

---

## 🚀 PRIORIZAÇÃO

### Fase 1 (MVP - Essencial):
1. ✅ Resumo Financeiro (tela principal)
2. ✅ Débitos Pendentes (lista)
3. ✅ Modal de Pagamento (PIX)
4. ✅ Configurações básicas (habilitar/desabilitar)

### Fase 2 (Completo):
5. ✅ Histórico de Transações
6. ✅ Configurações avançadas (limite, notificações)
7. ✅ Dashboard Admin
8. ✅ Notificações push/e-mail

### Fase 3 (Melhorias):
9. ⭐ Gráficos e analytics
10. ⭐ Exportação de relatórios
11. ⭐ Filtros avançados
12. ⭐ Previsões e insights

---

## 📞 SUPORTE TÉCNICO

**Dúvidas sobre implementação:**
- Consultar documentação da API
- Ver exemplos de integração existentes
- Contatar equipe de backend

**Endpoints disponíveis:**
- Base URL: `https://api-pedeja.vercel.app`
- Documentação: `/docs` (Swagger)
- Health check: `/api/status`

---

**Criado em:** 08/01/2026  
**Versão:** 1.0  
**Status:** Pronto para implementação

---

🎉 **Boa sorte com a implementação!**
