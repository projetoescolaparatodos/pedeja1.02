# 💵 Sistema de Pagamento em Dinheiro

## 📋 Visão Geral

Sistema completo de pagamento em dinheiro na entrega, integrado com a API backend e Firebase.

## 🎯 Funcionalidades Implementadas

### 1. Seleção de Método de Pagamento
- **Arquivo**: `lib/pages/checkout/payment_method_page.dart`
- Interface para escolher entre:
  - 💵 **Dinheiro na entrega** (cash)
  - 📱 **PIX** (pix)
  - 💳 **Cartão de Crédito** (credit_card) - Em breve
  - 💳 **Cartão de Débito** (debit_card) - Em breve

### 2. Gestão de Troco
Quando o cliente seleciona "Dinheiro na entrega":
- ✅ Checkbox "Preciso de troco"
- 💰 Campo para informar com quanto vai pagar
- ✔️ Validação: valor deve ser maior que o total
- 🧮 Backend calcula automaticamente o troco

### 3. Integração com Backend
- **Arquivo**: `lib/services/backend_order_service.dart`
- **API**: `https://api-pedeja.vercel.app`

#### Criação de Pedido
```dart
POST /api/orders
{
  "restaurantId": "rest123",
  "items": [...],
  "totalAmount": 35.00,
  "deliveryAddress": {...},
  "payment": {
    "method": "cash",
    "needsChange": true,
    "changeFor": 50.00  // Cliente vai pagar com R$ 50
  }
}

// Backend retorna:
{
  "orderId": "abc123",
  "payment": {
    "method": "cash",
    "changeAmount": 15.00  // Troco calculado automaticamente
  }
}
```

#### Confirmação de Pagamento (Entregador)
```dart
PATCH /api/orders/:orderId/confirm-cash-payment
{
  "receivedAmount": 50.00,  // opcional
  "changeGiven": 15.00      // opcional
}

// Atualiza status para "paid" e envia notificação push
```

### 4. Backup no Firebase
- **Arquivo**: `lib/services/order_service.dart`
- Pedidos também salvos no Firestore para backup
- Campos adicionados ao modelo:
  - `needsChange` (bool?)
  - `changeFor` (double?)
  - `receivedAmount` (double?)
  - `changeGiven` (double?)

## 🔄 Fluxo Completo

### Cliente (App)
1. 🛒 Adiciona produtos ao carrinho
2. 💳 Clica em "Finalizar Pedido"
3. 💵 Seleciona "Dinheiro na entrega"
4. ✅ Marca "Preciso de troco" (opcional)
5. 💰 Informa: "Vou pagar com R$ 50,00"
6. ✔️ Confirma pedido
7. 📱 Recebe confirmação com valor e troco

### Restaurante/Entregador (Painel Admin)
1. 📦 Recebe pedido
2. 👀 Vê informações:
   - 💰 Total: R$ 35,00
   - 💵 Forma: Dinheiro na entrega
   - 🔄 Troco: Cliente vai pagar com R$ 50,00
   - 💸 Levar troco de: R$ 15,00
3. 🚚 Entrega pedido
4. 💵 Recebe R$ 50,00
5. 💸 Dá R$ 15,00 de troco
6. ✅ Confirma pagamento no sistema

## 📱 Código de Exemplo

### Criar Pedido com Dinheiro
```dart
final backendOrderService = BackendOrderService();

// Pagamento em dinheiro COM troco
final orderId = await backendOrderService.createOrder(
  token: authToken,
  restaurantId: 'rest123',
  restaurantName: 'Restaurante ABC',
  items: orderItems,
  total: 35.00,
  deliveryAddress: {
    'street': 'Rua das Flores',
    'number': '123',
    'city': 'São Paulo',
  },
  payment: {
    'method': 'cash',
    'needsChange': true,
    'changeFor': 50.00,
  },
);
```

### Pagamento SEM Troco
```dart
payment: {
  'method': 'cash',
  'needsChange': false,
}
```

### Confirmar Pagamento (Entregador)
```dart
await backendOrderService.confirmCashPayment(
  token: authToken,
  orderId: orderId,
  receivedAmount: 50.00,
  changeGiven: 15.00,
);
```

## 🎨 Interface

### Resumo do Pedido
```
┌─────────────────────────────────┐
│ Resumo do Pedido                │
│ 3 itens          R$ 35,00       │
└─────────────────────────────────┘
```

### Opções de Pagamento
```
┌─────────────────────────────────┐
│ 💵 Dinheiro na entrega         │
│    Pague quando receber         │
│    ✓ SELECIONADO               │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ ✓ Preciso de troco             │
│                                 │
│ Vai pagar com quanto?          │
│ R$ 50.00                       │
│                                 │
│ Total: R$ 35.00                │
└─────────────────────────────────┘
```

### Confirmação
```
┌─────────────────────────────────┐
│ ✅ Pedido confirmado!           │
│                                 │
│ Pague R$ 35,00 na entrega      │
│ Troco para R$ 50,00            │
└─────────────────────────────────┘
```

## 🔧 Validações

### Frontend (Flutter)
- ✅ Método de pagamento selecionado
- ✅ Se troco: valor informado > total do pedido
- ✅ Token JWT válido
- ✅ Endereço cadastrado

### Backend (API)
- ✅ changeFor >= totalAmount
- ✅ Cálculo automático do troco
- ✅ Validação de autenticação
- ✅ Validação de dados do pedido

## 📊 Estados do Pagamento

| Status | Descrição |
|--------|-----------|
| `pending` | Aguardando pagamento |
| `paid` | Pagamento confirmado |
| `failed` | Pagamento falhou |
| `refunded` | Pagamento reembolsado |

## 🔐 Segurança

- 🔒 Autenticação JWT obrigatória
- 🔒 Apenas entregador/restaurante pode confirmar
- 🔒 Validação de valores no backend
- 🔒 Backup automático no Firebase

## 📱 Notificações Push

Quando o pagamento é confirmado:
- 📲 Cliente recebe notificação
- ✅ "Pagamento confirmado!"
- 🎉 Status atualizado automaticamente

## 🎯 Próximos Passos

1. **Painel do Entregador**
   - Interface para confirmar pagamento
   - Visualização de troco necessário
   - Histórico de pagamentos

2. **Relatórios**
   - Pagamentos em dinheiro vs online
   - Média de troco solicitado
   - Taxa de confirmação

3. **Validações Adicionais**
   - Limite de troco disponível
   - Sugestão de valores exatos
   - Alerta de falta de troco

## 🐛 Troubleshooting

### "Valor para troco deve ser maior que o total"
- Verifique se o valor informado é > total do pedido
- Exemplo: Total R$ 35,00 → Pagar com >= R$ 36,00

### "Erro ao criar pedido"
- Verifique conexão com internet
- Confirme que o token JWT está válido
- Veja logs no console para detalhes

### Backend não calcula troco
- Verifique se enviou `needsChange: true`
- Confirme que `changeFor` está presente
- Veja resposta da API no debugPrint

## 📝 Arquivos Modificados

- ✅ `lib/models/order_model.dart` - Campos de troco
- ✅ `lib/pages/checkout/payment_method_page.dart` - UI de seleção
- ✅ `lib/services/backend_order_service.dart` - Integração API
- ✅ `lib/services/order_service.dart` - Backup Firebase
- ✅ `lib/pages/checkout/checkout_page.dart` - Redirecionamento

## 🎉 Conclusão

Sistema completo de pagamento em dinheiro implementado e funcionando! 🚀

O backend calcula automaticamente o troco, o Firebase faz backup dos dados, e o cliente recebe confirmação instantânea via push notification.
