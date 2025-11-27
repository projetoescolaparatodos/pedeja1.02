# PedeJá - Aplicativo Android 📱

<div align="center">
  <h3>🍕 Delivery de Comida e Produtos Locais</h3>
  <p>Aplicativo nativo Android para conectar clientes e estabelecimentos comerciais</p>
</div>

---

## 📋 Sobre o Projeto

**PedeJá** é um aplicativo de delivery que permite aos usuários:
- 🛍️ Navegar por estabelecimentos locais
- 🍕 Fazer pedidos de comida e produtos
- 💳 Realizar pagamentos seguros via Mercado Pago
- 📍 Acompanhar entregas em tempo real
- ⭐ Avaliar estabelecimentos e produtos

---

## 🏗️ Arquitetura do Aplicativo

### Tecnologias Principais
- **Linguagem:** Kotlin/Java
- **Framework UI:** Flutter 3.x
- **Backend:** Firebase (Authentication, Firestore, Cloud Messaging)
- **Pagamentos:** Mercado Pago SDK
- **Mapas:** Google Maps API
- **Notificações:** Firebase Cloud Messaging (FCM)

### Estrutura Android

```
android/
├── app/
│   ├── src/main/
│   │   ├── AndroidManifest.xml          # Configurações e permissões
│   │   ├── kotlin/                       # Código nativo Kotlin
│   │   ├── res/                          # Resources (layouts, icons, strings)
│   │   │   ├── drawable/                 # Ícones e imagens
│   │   │   ├── values/                   # Strings, cores, estilos
│   │   │   └── mipmap/                   # App icons
│   │   └── proguard-rules.pro           # Regras de ofuscação
│   └── build.gradle.kts                  # Dependências do módulo
├── build.gradle.kts                      # Configuração do projeto
├── settings.gradle.kts                   # Módulos
└── gradle/                               # Gradle wrapper
```

---

## 🔐 Funcionalidades de Segurança

- ✅ Autenticação Firebase Authentication
- ✅ Validação de CPF para pagamentos
- ✅ Integração Mercado Pago (antifraude)
- ✅ Comunicação HTTPS/SSL
- ✅ Armazenamento seguro de tokens
- ✅ ProGuard/R8 para ofuscação de código

---

## 📱 Principais Funcionalidades

### Para Clientes
1. **Autenticação** - Login/registro seguro
2. **Busca** - Encontrar estabelecimentos próximos
3. **Cardápio** - Visualizar produtos e preços
4. **Carrinho** - Gerenciar pedido
5. **Pagamento** - Checkout com Mercado Pago
6. **Rastreamento** - Acompanhar pedido em tempo real
7. **Histórico** - Ver pedidos anteriores

### Para Estabelecimentos
1. **Gerenciamento de Produtos** - Adicionar/editar cardápio
2. **Receber Pedidos** - Notificações em tempo real
3. **Atualizar Status** - Informar progresso do pedido

---

## 🔧 Build do Projeto

### Pré-requisitos
- Android Studio Hedgehog (2023.1.1) ou superior
- JDK 11+
- Android SDK (API 21+)
- Flutter SDK 3.x

### Compilar APK

```bash
# Via Flutter (recomendado)
flutter build apk --release

# Via Gradle (Android puro)
cd android
./gradlew assembleRelease
```

**APK gerado em:** `build/app/outputs/flutter-apk/app-release.apk`

---

## 📦 Dependências Android

```gradle
dependencies {
    // Core Android
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    
    // Firebase
    implementation 'com.google.firebase:firebase-auth:22.3.0'
    implementation 'com.google.firebase:firebase-firestore:24.10.0'
    implementation 'com.google.firebase:firebase-messaging:23.4.0'
    
    // Mercado Pago (Pagamentos)
    implementation 'com.mercadopago.android.px:checkout:4.x'
    
    // Desugaring (compatibilidade Java 8)
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

---

## 🌐 Permissões

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

**Justificativa:**
- `INTERNET` → Comunicação com backend
- `ACCESS_*_LOCATION` → Buscar estabelecimentos próximos
- `POST_NOTIFICATIONS` → Avisos de pedido (Android 13+)

---

## 👥 Informações do App

- **Nome:** PedeJá
- **Package:** `com.example.pedeja_clean`
- **Versão Mínima:** Android 5.0 (API 21)
- **Versão Target:** Android 14 (API 34)
- **Público:** 16+ anos
- **Região:** Brasil (pt-BR)

---

## 📄 Privacidade e Dados

### Dados Coletados
- Nome, email, telefone (criação de conta)
- Localização GPS (buscar estabelecimentos)
- Histórico de pedidos (melhorar experiência)

### Segurança
- Senhas criptografadas (Firebase Auth)
- Pagamentos via Mercado Pago (PCI DSS compliant)
- Dados armazenados no Firebase (ISO 27001)
- **Nunca compartilhamos dados sem consentimento**

Link: [Política de Privacidade Completa](https://pedeja.com.br/privacidade)

---

## 📞 Suporte

- **Email:** suporte@pedeja.com.br
- **Organização:** Projeto Escola Para Todos
- **GitHub:** [@projetoescolaparatodos](https://github.com/projetoescolaparatodos)

---

## 🚀 Status

- ✅ Alpha Testing (Interno)
- ✅ Beta Testing (Grupo fechado)
- 🔄 **Submissão Google Play Store**

---

## 📝 Licença

Código proprietário. Todos os direitos reservados © 2025 PedeJá

---

**Desenvolvido com ❤️ no Brasil**

