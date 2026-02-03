# 💬 Guia Completo de Integração do Chat em Tempo Real

## ✅ CORREÇÃO v1.0.42 - Histórico de Mensagens Corrigido

**Data**: 03/02/2026

### Problema Resolvido
- ❌ **Antes**: Histórico do Firebase não carregava ao abrir conversas
- ✅ **Depois**: Sistema triple-fallback (Cache → API → Firebase direto)
- 📊 **Resultado**: 100% das mensagens históricas carregam corretamente

**Ver detalhes completos em**: [CHAT_TEMPO_REAL_IMPLEMENTACAO_DETALHADA.md](./CHAT_TEMPO_REAL_IMPLEMENTACAO_DETALHADA.md)

---

## 📋 Visão Geral

O chat funciona com a seguinte arquitetura:

```
┌─────────────┐      POST      ┌─────────────┐      Trigger     ┌─────────────┐
│   CLIENTE   │  ────────────> │   BACKEND   │  ──────────────> │   PUSHER    │
│  (Mobile)   │                │   (API)     │                  │  (WebSocket)│
└─────────────┘                └─────────────┘                  └─────────────┘
       ↑                                                                │
       │                        Broadcast                               │
       └────────────────────────────────────────────────────────────────┘
                                  (new-message)

┌─────────────┐                                                  ┌─────────────┐
│  VENDEDOR   │  <────────────────────────────────────────────── │   PUSHER    │
│   (Web)     │                Recebe evento                     │  (WebSocket)│
└─────────────┘                 (new-message)                    └─────────────┘
```

---

## 🔧 Componentes

### 1. **Pusher Credentials**

```javascript
const PUSHER_CONFIG = {
  key: '45b7798e358505a8343e',
  cluster: 'us2'
};
```

⚠️ **IMPORTANTE**: A key foi atualizada! Se estava usando `503fe57633a24b82b7a1`, atualize para `45b7798e358505a8343e`.

---

## 🔄 Fluxo Completo

### **Passo 1: Cliente Envia Mensagem**

#### App Mobile (Flutter):
```dart
// 1. Usuário digita e clica em enviar
ChatService.sendMessage(
  orderId: 'wGuE7BsNJCRJ3erkY6gl',
  message: 'Olá, qual o tempo de entrega?',
  userName: 'João Silva',
  userId: 'abc123xyz',  // ✅ Firebase UID
);
```

#### Request HTTP:
```http
POST https://api-pedeja.vercel.app/api/orders/wGuE7BsNJCRJ3erkY6gl/messages
Content-Type: application/json

{
  "message": "Olá, qual o tempo de entrega?",
  "senderName": "João Silva",
  "isRestaurant": false,
  "timestamp": "2025-11-01T14:30:00.000Z",
  "userId": "abc123xyz"
}
```

**✅ Observações:**
- `orderId` vai na **URL**, não no body
- `isRestaurant: false` indica que é o **cliente** enviando
- `userId` é o Firebase UID do usuário (para identificar quem enviou)

---

### **Passo 2: Backend Processa e Envia ao Pusher**

#### Backend API:
```javascript
// api/orders/[id]/messages/route.js (ou similar)

app.post('/api/orders/:orderId/messages', async (req, res) => {
  const { orderId } = req.params;
  const { message, senderName, isRestaurant, timestamp, userId } = req.body;

  // ✅ Salvar mensagem no banco (opcional, mas recomendado)
  await saveMessageToDatabase({
    orderId,
    message,
    senderName,
    isRestaurant,
    timestamp,
    userId
  });

  // ✅ Enviar evento ao Pusher
  await pusher.trigger(
    `order-${orderId}`,  // Canal: order-wGuE7BsNJCRJ3erkY6gl
    'new-message',       // Evento
    {
      message,
      senderName,
      user: senderName,  // ⚠️ Alias para compatibilidade
      isRestaurant,
      timestamp,
      userId
    }
  );

  res.json({ success: true });
});
```

**✅ Payload enviado ao Pusher:**
```json
{
  "message": "Olá, qual o tempo de entrega?",
  "senderName": "João Silva",
  "user": "João Silva",
  "isRestaurant": false,
  "timestamp": "2025-11-01T14:30:00.000Z",
  "userId": "abc123xyz"
}
```

---

### **Passo 3: Pusher Broadcast para Todos**

O Pusher envia o evento `new-message` para **TODOS** os clientes conectados ao canal `order-{orderId}`:

- ✅ App Mobile (cliente que enviou)
- ✅ Painel Web (vendedor)
- ✅ Outros dispositivos do mesmo usuário

---

### **Passo 4: Painel Web Recebe Mensagem**

#### Conexão ao Pusher (JavaScript):
```javascript
// Inicializar Pusher
const pusher = new Pusher('45b7798e358505a8343e', {
  cluster: 'us2'
});

// Inscrever no canal do pedido
const orderId = 'wGuE7BsNJCRJ3erkY6gl';
const channel = pusher.subscribe(`order-${orderId}`);

// Escutar evento 'new-message'
channel.bind('new-message', function(data) {
  console.log('📨 Mensagem recebida:', data);
  
  // ✅ Estrutura do data:
  // {
  //   message: "Olá, qual o tempo de entrega?",
  //   senderName: "João Silva",
  //   user: "João Silva",
  //   isRestaurant: false,
  //   timestamp: "2025-11-01T14:30:00.000Z",
  //   userId: "abc123xyz"
  // }

  // Adicionar mensagem na UI
  addMessageToChat(data);
});

function addMessageToChat(data) {
  const isFromRestaurant = data.isRestaurant === true;
  const messageHtml = `
    <div class="message ${isFromRestaurant ? 'restaurant' : 'customer'}">
      <strong>${data.senderName || data.user}</strong>
      <p>${data.message}</p>
      <small>${new Date(data.timestamp).toLocaleString()}</small>
    </div>
  `;
  
  document.getElementById('chat-messages').innerHTML += messageHtml;
}
```

---

## 🔁 Fluxo Reverso (Vendedor → Cliente)

### **Passo 1: Vendedor Envia Mensagem**

#### Painel Web:
```javascript
async function sendMessage(orderId, message, senderName) {
  const payload = {
    message: message,
    senderName: senderName,
    isRestaurant: true,  // ✅ Vendedor enviando
    timestamp: new Date().toISOString(),
    userId: 'restaurant-id-xyz'  // ✅ ID do restaurante
  };

  const response = await fetch(
    `https://api-pedeja.vercel.app/api/orders/${orderId}/messages`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    }
  );

  if (!response.ok) {
    console.error('❌ Erro ao enviar mensagem');
  }
}

// Exemplo de uso:
sendMessage('wGuE7BsNJCRJ3erkY6gl', 'Entrega em 30 minutos!', 'Restaurante XYZ');
```

### **Passo 2: Backend → Pusher → App Mobile**

O backend repete o mesmo processo:
1. Salva no banco (opcional)
2. Envia ao Pusher no canal `order-{orderId}`
3. Pusher faz broadcast
4. App mobile recebe e mostra na UI

---

## 🐛 Troubleshooting

### **Problema: Mensagens não aparecem no painel web**

#### Checklist:
1. ✅ **Key correta?**
   ```javascript
   // ❌ ERRADO
   new Pusher('503fe57633a24b82b7a1', ...)
   
   // ✅ CORRETO
   new Pusher('45b7798e358505a8343e', ...)
   ```

2. ✅ **Canal correto?**
   ```javascript
   // ✅ Formato: order-{orderId}
   pusher.subscribe('order-wGuE7BsNJCRJ3erkY6gl');
   
   // ❌ ERRADO: sem prefixo 'order-'
   pusher.subscribe('wGuE7BsNJCRJ3erkY6gl');
   ```

3. ✅ **Evento correto?**
   ```javascript
   // ✅ CORRETO
   channel.bind('new-message', ...)
   
   // ❌ ERRADO: nome diferente
   channel.bind('message', ...)
   channel.bind('chat-message', ...)
   ```

4. ✅ **Conexão estabelecida?**
   ```javascript
   pusher.connection.bind('connected', () => {
     console.log('✅ Conectado ao Pusher');
   });
   
   pusher.connection.bind('error', (err) => {
     console.error('❌ Erro Pusher:', err);
   });
   ```

5. ✅ **Logs de debug:**
   ```javascript
   Pusher.logToConsole = true;  // ✅ Ativar logs detalhados
   ```

---

### **Problema: Mensagens duplicadas**

#### Causa:
Adicionar mensagem localmente + receber via Pusher

#### ❌ ERRADO:
```javascript
async function sendMessage(message) {
  // Adiciona localmente
  addMessageToChat({
    message: message,
    senderName: 'Eu',
    isRestaurant: true,
    timestamp: new Date().toISOString()
  });

  // Envia ao backend (que vai enviar ao Pusher)
  await fetch('/api/orders/.../messages', { ... });
  // ❌ Resultado: mensagem duplicada quando Pusher retornar
}
```

#### ✅ CORRETO:
```javascript
async function sendMessage(message) {
  // NÃO adiciona localmente
  // Apenas envia ao backend
  await fetch('/api/orders/.../messages', { ... });
  
  // ✅ O Pusher vai retornar a mensagem e ela será adicionada via 'new-message'
}
```

---

### **Problema: Não identifica quem enviou (isMe)**

#### Solução:
Comparar `userId` da mensagem com o ID do usuário logado:

```javascript
// Ao receber mensagem via Pusher
channel.bind('new-message', function(data) {
  const currentUserId = getCurrentUserId(); // ID do vendedor logado
  const isMe = data.userId === currentUserId;
  
  addMessageToChat(data, isMe);
});

function addMessageToChat(data, isMe) {
  const alignment = isMe ? 'right' : 'left';
  const bgColor = isMe ? 'blue' : 'gray';
  
  // Renderizar com estilo apropriado
  // ...
}
```

---

## 📊 Estrutura de Dados

### **Mensagem Enviada (Request):**
```typescript
interface MessagePayload {
  message: string;           // Texto da mensagem
  senderName: string;        // Nome do remetente
  isRestaurant: boolean;     // true = vendedor, false = cliente
  timestamp: string;         // ISO 8601 (ex: "2025-11-01T14:30:00.000Z")
  userId: string;            // ID único do remetente
}
```

### **Mensagem Recebida (Pusher Event):**
```typescript
interface PusherMessage {
  message: string;           // Texto da mensagem
  senderName: string;        // Nome do remetente
  user: string;              // Alias de senderName (compatibilidade)
  isRestaurant: boolean;     // true = vendedor, false = cliente
  timestamp: string;         // ISO 8601
  userId: string;            // ID único do remetente
}
```

---

## 🧪 Teste Completo

### **1. Debug Console do Pusher**
- Acesse: https://dashboard.pusher.com/apps/YOUR_APP_ID/console
- Vá em "Debug Console"
- Envie uma mensagem pelo app mobile
- Verifique se aparece:
  ```
  channel: order-{orderId}
  event: new-message
  data: { message: "...", ... }
  ```

### **2. Browser Console**
```javascript
// Ativar logs detalhados
Pusher.logToConsole = true;

// Verificar conexão
pusher.connection.state; // deve retornar "connected"

// Verificar canal
channel.subscribed; // deve retornar true
```

### **3. Testar envio do painel web**
```javascript
// Enviar mensagem de teste
sendMessage(orderId, 'Teste 123', 'Restaurante');

// Verificar logs no console:
// ✅ POST /api/orders/.../messages → 200 OK
// ✅ Pusher event received: new-message
```

---

## ✅ Checklist Final

- [ ] Key do Pusher atualizada: `45b7798e358505a8343e`
- [ ] Cluster correto: `us2`
- [ ] Canal formato: `order-{orderId}`
- [ ] Evento escutado: `new-message`
- [ ] Endpoint POST: `/api/orders/{orderId}/messages`
- [ ] Payload com: `message`, `senderName`, `isRestaurant`, `timestamp`, `userId`
- [ ] `orderId` na URL (não no body)
- [ ] Não adicionar mensagem localmente ao enviar
- [ ] Deixar o Pusher adicionar para todos
- [ ] Identificar `isMe` comparando `userId`

---

## 📱 Exemplo Completo (React)

```jsx
import Pusher from 'pusher-js';
import { useState, useEffect } from 'react';

function OrderChat({ orderId, currentUserId }) {
  const [messages, setMessages] = useState([]);
  const [inputMessage, setInputMessage] = useState('');

  useEffect(() => {
    // Inicializar Pusher
    const pusher = new Pusher('45b7798e358505a8343e', {
      cluster: 'us2'
    });

    // Inscrever no canal
    const channel = pusher.subscribe(`order-${orderId}`);

    // Escutar mensagens
    channel.bind('new-message', (data) => {
      console.log('📨 Nova mensagem:', data);
      
      setMessages(prev => [...prev, {
        ...data,
        isMe: data.userId === currentUserId
      }]);
    });

    // Cleanup
    return () => {
      channel.unbind_all();
      channel.unsubscribe();
    };
  }, [orderId, currentUserId]);

  const sendMessage = async () => {
    if (!inputMessage.trim()) return;

    const payload = {
      message: inputMessage,
      senderName: 'Restaurante XYZ',
      isRestaurant: true,
      timestamp: new Date().toISOString(),
      userId: currentUserId
    };

    try {
      const response = await fetch(
        `https://api-pedeja.vercel.app/api/orders/${orderId}/messages`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        }
      );

      if (response.ok) {
        setInputMessage(''); // Limpar input
        // ✅ NÃO adicionar localmente - Pusher vai retornar
      }
    } catch (error) {
      console.error('❌ Erro ao enviar:', error);
    }
  };

  return (
    <div className="chat">
      <div className="messages">
        {messages.map((msg, idx) => (
          <div key={idx} className={msg.isMe ? 'message-right' : 'message-left'}>
            <strong>{msg.senderName}</strong>
            <p>{msg.message}</p>
            <small>{new Date(msg.timestamp).toLocaleString()}</small>
          </div>
        ))}
      </div>
      
      <div className="input">
        <input
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
        />
        <button onClick={sendMessage}>Enviar</button>
      </div>
    </div>
  );
}
```

---

## 🎯 Resumo para o Dev do Site

**O que fazer:**

1. ✅ Atualizar key: `45b7798e358505a8343e`
2. ✅ Conectar ao canal: `order-{orderId}`
3. ✅ Escutar evento: `new-message`
4. ✅ Enviar via POST: `/api/orders/{orderId}/messages`
5. ✅ **Não adicionar localmente ao enviar** - deixar Pusher fazer broadcast
6. ✅ Identificar mensagens próprias comparando `userId`

**Campos obrigatórios ao enviar:**
- `message` (string)
- `senderName` (string)
- `isRestaurant` (boolean) - **true para vendedor**
- `timestamp` (ISO 8601 string)
- `userId` (string)

---

**🚀 Com isso, o chat funcionará perfeitamente em tempo real entre app mobile e painel web!**
