# 💬 Chat em Tempo Real - Implementação Detalhada (Pusher)

## � CORREÇÃO CRÍTICA - v1.0.42 (03/02/2026)

### ❌ **Problema Identificado**
O histórico de mensagens **NÃO** carregava ao abrir conversas existentes:
- ✅ Mensagens em tempo real (Pusher) funcionavam
- ❌ Histórico do Firebase **NÃO** aparecia
- Usuários viam apenas mensagens enviadas enquanto o chat estava aberto

### 🔍 **Root Cause**
A função `_loadCachedMessages()` existia em `order_details_page.dart` mas **NUNCA ERA CHAMADA** no `initState()`.

### ✅ **Solução Implementada**

**1. Chamada no initState():**
```dart
@override
void initState() {
  super.initState();
  _loadCachedMessages(); // ← ADICIONADO
  _listenToOrderChanges();
  _setupFirebaseMessagesListener();
  _initializeChatService();
}
```

**2. Triple-Fallback System:**
```dart
Future<void> _loadCachedMessages() async {
  // 1️⃣ CACHE (SharedPreferences + Memory)
  final cachedMessages = _chatService.getCachedMessages(widget.order.id);
  
  // 2️⃣ BACKEND API (/api/orders/:orderId/messages?limit=100)
  final backendMessages = await _chatService.loadMessagesFromBackend(
    widget.order.id, 
    currentUserId
  );
  
  // 3️⃣ FIREBASE DIRETO (fallback se API falhar)
  if (backendMessages.isEmpty && token.isNotEmpty) {
    final firebaseMessages = await _loadDirectFromFirebase(currentUserId);
    allMessages.addAll(firebaseMessages);
  }
}
```

**3. Logs Detalhados:**
- 🔍 Mostra token, userId e contadores em cada etapa
- 💾 Exibe mensagens do cache local
- 🔄 Logs de requisição ao backend
- 🌐 Preview de mensagens retornadas
- 🔥 Fallback para Firebase direto
- ✅ Total final carregado na UI

### 📊 **Resultado**
Pedido `cF4QrXeCXW0Db0n5adAm` com 7 mensagens:
```
[Firebase] Recebeu 7 mensagens (snapshot changes: 7)
✅ [BackendOrderService] 7 mensagens carregadas do Firebase
🌐 [OrderDetailsPage] Backend retornou 7 mensagens
✅ [OrderDetailsPage] 7 mensagens TOTAL carregadas na UI
```

**Arquivos Modificados:**
- `lib/pages/orders/order_details_page.dart` - Fix principal + logs
- `lib/services/chat_service.dart` - Enhanced debugging
- `lib/services/backend_order_service.dart` - limit=100 + parsing robusto

---

## �📋 Visão Geral

O chat em tempo real usa **Pusher** (WebSocket) para comunicação instantânea entre restaurante e cliente. A implementação atual no painel do lojista (Replit) está funcionando perfeitamente e serve como referência para o app Flutter.

---

## 🏗️ Arquitetura Completa

```
┌──────────────┐      ┌─────────────┐      ┌──────────────┐
│   Cliente    │      │  Restaurante│      │  API Vercel  │
│  (Flutter)   │◄────►│   (Replit)  │◄────►│  + Firebase  │
└──────────────┘      └─────────────┘      └──────────────┘
       │                     │                      │
       │                     │                      │
       └─────────────────────┴──────────────────────┘
                            │
                     ┌──────▼──────┐
                     │   Pusher    │
                     │  (WebSocket)│
                     └─────────────┘
```

**Fluxo:**
1. ✅ Mensagem enviada via API (POST)
2. ✅ API salva no Firebase
3. ✅ API dispara evento Pusher
4. ✅ Todos conectados ao canal recebem em tempo real

---

## 🔧 1. Configuração do Pusher (Cliente)

### **A. Credenciais Pusher**
```javascript
// Mesmas credenciais para Replit e Flutter
const PUSHER_CONFIG = {
  key: '45b7798e358505a8343e',
  cluster: 'us2',
  encrypted: true
};
```

### **B. Inicialização (Replit - PusherContext.tsx)**

**Arquivo:** `client/src/contexts/PusherContext.tsx`

```typescript
import { createContext, useContext, useEffect, useRef, useState } from 'react';

// ✅ Context para gerenciar UMA ÚNICA instância do Pusher
export function PusherProvider({ children }) {
  const pusherRef = useRef(null);
  const channelsRef = useRef(new Map());
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    // ✅ Inicializar Pusher UMA VEZ para todo o app
    if (!pusherRef.current) {
      console.log('🔌 Initializing single Pusher instance...');
      
      pusherRef.current = new Pusher('45b7798e358505a8343e', {
        cluster: 'us2',
        encrypted: true
      });

      // ✅ Event handlers de conexão
      pusherRef.current.connection.bind('connected', () => {
        console.log('✅ Pusher Connected!');
        setIsConnected(true);
      });

      pusherRef.current.connection.bind('disconnected', () => {
        console.log('⚠️ Pusher Disconnected');
        setIsConnected(false);
      });

      pusherRef.current.connection.bind('error', (err) => {
        console.error('❌ Pusher Error:', err);
        setIsConnected(false);
      });
    }

    // ✅ Cleanup ao desmontar
    return () => {
      if (pusherRef.current) {
        pusherRef.current.disconnect();
        pusherRef.current = null;
        channelsRef.current.clear();
      }
    };
  }, []);

  // ✅ Função para se inscrever em um canal
  const subscribe = (channelName) => {
    if (!pusherRef.current) return null;

    // Verificar se já está inscrito
    if (channelsRef.current.has(channelName)) {
      return channelsRef.current.get(channelName);
    }

    // Inscrever em novo canal
    console.log(`📡 Subscribing to channel: ${channelName}`);
    const channel = pusherRef.current.subscribe(channelName);
    channelsRef.current.set(channelName, channel);
    
    return channel;
  };

  // ✅ Função para cancelar inscrição
  const unsubscribe = (channelName) => {
    if (!pusherRef.current) return;

    if (channelsRef.current.has(channelName)) {
      console.log(`🔌 Unsubscribing from channel: ${channelName}`);
      pusherRef.current.unsubscribe(channelName);
      channelsRef.current.delete(channelName);
    }
  };

  return (
    <PusherContext.Provider value={{ pusher: pusherRef.current, subscribe, unsubscribe, isConnected }}>
      {children}
    </PusherContext.Provider>
  );
}

// ✅ Hook para usar o Pusher
export function usePusher() {
  const context = useContext(PusherContext);
  if (!context) {
    throw new Error('usePusher must be used within PusherProvider');
  }
  return context;
}
```

---

## 📱 2. Implementação no Flutter (Equivalente)

### **A. Dependência**
```yaml
# pubspec.yaml
dependencies:
  pusher_channels_flutter: ^2.2.1  # Versão mais recente
```

### **B. Inicialização (Singleton)**

```dart
// lib/services/pusher_service.dart
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherService {
  static final PusherService _instance = PusherService._internal();
  factory PusherService() => _instance;
  PusherService._internal();

  PusherChannelsFlutter? _pusher;
  final Map<String, Channel> _channels = {};
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // ✅ Inicializar Pusher (chamar no main.dart)
  Future<void> initialize() async {
    if (_pusher != null) return;

    _pusher = PusherChannelsFlutter.getInstance();
    
    try {
      await _pusher!.init(
        apiKey: '45b7798e358505a8343e',
        cluster: 'us2',
        onConnectionStateChange: _onConnectionStateChange,
        onError: _onError,
      );
      
      await _pusher!.connect();
      print('🔌 Pusher initialized and connected');
    } catch (e) {
      print('❌ Pusher initialization error: $e');
    }
  }

  // ✅ Event Handlers
  void _onConnectionStateChange(dynamic currentState, dynamic previousState) {
    print('📡 Pusher connection state: $currentState');
    _isConnected = currentState == 'CONNECTED';
  }

  void _onError(String message, int? code, dynamic e) {
    print('❌ Pusher error: $message (code: $code)');
  }

  // ✅ Inscrever em canal
  Future<Channel?> subscribe(String channelName) async {
    if (_pusher == null) {
      print('❌ Pusher not initialized');
      return null;
    }

    // Verificar se já está inscrito
    if (_channels.containsKey(channelName)) {
      print('✅ Already subscribed to $channelName');
      return _channels[channelName];
    }

    try {
      print('📡 Subscribing to channel: $channelName');
      final channel = await _pusher!.subscribe(channelName: channelName);
      _channels[channelName] = channel;
      return channel;
    } catch (e) {
      print('❌ Failed to subscribe to $channelName: $e');
      return null;
    }
  }

  // ✅ Cancelar inscrição
  Future<void> unsubscribe(String channelName) async {
    if (_pusher == null) return;

    if (_channels.containsKey(channelName)) {
      print('🔌 Unsubscribing from channel: $channelName');
      await _pusher!.unsubscribe(channelName: channelName);
      _channels.remove(channelName);
    }
  }

  // ✅ Desconectar (quando app fecha)
  Future<void> disconnect() async {
    if (_pusher != null) {
      await _pusher!.disconnect();
      _channels.clear();
      print('🔌 Pusher disconnected');
    }
  }
}
```

### **C. Uso no main.dart**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Inicializar Pusher ANTES do runApp
  await PusherService().initialize();
  
  runApp(MyApp());
}
```

---

## 💬 3. Componente de Chat (OrderChat)

### **A. Implementação Replit (OrderChat.tsx)**

**Arquivo:** `client/src/components/OrderChat.tsx`

**Principais funcionalidades:**

```typescript
// ✅ 1. Inscrever no canal ao montar componente
useEffect(() => {
  const channelName = `order-${orderId}`;
  const channel = subscribe(channelName);
  
  if (!channel) return;

  // ✅ 2. Escutar evento 'new-message'
  const handleNewMessage = (data) => {
    console.log('💬 Nova mensagem via Pusher:', data);
    
    const normalizedMessage = {
      user: data.senderName || 'Anônimo',
      message: data.message,
      timestamp: data.timestamp,
      isRestaurant: data.isRestaurant || false
    };

    // ✅ 3. Atualizar estado (evitar duplicatas)
    setMessages(prev => {
      const isDuplicate = prev.some(msg => 
        msg.message === normalizedMessage.message && 
        msg.isRestaurant === normalizedMessage.isRestaurant &&
        Math.abs(new Date(msg.timestamp) - new Date(normalizedMessage.timestamp)) < 2000
      );
      
      if (isDuplicate) return prev;
      return [...prev, normalizedMessage];
    });

    // ✅ 4. Notificação (se mensagem do cliente)
    if (!normalizedMessage.isRestaurant) {
      showNotification('Nova mensagem', normalizedMessage.message);
      playSound('message');
    }

    // ✅ 5. Scroll automático
    scrollToBottom();
  };

  channel.bind('new-message', handleNewMessage);

  // ✅ 6. Cleanup ao desmontar
  return () => {
    channel.unbind('new-message', handleNewMessage);
    unsubscribe(channelName);
  };
}, [orderId]);
```

### **B. Implementação Flutter (OrderChatScreen.dart)**

```dart
// lib/screens/order_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../services/pusher_service.dart';
import '../services/api_service.dart';

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String customerName;

  const OrderChatScreen({
    required this.orderId,
    required this.customerName,
  });

  @override
  _OrderChatScreenState createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PusherService _pusher = PusherService();
  Channel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeToChannel();
    _loadMessages();
  }

  // ✅ 1. Inscrever no canal
  Future<void> _subscribeToChannel() async {
    final channelName = 'order-${widget.orderId}';
    _channel = await _pusher.subscribe(channelName);
    
    if (_channel == null) {
      print('❌ Failed to subscribe to $channelName');
      return;
    }

    // ✅ 2. Escutar evento 'new-message'
    _channel!.bind('new-message', (event) {
      print('💬 Nova mensagem via Pusher: ${event?.data}');
      
      if (event?.data != null) {
        _handleNewMessage(event!.data);
      }
    });

    print('📡 Subscribed to channel: $channelName');
  }

  // ✅ 3. Processar mensagem recebida
  void _handleNewMessage(dynamic data) {
    final message = ChatMessage(
      user: data['senderName'] ?? 'Anônimo',
      message: data['message'],
      timestamp: DateTime.parse(data['timestamp']),
      isRestaurant: data['isRestaurant'] ?? false,
    );

    setState(() {
      // Evitar duplicatas
      final isDuplicate = _messages.any((msg) =>
          msg.message == message.message &&
          msg.isRestaurant == message.isRestaurant &&
          msg.timestamp.difference(message.timestamp).abs() < Duration(seconds: 2));

      if (!isDuplicate) {
        _messages.add(message);
        _scrollToBottom();
      }
    });

    // ✅ 4. Notificação local (se mensagem do restaurante)
    if (message.isRestaurant) {
      _showLocalNotification(message);
    }
  }

  // ✅ 5. Carregar mensagens ao abrir chat
  Future<void> _loadMessages() async {
    try {
      final response = await ApiService().get(
        '/orders/${widget.orderId}/messages?limit=100',
      );

      if (response['success'] && response['messages'] != null) {
        setState(() {
          _messages.clear();
          _messages.addAll(
            (response['messages'] as List).map((msg) => ChatMessage(
              user: msg['senderName'] ?? 'Anônimo',
              message: msg['message'],
              timestamp: DateTime.parse(msg['timestamp']),
              isRestaurant: msg['isRestaurant'] ?? false,
            )),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('❌ Erro ao carregar mensagens: $e');
    }
  }

  // ✅ 6. Enviar mensagem
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final tempMessage = ChatMessage(
      user: 'Você',
      message: text,
      timestamp: DateTime.now(),
      isRestaurant: false, // Cliente
    );

    setState(() {
      _messages.add(tempMessage);
      _controller.clear();
    });
    _scrollToBottom();

    try {
      await ApiService().post(
        '/orders/${widget.orderId}/messages',
        {
          'senderId': 'user-id-here',
          'senderName': widget.customerName,
          'message': text,
          'isRestaurant': false,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      print('✅ Mensagem enviada');
    } catch (e) {
      print('❌ Erro ao enviar mensagem: $e');
      // Remover mensagem se falhou
      setState(() {
        _messages.remove(tempMessage);
        _controller.text = text; // Restaurar texto
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showLocalNotification(ChatMessage message) {
    // Implementar notificação local (opcional)
  }

  @override
  void dispose() {
    _pusher.unsubscribe('order-${widget.orderId}');
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${widget.customerName}'),
      ),
      body: Column(
        children: [
          // ✅ Lista de mensagens
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          // ✅ Campo de entrada
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isRestaurant == false; // Cliente
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.user,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              message.message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String user;
  final String message;
  final DateTime timestamp;
  final bool isRestaurant;

  ChatMessage({
    required this.user,
    required this.message,
    required this.timestamp,
    required this.isRestaurant,
  });
}
```

---

## 🌐 4. Endpoints da API

### **A. Enviar Mensagem**

**Endpoint:** `POST /api/orders/:orderId/messages`

**Arquivo:** `server/routes.ts` (linha 1041)

**Código:**
```typescript
app.post('/api/orders/:orderId/messages', async (req, res) => {
  const { orderId } = req.params;
  const { senderId, senderName, message, isRestaurant, timestamp } = req.body;

  // ✅ 1. Validação
  if (!senderName || !message) {
    return res.status(400).json({ error: 'senderName e message obrigatórios' });
  }

  const newMessage = {
    senderId: senderId || null,
    senderName: senderName,
    message: message,
    timestamp: timestamp || new Date().toISOString(),
    isRestaurant: isRestaurant || false
  };

  // ✅ 2. Salvar no Firebase
  const messagesRef = db.collection('orders').doc(orderId).collection('messages');
  const docRef = await messagesRef.add(newMessage);
  console.log(`💬 Mensagem salva: ${docRef.id}`);

  // ✅ 3. Disparar Pusher (TEMPO REAL)
  const pusherPayload = { ...newMessage, id: docRef.id };
  await pusher.trigger(`order-${orderId}`, 'new-message', pusherPayload);
  console.log(`📡 Pusher enviou mensagem`);

  // ✅ 4. Resposta
  res.status(201).json({
    success: true,
    data: pusherPayload
  });
});
```

**Payload de Exemplo:**
```json
{
  "senderId": "user_123",
  "senderName": "João Silva",
  "message": "Olá, pode trocar o refrigerante por suco?",
  "isRestaurant": false,
  "timestamp": "2026-02-03T10:30:00.000Z"
}
```

### **B. Buscar Mensagens**

**Endpoint:** `GET /api/orders/:orderId/messages?limit=100`

**Resposta:**
```json
{
  "success": true,
  "count": 5,
  "messages": [
    {
      "id": "msg_abc123",
      "senderId": "user_123",
      "senderName": "João Silva",
      "message": "Pode trocar?",
      "timestamp": "2026-02-03T10:30:00.000Z",
      "isRestaurant": false
    },
    {
      "id": "msg_def456",
      "senderId": "restaurant",
      "senderName": "Restaurante",
      "message": "Claro, sem problemas!",
      "timestamp": "2026-02-03T10:31:00.000Z",
      "isRestaurant": true
    }
  ]
}
```

---

## 📊 5. Estrutura Firestore

```
orders (collection)
  └─ {orderId} (document)
       ├─ status: "preparing"
       ├─ userId: "user_123"
       ├─ items: [...]
       └─ messages (subcollection)
            ├─ {messageId_1} (document)
            │    ├─ senderId: "user_123"
            │    ├─ senderName: "João Silva"
            │    ├─ message: "Pode trocar?"
            │    ├─ timestamp: "2026-02-03T10:30:00.000Z"
            │    └─ isRestaurant: false
            └─ {messageId_2} (document)
                 ├─ senderId: "restaurant"
                 ├─ senderName: "Restaurante"
                 ├─ message: "Claro!"
                 ├─ timestamp: "2026-02-03T10:31:00.000Z"
                 └─ isRestaurant: true
```

---

## ✅ 6. Checklist de Implementação Flutter

### **Backend (Já pronto)**
- [x] Endpoint POST `/api/orders/:orderId/messages`
- [x] Endpoint GET `/api/orders/:orderId/messages`
- [x] Integração com Pusher
- [x] Salvamento no Firestore

### **Flutter (A fazer)**
- [ ] Adicionar dependência `pusher_channels_flutter: ^2.2.1`
- [ ] Criar `PusherService` (singleton)
- [ ] Inicializar Pusher no `main.dart`
- [ ] Criar tela `OrderChatScreen`
- [ ] Implementar lógica de inscrição no canal
- [ ] Implementar escuta do evento `new-message`
- [ ] Implementar envio de mensagens via API
- [ ] Implementar carregamento de mensagens ao abrir chat
- [ ] Adicionar notificações locais (opcional)
- [ ] Testar tempo real

---

## 🎯 7. Pontos Importantes

### **✅ O que FUNCIONA no Replit (e deve ser replicado)**

1. **Instância única do Pusher**
   - PusherContext gerencia UMA ÚNICA conexão
   - Canais são reutilizados se já estiverem inscritos

2. **Inscrição automática ao montar componente**
   - `useEffect(() => subscribe(channelName), [orderId])`
   - Cleanup ao desmontar

3. **Evitar duplicatas**
   - Verificar timestamp com tolerância de 2 segundos
   - Mensagens têm IDs únicos

4. **Mensagens otimistas (UI instantânea)**
   - Adicionar à UI antes de confirmar envio
   - Remover se API falhar

5. **Notificações apenas de mensagens do outro lado**
   - Restaurante notifica quando CLIENTE envia
   - Cliente notifica quando RESTAURANTE envia

6. **Scroll automático**
   - Sempre ao receber nova mensagem
   - Delay de 100ms para garantir renderização

### **❌ O que NÃO fazer**

1. ❌ Criar múltiplas instâncias do Pusher
2. ❌ Inscrever no mesmo canal várias vezes
3. ❌ Escutar onSnapshot do Firebase (redundante com Pusher)
4. ❌ Enviar mensagens diretamente ao Firebase (sempre via API)
5. ❌ Notificar quando você mesmo envia mensagem

---

## 🔍 8. Debugging

### **Logs Esperados (Replit)**
```
🔌 Initializing single Pusher instance...
✅ Pusher Connected!
📡 Subscribing to channel: order-abc123
👂 Escutando evento 'new-message' no canal: order-abc123
💬 Nova mensagem via Pusher: {...}
✅ Mensagens atualizadas: 5 total
```

### **Logs Esperados (Flutter)**
```
🔌 Pusher initialized and connected
📡 Pusher connection state: CONNECTED
📡 Subscribing to channel: order-abc123
💬 Nova mensagem via Pusher: {...}
✅ Mensagem enviada
```

---

## 📝 9. Exemplo Completo de Fluxo

```
1. Cliente abre app Flutter → Conecta ao Pusher
2. Cliente abre pedido #abc123 → Inscreve no canal order-abc123
3. Cliente envia "Pode trocar?" → 
   ├─ Flutter adiciona mensagem à UI (otimista)
   ├─ Flutter chama POST /api/orders/abc123/messages
   ├─ API salva no Firebase
   ├─ API dispara Pusher → order-abc123 / new-message
   └─ Restaurante recebe em tempo real (Pusher)
4. Restaurante vê notificação → Abre chat
5. Restaurante responde "Claro!" →
   ├─ Replit adiciona mensagem à UI (otimista)
   ├─ Replit chama POST /api/orders/abc123/messages
   ├─ API salva no Firebase
   ├─ API dispara Pusher → order-abc123 / new-message
   └─ Cliente recebe em tempo real (Pusher)
6. Pedido finalizado → Ambos desconectam do canal
```

---

## 🚀 10. Próximos Passos para Flutter

1. **Implementar PusherService** (copiar lógica do PusherContext)
2. **Criar OrderChatScreen** (copiar lógica do OrderChat.tsx)
3. **Testar conexão Pusher** (verificar logs)
4. **Testar envio/recebimento** (duas instâncias do app)
5. **Adicionar notificações** (flutter_local_notifications)
6. **Polir UI** (seguir design do Replit)

---

**Documento criado em:** 03/02/2026  
**Baseado em:** Implementação funcional do Replit (PedejaParceiros)  
**Status:** ✅ Pronto para implementação no Flutter
