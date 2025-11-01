# 🔔 Sistema de Notificações - PedeJá

## 📋 Visão Geral

O app PedeJá agora possui um sistema completo de notificações que mantém os clientes informados sobre:
- 📦 **Mudanças de status dos pedidos** (Preparando, Pronto, Entregue, etc.)
- 💬 **Novas mensagens no chat do pedido**

## 🎯 Funcionalidades

### 1. Notificações de Status de Pedido

O sistema monitora automaticamente todos os pedidos ativos do usuário e envia notificações quando o status muda:

#### Status Monitorados:
- **Pendente → Preparando**: "👨‍🍳 Pedido em Preparação - Seu pedido está sendo preparado! Em breve estará pronto."
- **Preparando → Pronto**: "✅ Pedido Pronto! - Seu pedido está pronto para ser retirado ou entregue!"
- **Pronto → Entregue**: "🎉 Pedido Entregue! - Seu pedido foi entregue. Bom apetite!"
- **Cancelado**: "❌ Pedido Cancelado - Seu pedido foi cancelado."

#### Características:
- ✅ Notificações em tempo real usando Firebase Firestore
- ✅ Funciona em foreground, background e quando o app está fechado
- ✅ Exibe ID curto do pedido (8 primeiros caracteres)
- ✅ Som e vibração configuráveis
- ✅ Ao clicar, abre os detalhes do pedido

### 2. Notificações de Chat

Sempre que o restaurante envia uma mensagem no chat do pedido, o cliente recebe uma notificação clara:

#### Formato da Notificação:
- **Título**: "💬 Nova mensagem no chat do pedido #ABC12345"
- **Corpo**: "Nome do Restaurante: Texto da mensagem"

#### Características:
- ✅ Notificações apenas de mensagens do restaurante (não das próprias)
- ✅ Texto claro indicando que é uma mensagem de chat
- ✅ ID do pedido visível para contexto
- ✅ Estilo de mensageria no Android (MessagingStyle)
- ✅ Ao clicar, abre o chat do pedido

## 🏗️ Arquitetura

### Serviços Criados/Atualizados:

#### 1. `OrderStatusListenerService` (NOVO)
**Localização**: `lib/services/order_status_listener_service.dart`

**Responsabilidades**:
- Escutar mudanças em tempo real no Firestore
- Detectar quando o status de um pedido muda
- Disparar notificações apropriadas
- Gerenciar cache de status conhecidos

**Métodos Principais**:
```dart
// Iniciar monitoramento de todos os pedidos do usuário
static Future<void> startListeningToUserOrders()

// Iniciar monitoramento de um pedido específico
static Future<void> startListeningToOrder(String orderId)

// Parar monitoramento
static Future<void> stopListeningToAllOrders()

// Limpar cache
static void clearCache()
```

#### 2. `NotificationService` (ATUALIZADO)
**Localização**: `lib/services/notification_service.dart`

**Novos Métodos**:
```dart
// Notificação de status de pedido
static Future<void> showOrderStatusNotification({
  required String orderId,
  required String title,
  required String body,
  required dynamic status,
})

// Notificação de chat (atualizada com texto mais claro)
static Future<void> showChatNotification({
  required String orderId,
  required String senderName,
  required String messageText,
})
```

#### 3. `ChatService` (JÁ EXISTENTE)
**Localização**: `lib/services/chat_service.dart`

- Já dispara notificações de chat automaticamente
- Verifica se a mensagem não é do próprio usuário
- Verifica se é mensagem do restaurante

#### 4. `AuthState` (ATUALIZADO)
**Localização**: `lib/state/auth_state.dart`

**Mudanças**:
- Inicia monitoramento de pedidos após login/cadastro
- Para monitoramento ao fazer logout
- Limpa cache de status ao deslogar

## 🔄 Fluxo de Funcionamento

### Login/Cadastro:
```
1. Usuário faz login/cadastro
2. AuthState detecta autenticação
3. OrderStatusListenerService.startListeningToUserOrders() é chamado
4. Listener ativo monitorando todos os pedidos do usuário
```

### Mudança de Status:
```
1. Restaurante atualiza status no Firestore (via painel admin)
2. OrderStatusListenerService detecta mudança
3. Compara com status anterior em cache
4. Se mudou, chama NotificationService.showOrderStatusNotification()
5. Usuário recebe notificação push local
6. Ao clicar, navega para detalhes do pedido
```

### Nova Mensagem de Chat:
```
1. Restaurante envia mensagem via Pusher
2. ChatService recebe evento 'new-message'
3. Verifica se NÃO é mensagem própria E se é do restaurante
4. Chama NotificationService.showChatNotification()
5. Usuário recebe notificação com texto claro
6. Ao clicar, navega para chat do pedido
```

### Logout:
```
1. Usuário faz logout
2. AuthState chama OrderStatusListenerService.stopListeningToAllOrders()
3. Todos os listeners são cancelados
4. Cache é limpo
5. Token FCM é removido
```

## 📱 Canais de Notificação (Android)

### Canal: `order_updates`
- **Nome**: Atualizações de Pedidos
- **Descrição**: Notificações sobre o status dos seus pedidos
- **Importância**: Alta
- **Som**: Sim
- **Vibração**: Sim

### Canal: `chat_messages`
- **Nome**: Mensagens do Chat
- **Descrição**: Notificações de novas mensagens no chat
- **Importância**: Alta
- **Som**: Sim
- **Vibração**: Sim

## 🎨 Personalização de Mensagens

### Títulos por Status:
| Status | Emoji | Título |
|--------|-------|--------|
| preparing | 👨‍🍳 | Pedido em Preparação |
| ready | ✅ | Pedido Pronto! |
| delivered | 🎉 | Pedido Entregue! |
| cancelled | ❌ | Pedido Cancelado |

### Formato de Chat:
- Título: `💬 Nova mensagem no chat do pedido #ABC12345`
- Corpo: `[Nome]: [Mensagem]`

## 🔐 Permissões Necessárias

### Android (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### iOS (`Info.plist`):
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

## 🧪 Testando

### Teste de Notificação de Status:
1. Faça login no app
2. Crie um pedido
3. No painel admin, mude o status do pedido
4. Aguarde 1-2 segundos
5. Notificação deve aparecer

### Teste de Notificação de Chat:
1. Faça login no app
2. Crie um pedido
3. Abra o chat do pedido
4. No painel do restaurante, envie uma mensagem
5. Notificação deve aparecer (mesmo com o chat aberto)

### Teste em Background:
1. Faça login no app
2. Crie um pedido
3. Minimize o app
4. Mude o status no painel admin
5. Notificação deve aparecer na barra de notificações

## 📊 Logs de Debug

O sistema gera logs detalhados para facilitar debugging:

```
👂 [OrderStatusListener] Iniciando monitoramento de pedidos do usuário
📦 [OrderStatusListener] Mudanças detectadas em 1 pedidos
🔄 [OrderStatusListener] Status do pedido ABC123 mudou: Pendente → Preparando
📦 [NotificationService] Mostrando notificação de status
💬 [ChatService] Disparando notificação de nova mensagem
🔔 [NotificationService] Notificação de chat exibida
```

## 🚀 Melhorias Futuras

- [ ] Agrupar notificações por pedido
- [ ] Notificações ricas com imagem do pedido
- [ ] Ações rápidas (ex: "Ver Pedido", "Abrir Chat")
- [ ] Badge de contagem no ícone do app
- [ ] Som personalizado por tipo de notificação
- [ ] Configurações de notificação no perfil
- [ ] Histórico de notificações
- [ ] Notificações de promoções/ofertas

## 📝 Notas Técnicas

- As notificações usam `flutter_local_notifications` para exibição
- O monitoramento usa Firestore Snapshots (real-time)
- Chat usa Pusher Channels para mensagens em tempo real
- IDs únicos baseados em `hashCode` do orderId
- Cache de status para evitar notificações duplicadas
- Listeners são automaticamente limpos no logout

## ⚠️ Troubleshooting

### Notificações não aparecem:
1. Verificar permissões do app
2. Verificar se listener foi iniciado (check logs)
3. Verificar conexão com Firestore
4. Verificar se status realmente mudou

### Notificações duplicadas:
1. Verificar cache de status
2. Verificar se há múltiplos listeners ativos
3. Check logs para `_lastKnownStatus`

### Chat não notifica:
1. Verificar conexão com Pusher
2. Verificar se mensagem é do restaurante (`isRestaurant: true`)
3. Verificar se não é mensagem própria (`isMe: false`)
4. Check logs do ChatService

## 📚 Referências

- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [Pusher Channels Flutter](https://pub.dev/packages/pusher_channels_flutter)
- [Cloud Firestore Snapshots](https://firebase.google.com/docs/firestore/query-data/listen)
