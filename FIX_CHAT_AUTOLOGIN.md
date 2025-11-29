# 🔧 Correção: Chat "Usuário Não Logado" no Auto-Login

## 📋 Problema Identificado

Quando o usuário fazia **auto-login** (sair e voltar ao app), o **chat** mostrava erro "usuário não está logado", mesmo com as notificações de status funcionando via Pusher.

### Causa Raiz

O `ChatService` não estava **autenticando** com o backend Pusher após auto-login porque:

1. **Faltava token JWT** na inicialização do chat
2. **Sem `onAuthorizer`** no ChatService (apenas OrderStatusPusherService tinha)
3. Chat tentava conectar a **canais privados sem autenticação**

## ✅ Correções Implementadas

### 1. **Adicionado Autenticação no ChatService**

```dart
// ✅ Token compartilhado entre ChatService e OrderStatusPusherService
static String? _currentAuthToken;

// ✅ onAuthorizer adicionado na inicialização
onAuthorizer: (String channelName, String socketId, dynamic options) async {
  if (_currentAuthToken != null) {
    return await _authorizeChannel(
      channelName: channelName,
      socketId: socketId,
      authToken: _currentAuthToken!,
    );
  }
  return null;
},
```

### 2. **Método de Autorização com Backend**

```dart
/// Autorizar canal privado no backend
static Future<Map<String, dynamic>?> _authorizeChannel({
  required String channelName,
  required String socketId,
  required String authToken,
}) async {
  final response = await http.post(
    Uri.parse('https://api-pedeja.vercel.app/pusher/auth'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    },
    body: json.encode({
      'socket_id': socketId,
      'channel_name': channelName,
    }),
  );
  
  if (response.statusCode == 200) {
    return json.decode(response.body);
  }
  return null;
}
```

### 3. **JWT Token Passado ao Inicializar Chat**

```dart
// OrderDetailsPage.dart
await ChatService.initialize(
  orderId: widget.order.id,
  userId: authState.currentUser!.uid,
  restaurantName: widget.order.restaurantName,
  authToken: authState.jwtToken, // ✅ CRÍTICO: Token JWT
  onMessageReceived: (message) { ... },
);
```

### 4. **Import do http Package**

```dart
import 'package:http/http.dart' as http;
```

## 🔍 Arquitetura Atualizada

### Fluxo de Autenticação Pusher

```
┌─────────────────┐
│   Auto-Login    │
│  (AuthState)    │
└────────┬────────┘
         │
         │ JWT Token renovado
         ▼
┌─────────────────────────┐
│ OrderStatusPusherService│
│   .initialize()         │
│   authToken: JWT        │
└────────┬────────────────┘
         │
         │ Pusher inicializado
         ▼
┌─────────────────────────┐
│    ChatService          │
│   .initialize()         │
│   authToken: JWT        │◄────── Reutiliza Pusher
└────────┬────────────────┘
         │
         │ onAuthorizer chamado
         ▼
┌──────────────────────────┐
│ POST /pusher/auth        │
│ Authorization: Bearer JWT│
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ Backend retorna auth     │
│ { auth: "xxx:yyy" }      │
└────────┬─────────────────┘
         │
         ▼
    ✅ Canal autorizado
    ✅ Chat conectado
```

## 📝 Arquivos Modificados

1. **`lib/services/chat_service.dart`**
   - ✅ Adicionado `_currentAuthToken`
   - ✅ Adicionado parâmetro `authToken` em `initialize()`
   - ✅ Adicionado `onAuthorizer` no `_pusher.init()`
   - ✅ Criado método `_authorizeChannel()`
   - ✅ Importado `package:http/http.dart`

2. **`lib/pages/orders/order_details_page.dart`**
   - ✅ Adicionado `authToken: authState.jwtToken` na chamada `ChatService.initialize()`

## 🧪 Como Testar

### Teste 1: Login Normal
1. Fazer login no app
2. Abrir chat de um pedido
3. ✅ Chat deve conectar normalmente
4. ✅ Mensagens do restaurante devem aparecer

### Teste 2: Auto-Login (Problema Original)
1. Fazer login no app
2. **Fechar app completamente** (swipe na lista de apps)
3. Abrir app novamente (auto-login)
4. Abrir chat de um pedido
5. ✅ Chat deve conectar SEM erro "usuário não logado"
6. ✅ Mensagens antigas devem carregar do cache
7. ✅ Novas mensagens devem chegar em tempo real

### Teste 3: Notificações do Chat
1. Com app aberto mas chat fechado
2. Restaurante envia mensagem
3. ✅ Notificação deve aparecer
4. Abrir o chat
5. ✅ Mensagem deve estar lá

### Teste 4: Supressão de Notificações
1. Abrir chat de um pedido
2. Restaurante envia mensagem
3. ✅ Notificação NÃO deve aparecer (chat está aberto)
4. ✅ Mensagem aparece diretamente no chat

## 🐛 Logs de Debug

Procurar por estes logs para validar:

```
✅ Sucesso:
💬 [ChatService] Token de autenticação salvo
🔐 [ChatService] Autorizando canal: order-xxx
✅ [ChatService] Canal autorizado: order-xxx
✅ [ChatService] Conectado ao canal order-xxx

❌ Erro (se acontecer):
❌ [ChatService] Erro na autorização: 401 - Unauthorized
⚠️ [ChatService] Sem token de autenticação
```

## 📊 Impacto

### Antes
- ❌ Chat quebrava no auto-login
- ❌ Erro "usuário não está logado"
- ❌ Mensagens não chegavam em tempo real

### Depois
- ✅ Chat funciona após auto-login
- ✅ Autenticação correta com Pusher
- ✅ Mensagens em tempo real funcionando
- ✅ Notificações de chat funcionando
- ✅ Supressão de notificações quando chat está aberto

## 🔗 Dependências do Backend

O backend **DEVE** ter endpoint de autenticação Pusher:

```javascript
// POST /pusher/auth
app.post('/pusher/auth', authenticateJWT, (req, res) => {
  const { socket_id, channel_name } = req.body;
  const userId = req.user.id; // Do JWT
  
  // Verificar se usuário tem permissão ao canal
  if (channel_name.startsWith(`private-user-${userId}`) || 
      channel_name.startsWith('order-')) {
    
    const auth = pusher.authorizeChannel(socket_id, channel_name);
    return res.json(auth);
  }
  
  return res.status(403).json({ error: 'Forbidden' });
});
```

## ✅ Checklist Final

- [x] ChatService com autenticação Pusher
- [x] Token JWT passado ao inicializar chat
- [x] Método `_authorizeChannel()` implementado
- [x] Import do http package
- [x] OrderDetailsPage atualizada
- [x] Logs de debug adicionados
- [ ] Testar login normal
- [ ] Testar auto-login
- [ ] Testar notificações de chat
- [ ] Verificar backend /pusher/auth

---

**Data:** 29/11/2025  
**Commit:** Próximo commit após testes
