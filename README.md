# 📱 PedeJá - App de Delivery Completo

> **Versão Atual**: 1.0.42+42  
> **Última Atualização**: 03 de Fevereiro de 2026

## 🎯 Sobre o Projeto

**PedeJá** é um aplicativo completo de delivery desenvolvido em Flutter, oferecendo uma experiência moderna e fluida para pedidos de comida, farmácia e mercado.

### ✨ Principais Recursos
- 🍔 Delivery de Comida (Restaurantes)
- 🥩 Açougue
- 🍺 Bebidas
- 💊 Farmácia
- 🧴 Perfumaria e Cuidados Pessoais
- 🛒 Mercado
- 💬 **Chat em Tempo Real** (Pusher + Firebase)
- 📹 Promoções em Vídeo
- 💳 Pagamentos (Cartão, PIX, Dinheiro)
- 🚚 Taxa de Entrega Dinâmica

---

## 📝 Changelog Recente

### v1.0.42 (03/02/2026) - 🔧 CORREÇÃO CRÍTICA: Chat History

**Problema Identificado:**
- ❌ Histórico de mensagens não carregava ao abrir conversas existentes
- ✅ Apenas mensagens em tempo real (Pusher) apareciam

**Solução:**
- ✅ Adicionada chamada `_loadCachedMessages()` no `initState()`
- ✅ Implementado sistema triple-fallback:
  1. Cache local (SharedPreferences + Memory)
  2. Backend API (`/api/orders/:orderId/messages?limit=100`)
  3. Firebase direto (fallback automático)
- ✅ Logs detalhados para debugging (🔍💾🔄🌐🔥)

**Arquivos Modificados:**
- `lib/pages/orders/order_details_page.dart`
- `lib/services/chat_service.dart`
- `lib/services/backend_order_service.dart`

**Teste Validado:** Pedido `cF4QrXeCXW0Db0n5adAm` com 7 mensagens carrega 100% corretamente.

### v1.0.41 (Janeiro 2026)
- ✅ Seção Açougue adicionada (depois de Bebidas)
- ✅ Navegação por seções com GlobalKeys (scroll preciso)
- ✅ Bordas douradas nos cards de adicionais
- ✅ Modal de login sempre visível

---

## 🚀 Como Rodar o Projeto

### Pré-requisitos
- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio / Xcode
- Firebase CLI (para configuração)

### Instalação

```bash
# Clone o repositório
git clone [URL_DO_REPO]

# Instale as dependências
flutter pub get

# Execute no dispositivo/emulador
flutter run
```

### Build APK (Release)

```bash
flutter build apk --release
```

APK gerado em: `build/app/outputs/flutter-apk/app-release.apk`

---

## 📚 Documentação Completa

- **[DOCUMENTACAO_PROJETO.md](./DOCUMENTACAO_PROJETO.md)** - Documentação técnica completa
- **[CHAT_TEMPO_REAL_IMPLEMENTACAO_DETALHADA.md](./CHAT_TEMPO_REAL_IMPLEMENTACAO_DETALHADA.md)** - Chat em tempo real
- **[IMPLEMENTACAO_COMPLETA_TAXA_DINAMICA.md](./IMPLEMENTACAO_COMPLETA_TAXA_DINAMICA.md)** - Taxa de entrega
- **[GUIA_PAGAMENTO_CARTAO.md](./GUIA_PAGAMENTO_CARTAO.md)** - Integração de pagamentos

---

## 🛠️ Stack Tecnológica

- **Frontend**: Flutter 3.x
- **State Management**: Provider
- **Backend**: Node.js/Vercel (https://api-pedeja.vercel.app)
- **Database**: Firebase (Firestore + Auth)
- **Real-time**: Pusher (WebSocket)
- **Storage**: Firebase Storage
- **Notifications**: Firebase Cloud Messaging

---

## 📞 Suporte

Para dúvidas ou problemas, consulte a documentação completa em `DOCUMENTACAO_PROJETO.md`.
