# 💳 Sistema de Pagamento com Split - Mercado Pago

## 📋 Visão Geral

Este documento explica como funciona o sistema de pagamento com split automático usando Mercado Pago no app PedeJá.

---

## 🎯 Fluxo Completo do Pagamento

```
1. Cliente adiciona produtos ao carrinho
2. Cliente clica "Finalizar Pedido"
3. App valida perfil completo
4. App cria pedido no Firebase
5. App chama API para criar pagamento com split
6. App abre URL do Mercado Pago (Checkout Pro)
7. Cliente paga no Mercado Pago
8. MP envia webhook para API
9. API atualiza status do pedido no Firebase
10. App mostra "Pagamento Aprovado" (via StreamBuilder)
```

---

## 🏗️ Arquitetura

### Componentes

1. **Flutter App** (Frontend)
   - `CheckoutPage`: Tela de finalização do pedido
   - `PaymentStatusPage`: Acompanhamento do pagamento
   - `OrderService`: CRUD de pedidos no Firebase
   - `PaymentService`: Comunicação com API de pagamento

2. **Firebase** (Database)
   - Collection `orders`: Armazena pedidos
   - Real-time updates via StreamBuilder

3. **API Backend** (`https://api-pedeja.vercel.app`)
   - `POST /api/auth/firebase-token`: Troca Firebase token por JWT
   - `POST /api/payments/mp/create-with-split`: Cria pagamento com split
   - Webhook do Mercado Pago: Recebe notificações de pagamento

4. **Mercado Pago** (Gateway de Pagamento)
   - Checkout Pro: Interface de pagamento
   - Split Payment: Divisão automática (85% restaurante, 15% plataforma)

---

## 📝 Modelos de Dados

### OrderItem
```dart
class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final List<OrderItemAddon> addons;
  
  double get totalPrice; // (price + addons) * quantity
}
```

### Order
```dart
class Order {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String userId;
  final String userEmail;
  final List<OrderItem> items;
  final double total;
  final String deliveryAddress;
  final OrderStatus status;         // pending | preparing | ready | delivered
  final PaymentStatus paymentStatus; // pending | approved | paid | rejected
  final DateTime createdAt;
  final PaymentInfo? payment;
}
```

### PaymentInfo
```dart
class PaymentInfo {
  final String? method;        // "mercadopago"
  final String? provider;      // "mercadopago"
  final String status;         // "pending" | "approved" | "rejected"
  final String? transactionId; // ID do MP
  final String? initPoint;     // URL do checkout
}
```

---

## 🔄 Fluxo Detalhado

### 1. Criar Pedido no Firebase

**Arquivo**: `lib/services/order_service.dart`

```dart
final orderId = await OrderService().createOrder(
  restaurantId: 'rest_123',
  restaurantName: 'Pizza Express',
  items: orderItems,
  total: 89.90,
  deliveryAddress: 'Rua ABC, 123...',
);

// Retorna: "abc123def456"
```

**Firestore Document Criado**:
```json
{
  "id": "abc123def456",
  "restaurantId": "rest_123",
  "restaurantName": "Pizza Express",
  "userId": "user_xyz",
  "userEmail": "user@example.com",
  "items": [...],
  "total": 89.90,
  "totalAmount": 89.90,
  "deliveryAddress": "Rua ABC, 123...",
  "status": "pending",
  "paymentStatus": "pending",
  "payment": {
    "method": null,
    "provider": null,
    "status": "pending"
  },
  "createdAt": "2025-10-26T10:30:00Z"
}
```

---

### 2. Autenticar na API

**Arquivo**: `lib/services/payment_service.dart`

```dart
// Passo 1: Obter Firebase Token
final firebaseToken = await FirebaseAuth.instance.currentUser!.getIdToken();

// Passo 2: Trocar por JWT da API
POST https://api-pedeja.vercel.app/api/auth/firebase-token
Headers:
  Content-Type: application/json
Body:
  {
    "idToken": "eyJhbGciOiJSUzI1NiIsImtpZCI6..."
  }

Response:
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "uid": "user_xyz",
      "email": "user@example.com"
    }
  }
```

---

### 3. Criar Pagamento com Split

**Request**:
```dart
POST https://api-pedeja.vercel.app/api/payments/mp/create-with-split
Headers:
  Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
  Content-Type: application/json
Body:
  {
    "orderId": "abc123def456",
    "paymentMethod": "mercadopago",
    "installments": 1
  }
```

**Response (Sucesso)**:
```json
{
  "success": true,
  "payment": {
    "id": "mp_payment_123",
    "initPoint": "https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=12345-abcdef",
    "status": "pending",
    "transactionAmount": 89.90,
    "platformFee": 13.49,
    "restaurantAmount": 76.41,
    "splits": [
      {
        "accountId": "restaurant_mp_account",
        "amount": 76.41,
        "percentage": 85
      },
      {
        "accountId": "platform_mp_account",
        "amount": 13.49,
        "percentage": 15
      }
    ]
  }
}
```

**Response (Erro - Restaurante sem MP)**:
```json
{
  "success": false,
  "error": "Restaurante não tem Mercado Pago configurado"
}
```

---

### 4. Abrir Checkout do Mercado Pago

**Arquivo**: `lib/pages/checkout/checkout_page.dart`

```dart
final checkoutUrl = paymentData['payment']['initPoint'];

final uri = Uri.parse(checkoutUrl);

if (await canLaunchUrl(uri)) {
  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication, // Abre no navegador
  );
  
  // Navegar para tela de status
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => PaymentStatusPage(orderId: orderId),
    ),
  );
}
```

**O que acontece**:
1. App abre navegador externo
2. Cliente vê checkout do Mercado Pago
3. Cliente escolhe método de pagamento (PIX, cartão, etc)
4. Cliente confirma pagamento
5. Mercado Pago processa
6. MP envia webhook para API

---

### 5. Webhook Atualiza Pedido

**API recebe webhook do MP**:
```
POST https://api-pedeja.vercel.app/api/webhooks/mercadopago
Body (example):
  {
    "action": "payment.updated",
    "data": {
      "id": "mp_payment_123"
    }
  }
```

**API busca detalhes do pagamento**:
```
GET https://api.mercadopago.com/v1/payments/mp_payment_123
Authorization: Bearer ACCESS_TOKEN

Response:
  {
    "id": "mp_payment_123",
    "status": "approved",
    "status_detail": "accredited",
    "transaction_amount": 89.90,
    ...
  }
```

**API atualiza Firestore**:
```dart
FirebaseFirestore.instance
  .collection('orders')
  .doc('abc123def456')
  .update({
    'paymentStatus': 'approved',
    'payment.status': 'approved',
    'payment.transactionId': 'mp_payment_123',
  });
```

---

### 6. App Detecta Atualização

**Arquivo**: `lib/pages/checkout/payment_status_page.dart`

```dart
StreamBuilder<Order?>(
  stream: OrderService().watchOrder(orderId),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    
    final order = snapshot.data!;
    final paymentStatus = order.paymentStatus;
    
    if (paymentStatus == PaymentStatus.approved) {
      return _buildSuccess(); // ✅ Pagamento Aprovado!
    } else {
      return _buildPending(); // ⏳ Aguardando...
    }
  },
)
```

**Fluxo Visual**:
```
PaymentStatusPage
├─ StreamBuilder escuta mudanças no Firestore
├─ Estado inicial: paymentStatus = "pending"
│  └─ Mostra: CircularProgressIndicator + "Aguardando pagamento..."
│
├─ Webhook atualiza: paymentStatus = "approved"
│  └─ StreamBuilder recebe evento
│  └─ Mostra: ✅ Icon + "Pagamento Aprovado!"
│  └─ Botão: "Voltar ao Início"
```

---

## 🔒 Validações e Segurança

### 1. Validação de Perfil Completo

**Antes de criar pedido**:
```dart
if (!userState.isProfileComplete) {
  // Mostra dialog com campos faltantes
  // Navega para CompleteProfilePage
  return;
}
```

### 2. Validação de Carrinho

```dart
if (cartState.items.isEmpty) {
  throw Exception('Carrinho vazio');
}
```

### 3. Validação de Endereço

```dart
final address = userData['address'];
if (address == null || address['street'] == null) {
  throw Exception('Endereço incompleto');
}
```

### 4. Validação de Restaurante com MP

```dart
final hasConfig = await PaymentService().isRestaurantConfigured(restaurantId);

if (!hasConfig) {
  throw Exception('Restaurante não aceita pagamentos online');
}
```

### 5. Autenticação

```dart
// Usuário deve estar logado
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  throw Exception('Usuário não autenticado');
}

// Token válido por 1 hora
final token = await user.getIdToken();
```

---

## 🧪 Testando o Fluxo

### Ambiente de Desenvolvimento

1. **Criar conta de teste no Mercado Pago**:
   - https://www.mercadopago.com.br/developers/panel/test-users

2. **Configurar credenciais de teste**:
   - Access Token de teste
   - Public Key de teste

3. **Cartões de teste**:
   ```
   Aprovado: 5031 4332 1540 6351
   Recusado: 5031 7557 3453 0604
   CVV: 123
   Validade: 11/25
   ```

### Fluxo de Teste

```bash
# 1. Rodar app
flutter run -d chrome

# 2. Login/Cadastro
Email: teste@pedeja.com
Senha: teste123

# 3. Completar perfil
Nome: João Silva
Telefone: (11) 98765-4321
CEP: 01310-100
Rua: Av. Paulista
Número: 1000
Bairro: Bela Vista
Cidade: São Paulo
Estado: SP

# 4. Adicionar produtos ao carrinho
- Selecionar restaurante
- Adicionar 2-3 produtos
- Adicionar adicionais (opcional)

# 5. Finalizar pedido
- Abrir carrinho
- Clicar "Finalizar Pedido"
- Verificar resumo
- Clicar "Pagar com Mercado Pago"

# 6. Checkout MP
- Navegador abre automaticamente
- Escolher "Cartão de crédito"
- Usar cartão de teste
- Confirmar pagamento

# 7. Verificar status
- App volta para PaymentStatusPage
- Aguardar webhook (5-30 segundos)
- Ver "Pagamento Aprovado!" ✅
```

---

## 📊 Monitoramento e Logs

### Logs do App

```dart
debugPrint('📦 Criando pedido...');
debugPrint('✅ Pedido criado: $orderId');
debugPrint('💳 Criando pagamento com split...');
debugPrint('🌐 Abrindo checkout: $checkoutUrl');
debugPrint('📊 Status do pagamento: ${paymentStatus.value}');
```

### Logs da API

```bash
# Ver logs da Vercel
vercel logs https://api-pedeja.vercel.app --follow

# Ver webhooks recebidos
vercel logs --filter="POST /api/webhooks/mercadopago"
```

### Monitorar Firestore

```javascript
// No Firebase Console → Firestore → orders
// Filtrar por userId
// Ordenar por createdAt desc
// Ver documento em tempo real
```

---

## ⚠️ Tratamento de Erros

### Erros Comuns

#### 1. "Usuário não autenticado"
```dart
catch (e) {
  if (e.toString().contains('não autenticado')) {
    // Redirecionar para login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }
}
```

#### 2. "Restaurante não tem Mercado Pago configurado"
```dart
catch (e) {
  if (e.toString().contains('Mercado Pago configurado')) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pagamento Indisponível'),
        content: Text(
          'Este restaurante ainda não aceita pagamentos online. '
          'Tente outro restaurante ou pague na entrega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

#### 3. "Erro ao criar pagamento"
```dart
setState(() {
  _errorMessage = 'Erro ao processar pagamento. Tente novamente.';
});

ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(_errorMessage),
    backgroundColor: Colors.red,
    action: SnackBarAction(
      label: 'Tentar Novamente',
      onPressed: _finalizarPagamento,
    ),
  ),
);
```

#### 4. "Não foi possível abrir checkout"
```dart
if (!await canLaunchUrl(uri)) {
  // Copiar URL para clipboard
  await Clipboard.setData(ClipboardData(text: checkoutUrl));
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('URL copiada! Cole no navegador para pagar.'),
    ),
  );
}
```

---

## 🚀 Melhorias Futuras

### 1. Retry de Pagamento
```dart
// Se pagamento falhar, permitir tentar novamente
ElevatedButton(
  onPressed: () => _retryPayment(orderId),
  child: Text('Tentar Novamente'),
)
```

### 2. Cancelar Pedido
```dart
// Permitir cancelar pedido antes de pagar
await OrderService().cancelOrder(orderId);
```

### 3. Histórico de Pedidos
```dart
// Tela para ver todos os pedidos do usuário
final orders = await OrderService().getUserOrders();
```

### 4. Notificações Push
```dart
// Firebase Cloud Messaging
// Enviar notificação quando pagamento for aprovado
```

### 5. PIX como Método Principal
```dart
// Gerar QR Code PIX diretamente no app
// Usar plugin qr_flutter
```

### 6. Suporte a Múltiplos Restaurantes
```dart
// Validar se todos os itens são do mesmo restaurante
// Ou criar pedidos separados
```

---

## 📚 Referências

- [Mercado Pago Checkout Pro](https://www.mercadopago.com.br/developers/pt/docs/checkout-pro/landing)
- [Split Payments](https://www.mercadopago.com.br/developers/pt/docs/split-payments/landing)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Cloud Firestore](https://firebase.google.com/docs/firestore)
- [URL Launcher Plugin](https://pub.dev/packages/url_launcher)

---

**Última atualização**: 26 de outubro de 2025
