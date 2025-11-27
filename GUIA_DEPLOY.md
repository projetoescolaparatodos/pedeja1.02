# 📱 Guia Completo de Deploy - PedeJá

**App:** PedeJá - Food Delivery  
**Versão:** 1.0.0+1  
**Plataformas:** Google Play Store & Apple App Store  
**Data:** Novembro 2025

---

## 📋 Pré-requisitos Gerais

- [ ] Flutter SDK 3.x instalado
- [ ] Conta Google Play Console (R$ 150 pagamento único)
- [ ] Conta Apple Developer Program (US$ 99/ano)
- [ ] Logo do app em alta resolução (1024x1024px)
- [ ] Screenshots do app (5-8 capturas por plataforma)
- [ ] Descrição do app em português
- [ ] Política de privacidade hospedada (URL pública)
- [ ] Certificados de assinatura configurados

---

## 🤖 PARTE 1: Google Play Store (Android)

### ✅ Checklist de Preparação

#### 1. Atualizar Build Configuration

**Arquivo:** `android/app/build.gradle.kts`

**Alterações necessárias:**
```kotlin
android {
    namespace = "com.pedeja.app"  // ✅ Mudar de com.example.pedeja_clean
    compileSdk = 34  // ✅ Atualizar para API 34

    defaultConfig {
        applicationId = "com.pedeja.app"  // ✅ ID único do app
        minSdk = 23  // ✅ Suporta 95% dos dispositivos Android
        targetSdk = 34  // ✅ Última API estável
        versionCode = 1  // ✅ Incrementar a cada release
        versionName = "1.0.0"  // ✅ Versão visível ao usuário
        
        // ✅ Configurações multiDex
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // ⚠️ CRÍTICO: Configurar assinatura de release
            signingConfig = signingConfigs.getByName("release")
            
            // ✅ Otimizações para produção
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // ✅ Splits para APKs menores
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }
}
```

#### 2. Criar Keystore de Assinatura

**Gerar keystore (executar no terminal):**
```powershell
# Navegue até android/app
cd android\app

# Gere a keystore
keytool -genkey -v -keystore pedeja-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias pedeja-key
```

**Informações para preencher:**
- **Senha do keystore:** (anote com segurança!)
- **Nome:** PedeJá
- **Unidade organizacional:** PedeJá Dev Team
- **Organização:** PedeJá
- **Cidade:** Belém
- **Estado:** Pará
- **Código do país:** BR

**⚠️ IMPORTANTE:** Guarde a keystore e senha em local seguro! Sem ela, não conseguirá atualizar o app!

#### 3. Configurar Assinatura no Gradle

**Criar arquivo:** `android/key.properties`

```properties
storePassword=SUA_SENHA_KEYSTORE
keyPassword=SUA_SENHA_KEY
keyAlias=pedeja-key
storeFile=pedeja-release-key.jks
```

**⚠️ IMPORTANTE:** Adicione `key.properties` ao `.gitignore`:
```
# android/key.properties
key.properties
*.jks
```

**Atualizar:** `android/app/build.gradle.kts`

```kotlin
// No topo do arquivo, antes de android {
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... configurações existentes

    signingConfigs {
        create("release") {
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // ...
        }
    }
}
```

#### 4. Atualizar `android/app/src/main/AndroidManifest.xml`

**Adicionar permissões necessárias:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- ✅ Internet (obrigatório) -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <!-- ✅ Localização -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- ✅ Notificações -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    
    <!-- ✅ Rede -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- ✅ Vibração (notificações) -->
    <uses-permission android:name="android.permission.VIBRATE" />
    
    <application
        android:label="PedeJá"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="false">  <!-- ✅ Apenas HTTPS -->
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            
            <!-- ✅ Deep link example -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data
                    android:scheme="https"
                    android:host="pedeja.com.br" />
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

#### 5. Gerar Build de Produção

**Executar no terminal:**

```powershell
# Limpar builds anteriores
flutter clean

# Instalar dependências
flutter pub get

# Gerar AAB (Android App Bundle) - RECOMENDADO
flutter build appbundle --release

# OU gerar APK (apenas para testes)
flutter build apk --release --split-per-abi
```

**Arquivos gerados:**
- **AAB:** `build/app/outputs/bundle/release/app-release.aab` (para Google Play)
- **APK:** `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (para testes)

**Tamanho esperado:**
- AAB: ~40-60 MB
- APK: ~20-30 MB por ABI

#### 6. Preparar Recursos Visuais

**Screenshots necessários:**
- Mínimo: 2 screenshots
- Recomendado: 5-8 screenshots
- Formato: PNG ou JPG
- Resolução mínima: 320px
- Resolução máxima: 3840px
- Proporção: 16:9 ou 9:16

**Tipos de screenshots:**
1. Tela de login/onboarding
2. Home page com restaurantes
3. Detalhes de produto
4. Carrinho de compras
5. Chat com vendedor
6. Status do pedido
7. Perfil do usuário
8. Mapa de entrega

**Ícone do app:**
- **512x512px** - High-res icon (obrigatório)
- **1024x1024px** - Feature graphic (banner)
- Formato: PNG (32-bit)
- Sem transparência no ícone principal

#### 7. Criar Conta no Google Play Console

**URL:** https://play.google.com/console/signup

**Passos:**
1. ✅ Criar conta Google Developer (R$ 150 única vez)
2. ✅ Aceitar termos e condições
3. ✅ Preencher informações da organização
4. ✅ Configurar métodos de pagamento (para receber vendas in-app, se houver)

#### 8. Criar Novo App no Console

**Play Console → Todos os apps → Criar app:**

**Informações básicas:**
- **Nome do app:** PedeJá - Delivery de Comida
- **Idioma padrão:** Português (Brasil)
- **App ou jogo:** App
- **Gratuito ou pago:** Gratuito
- **Categoria:** Food & Drink
- **Público-alvo:** Maiores de 3 anos (selecionar categorias adequadas)

#### 9. Preencher Ficha da Play Store

**Descrição curta (80 caracteres):**
```
Delivery rápido de comida, bebidas e farmácia. Peça agora!
```

**Descrição completa (4000 caracteres):**
```
🍕 PedeJá - Seu App de Delivery Favorito!

Peça comida, bebidas e produtos de farmácia com rapidez e segurança. Com o PedeJá, você tem acesso aos melhores restaurantes e lojas da sua região, tudo na palma da sua mão!

✨ RECURSOS PRINCIPAIS:

🍔 Variedade de Restaurantes
• Milhares de opções: pizzarias, hamburguerias, comida japonesa, lanches, sobremesas e muito mais
• Filtros inteligentes por categoria, preço e avaliação
• Promoções exclusivas e cupons de desconto

🚀 Entrega Rápida
• Acompanhamento em tempo real do seu pedido
• Notificações instantâneas sobre o status da entrega
• Chat direto com o estabelecimento
• Tempo estimado de entrega preciso

💰 Pagamento Seguro
• Múltiplas formas de pagamento: cartão, Pix, dinheiro
• Sistema de pagamento criptografado
• Histórico completo de pedidos e pagamentos

📍 Localização Inteligente
• Preenchimento automático do endereço via GPS
• Salvamento de múltiplos endereços
• Entrega onde você estiver

🎯 Experiência Personalizada
• Produtos recomendados baseados no seu gosto
• Favoritos salvos para pedidos rápidos
• Avaliações e comentários de outros usuários

💊 Farmácia 24h
• Delivery de medicamentos e produtos de farmácia
• Opções de medicamentos com e sem receita
• Atendimento rápido para emergências

🎉 VANTAGENS DO PEDEJÁ:

✓ Interface moderna e intuitiva
✓ Processo de pedido em poucos cliques
✓ Cupons e promoções exclusivas
✓ Atendimento ao cliente dedicado
✓ Avaliações verificadas
✓ Sem taxa de entrega em restaurantes participantes

📱 COMO FUNCIONA:

1. Escolha seu restaurante ou loja favorita
2. Monte seu pedido com os produtos desejados
3. Adicione adicionais e personalize como quiser
4. Escolha a forma de pagamento
5. Confirme o endereço de entrega
6. Acompanhe seu pedido em tempo real
7. Receba e aproveite!

🔒 SEGURANÇA E PRIVACIDADE:

• Dados protegidos com criptografia de ponta
• Conformidade com LGPD (Lei Geral de Proteção de Dados)
• Transações seguras via Mercado Pago
• Nunca compartilhamos seus dados pessoais

🌟 DEPOIMENTOS:

"Melhor app de delivery! Rápido, prático e sempre com promoções." - Maria S.
"Interface linda e fácil de usar. Recomendo!" - João P.
"Entrega sempre no prazo, comida chegando quentinha." - Ana R.

📞 SUPORTE:

Alguma dúvida ou problema? Nossa equipe está pronta para ajudar!
• E-mail: suporte@pedeja.com.br
• WhatsApp: (91) 9999-9999
• Chat in-app disponível 24/7

🎁 BAIXE AGORA E GANHE:

• Cupom de R$ 15 OFF no primeiro pedido
• Frete grátis em pedidos acima de R$ 30
• Acesso a promoções exclusivas

Faça parte da comunidade PedeJá e descubra por que somos o app de delivery mais amado da região!

#PedeJá #Delivery #Comida #Restaurantes #FoodDelivery #EntregaRápida
```

#### 10. Configurar Classificação de Conteúdo

**Play Console → Classificação de conteúdo:**

**Categoria:** Food & Drink / Delivery App

**Perguntas comuns:**
- Violência: Não
- Conteúdo sexual: Não
- Linguagem inadequada: Não
- Discriminação: Não
- Drogas/Álcool: Sim (delivery pode incluir bebidas alcoólicas)
- Conteúdo gerado por usuários: Sim (avaliações e chat)
- Compartilhamento de localização: Sim (entrega de pedidos)
- Compras: Sim (compra de produtos)

**Classificação esperada:** LIVRE (maiores de 3 anos com informações sobre álcool)

#### 11. Configurar Público-Alvo

**Faixa etária principal:** 18-65 anos

**Público-alvo:**
- [x] Maiores de 18 anos (devido a álcool)
- [x] Interessados em delivery de comida
- [x] Usuários urbanos
- [x] Famílias

#### 12. Upload do AAB

**Play Console → Produção → Criar nova versão:**

1. ✅ Fazer upload de `app-release.aab`
2. ✅ Aguardar validação automática
3. ✅ Preencher notas da versão:

**Notas da versão (em português):**
```
🎉 Lançamento Inicial - Versão 1.0.0

Bem-vindo ao PedeJá! Recursos incluídos nesta versão:

✅ Catálogo completo de restaurantes e produtos
✅ Sistema de carrinho de compras otimizado
✅ Pagamento seguro via Mercado Pago
✅ Pagamento em dinheiro na entrega
✅ Acompanhamento de pedidos em tempo real
✅ Chat instantâneo com vendedores
✅ Notificações de status do pedido
✅ Localização automática via GPS
✅ Vídeos promocionais
✅ Busca avançada de produtos
✅ Perfil personalizável
✅ Histórico de pedidos

Obrigado por usar o PedeJá! 🍕🚀
```

#### 13. Preencher Política de Privacidade

**⚠️ OBRIGATÓRIO:** URL pública com política de privacidade

**Exemplo de URL:** `https://pedeja.com.br/privacy-policy`

**Conteúdo mínimo (LGPD compliance):**

```markdown
# Política de Privacidade - PedeJá

Última atualização: Novembro 2025

## 1. Coleta de Dados

O PedeJá coleta as seguintes informações:
- Nome completo, CPF, e-mail, telefone
- Endereço de entrega
- Localização via GPS (com permissão)
- Histórico de pedidos
- Informações de pagamento (processadas via Mercado Pago)
- Mensagens de chat com estabelecimentos

## 2. Uso dos Dados

Seus dados são utilizados para:
- Processar e entregar seus pedidos
- Comunicação sobre status de pedidos
- Suporte ao cliente
- Melhorias no serviço
- Promoções e ofertas (com seu consentimento)

## 3. Compartilhamento

Compartilhamos dados apenas com:
- Restaurantes/estabelecimentos (para processar pedidos)
- Mercado Pago (para processar pagamentos)
- Firebase/Google (infraestrutura de backend)
- Pusher (sistema de chat)

Nunca vendemos seus dados para terceiros.

## 4. Segurança

- Criptografia SSL/TLS
- Dados armazenados em servidores Firebase (Google Cloud)
- Autenticação via Firebase Auth
- Conformidade com LGPD

## 5. Seus Direitos

Você pode:
- Acessar seus dados
- Corrigir informações incorretas
- Solicitar exclusão da conta
- Revogar permissões

Contato: suporte@pedeja.com.br

## 6. Cookies e Analytics

Não utilizamos cookies de rastreamento de terceiros.

## 7. Alterações

Reservamos o direito de atualizar esta política. Mudanças serão notificadas no app.
```

#### 14. Configurar Preços e Distribuição

**Países disponíveis:** Brasil (ou selecionar outros)

**Preço:** Gratuito

**Distribuição:**
- [x] Google Play
- [x] Todos os dispositivos Android (telefone, tablet)

#### 15. Revisar e Publicar

**Play Console → Painel → Revisar versão:**

**Checklist final:**
- [x] AAB carregado com sucesso
- [x] Screenshots adicionados (mínimo 2)
- [x] Ícone 512x512px adicionado
- [x] Descrição completa preenchida
- [x] Classificação de conteúdo aprovada
- [x] Política de privacidade configurada
- [x] Público-alvo definido
- [x] Notas da versão escritas

**Clicar em:** "Enviar para revisão"

**Tempo de revisão:** 1-7 dias (média 24-48 horas)

---

## 🍎 PARTE 2: Apple App Store (iOS)

### ✅ Checklist de Preparação

#### 1. Requisitos de Hardware/Software

**Necessário:**
- Mac com macOS Ventura 13+ ou Sonoma 14+
- Xcode 15.0+
- Conta Apple Developer ($99/ano)
- Certificado de distribuição
- Provisioning Profile

**⚠️ IMPORTANTE:** iOS exige Mac para compilar e submeter!

#### 2. Configurar Xcode Project

**Abrir projeto no Xcode:**
```bash
# Navegue até a pasta do projeto
cd pedeja1.02

# Abra o workspace (NÃO o .xcodeproj!)
open ios/Runner.xcworkspace
```

**No Xcode:**

**A. General Tab:**
- **Display Name:** PedeJá
- **Bundle Identifier:** `com.pedeja.app` (deve ser único)
- **Version:** 1.0.0
- **Build:** 1
- **Deployment Target:** iOS 13.0 (suporta 98% dos iPhones)
- **Devices:** iPhone (ou Universal para iPad também)

**B. Signing & Capabilities:**

1. ✅ Selecionar Team: (sua conta Apple Developer)
2. ✅ Automatically manage signing: ATIVAR
3. ✅ Adicionar Capabilities:
   - **Push Notifications** ✅
   - **Background Modes** ✅
     - [x] Remote notifications
     - [x] Background fetch
   - **Location When In Use** ✅

#### 3. Atualizar Info.plist

**Arquivo:** `ios/Runner/Info.plist`

**Verificar/adicionar permissões:**
```xml
<dict>
    <!-- ✅ App name -->
    <key>CFBundleName</key>
    <string>PedeJá</string>
    
    <key>CFBundleDisplayName</key>
    <string>PedeJá</string>
    
    <!-- ✅ Permissões com descrições em português -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Precisamos da sua localização para calcular o tempo de entrega e preencher seu endereço automaticamente.</string>
    
    <key>NSCameraUsageDescription</key>
    <string>Permite tirar foto do perfil.</string>
    
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Permite escolher foto do perfil da galeria.</string>
    
    <!-- ✅ Orientações suportadas (apenas retrato) -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
    
    <!-- ✅ Universal Links (deep links) -->
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>pedeja</string>
            </array>
        </dict>
    </array>
</dict>
```

#### 4. Configurar Firebase para iOS

**Verificar arquivo:** `ios/Runner/GoogleService-Info.plist`

**Se não existir, baixar do Firebase Console:**
1. Firebase Console → Configurações do projeto
2. Seus apps → iOS → Baixar GoogleService-Info.plist
3. Arrastar para `ios/Runner/` no Xcode

#### 5. Gerar Ícones e Launch Screen

**Ícones necessários:**
- 1024x1024px para App Store (sem transparência)
- Múltiplos tamanhos gerados automaticamente

**Usando flutter_launcher_icons:**
```powershell
# Já configurado no pubspec.yaml
flutter pub run flutter_launcher_icons
```

**Launch Screen (Splash):**

**Arquivo:** `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

- Adicionar logo 3x (ex: 300x300px)
- Cor de fundo: #E39110 (laranja)

**⚠️ iOS não suporta vídeo em splash nativo!** Mostrará logo estática.

#### 6. Build de Produção

**No terminal:**
```bash
# Limpar builds anteriores
flutter clean

# Instalar dependências
flutter pub get

# Gerar pods do iOS (CocoaPods)
cd ios
pod install
cd ..

# Build de release (necessário Mac!)
flutter build ios --release
```

**OU via Xcode:**

1. Xcode → Product → Scheme → Runner
2. Product → Destination → Any iOS Device
3. Product → Archive
4. Aguardar build (~5-15 minutos)

**Arquivo gerado:**
- **IPA:** `build/ios/iphoneos/Runner.app` (dentro do archive)

#### 7. Preparar Recursos Visuais

**Screenshots necessários (por tipo de dispositivo):**

**iPhone 6.7" (iPhone 15 Pro Max, 14 Pro Max):**
- Resolução: 1290 x 2796 pixels
- Quantidade: 3-10 screenshots

**iPhone 6.5" (iPhone 11 Pro Max, XS Max):**
- Resolução: 1242 x 2688 pixels
- Quantidade: 3-10 screenshots

**iPhone 5.5" (iPhone 8 Plus):**
- Resolução: 1242 x 2208 pixels
- Quantidade: 3-10 screenshots

**⚠️ MÍNIMO:** Screenshots para 6.7" e 5.5"

**Como capturar screenshots no iOS Simulator:**
```bash
# Executar no simulador
flutter run -d "iPhone 15 Pro Max"

# No simulador: Cmd + S para capturar tela
# Ou: xcrun simctl io booted screenshot screenshot.png
```

**Ícone do app:**
- 1024x1024px (obrigatório)
- Formato: PNG
- Sem cantos arredondados (iOS adiciona automaticamente)
- Sem transparência

#### 8. Criar Conta no App Store Connect

**URL:** https://appstoreconnect.apple.com

**Passos:**
1. ✅ Entrar com Apple ID
2. ✅ Criar conta Apple Developer ($99/ano)
3. ✅ Aceitar termos e condições
4. ✅ Preencher informações da empresa/pessoa física
5. ✅ Configurar Agreements, Tax, and Banking (para vendas in-app)

#### 9. Criar Novo App no App Store Connect

**App Store Connect → My Apps → + (Novo App):**

**Informações:**
- **Platform:** iOS
- **Name:** PedeJá - Delivery de Comida
- **Primary Language:** Portuguese (Brazil)
- **Bundle ID:** com.pedeja.app (selecionar da lista)
- **SKU:** PEDEJA001 (identificador único interno)
- **User Access:** Full Access

#### 10. Preencher Informações do App

**App Store Connect → App Information:**

**Categoria:**
- **Primary:** Food & Drink
- **Secondary:** Lifestyle

**Classificação de conteúdo:**

Questionário:
- Cartoon ou violence realista: Não
- Conteúdo realista: Não
- Profanidade ou humor grosseiro: Não
- Referências sexuais ou nudez: Não
- Álcool, tabaco ou drogas: Infrequent/Mild (permite delivery de bebidas)
- Temas médicos/tratamento: Não
- Horror/medo: Não
- Simulação de apostas: Não
- Violência realista prolongada: Não
- Referências sexuais ou nudez: Não

**Classificação esperada:** 12+ (devido a álcool)

**Descrição:**

**Subtítulo (30 caracteres):**
```
Delivery rápido e fácil
```

**Descrição promocional (170 caracteres):**
```
🍕 Delivery de comida, bebidas e farmácia direto na sua casa! Peça agora com o PedeJá e receba rápido com acompanhamento em tempo real. 🚀
```

**Descrição (4000 caracteres máx):**
```
🍕 PedeJá - Delivery Rápido na Palma da Sua Mão!

Peça comida, bebidas e produtos de farmácia com facilidade e segurança. O PedeJá conecta você aos melhores restaurantes e lojas da sua região!

✨ RECURSOS PRINCIPAIS

🍔 Variedade de Restaurantes
• Milhares de opções: pizza, hambúrguer, japonês, lanches, sobremesas
• Filtros inteligentes por categoria e preço
• Promoções exclusivas

🚀 Entrega Rápida
• Acompanhamento em tempo real
• Notificações instantâneas
• Chat direto com o estabelecimento
• Tempo estimado preciso

💰 Pagamento Seguro
• Cartão, Pix ou dinheiro
• Sistema criptografado
• Histórico completo

📍 Localização Inteligente
• Preenchimento automático via GPS
• Múltiplos endereços salvos

💊 Farmácia 24h
• Delivery de medicamentos
• Atendimento rápido

🎉 VANTAGENS

✓ Interface moderna
✓ Pedido em poucos cliques
✓ Cupons exclusivos
✓ Avaliações verificadas
✓ Sem taxa em restaurantes participantes

📱 COMO FUNCIONA

1. Escolha seu restaurante
2. Monte seu pedido
3. Personalize como quiser
4. Escolha pagamento
5. Confirme endereço
6. Acompanhe em tempo real
7. Receba e aproveite!

🔒 SEGURANÇA

• Criptografia de ponta
• Conformidade com LGPD
• Transações via Mercado Pago
• Dados protegidos

📞 SUPORTE

suporte@pedeja.com.br
WhatsApp: (91) 9999-9999
Chat 24/7 no app

🎁 BAIXE AGORA

• R$ 15 OFF no primeiro pedido
• Frete grátis acima de R$ 30
• Promoções exclusivas

#PedeJá #Delivery #Comida #FoodDelivery
```

**Keywords (100 caracteres):**
```
delivery,comida,restaurante,pedido,entrega,food,pizza,lanche,bebida,farmacia
```

**Support URL:** https://pedeja.com.br/support  
**Marketing URL:** https://pedeja.com.br  
**Privacy Policy URL:** https://pedeja.com.br/privacy-policy

#### 11. Adicionar Screenshots e Mídias

**App Store Connect → App Preview and Screenshots:**

**Upload screenshots para cada tamanho:**
- iPhone 6.7" Display: 3-10 imagens
- iPhone 6.5" Display: 3-10 imagens
- iPhone 5.5" Display: 3-10 imagens

**Opcional:**
- App Preview (vídeo de 15-30s mostrando o app)

#### 12. Configurar Versão para Revisão

**App Store Connect → 1.0 Prepare for Submission:**

**Notas da versão:**
```
🎉 Lançamento Inicial - Versão 1.0.0

Bem-vindo ao PedeJá!

✅ Catálogo completo de restaurantes
✅ Carrinho de compras otimizado
✅ Pagamento seguro (Mercado Pago)
✅ Pagamento em dinheiro
✅ Acompanhamento em tempo real
✅ Chat instantâneo
✅ Notificações de status
✅ GPS automático
✅ Vídeos promocionais
✅ Busca avançada
✅ Histórico de pedidos

Obrigado por usar o PedeJá! 🍕🚀
```

#### 13. Upload do Build

**Opção A: Via Xcode (recomendado)**

1. Xcode → Window → Organizer
2. Selecionar archive mais recente
3. Clicar em "Distribute App"
4. Selecionar "App Store Connect"
5. Selecionar "Upload"
6. Aguardar validação (~5-30 minutos)

**Opção B: Via Application Loader**

1. Exportar IPA do Xcode
2. Abrir Application Loader (Xcode → Open Developer Tool)
3. Fazer upload do IPA

**Verificar upload:**
- App Store Connect → TestFlight → Builds
- Aguardar "Processing" → "Ready to Submit"
- Tempo: 10-60 minutos

#### 14. Preencher Informações de Teste

**App Store Connect → App Review Information:**

**Contato:**
- First Name: [Seu nome]
- Last Name: [Seu sobrenome]
- Phone: [Telefone com DDD]
- Email: suporte@pedeja.com.br

**Credenciais de teste (obrigatório!):**
```
Email: teste@pedeja.com.br
Senha: TestePedeja2025!

Instruções:
1. Faça login com as credenciais acima
2. Navegue para a página inicial
3. Selecione um restaurante
4. Adicione produtos ao carrinho
5. Finalize o pedido (use pagamento em dinheiro para teste)
6. Acompanhe o status do pedido em tempo real
```

**Notas para revisão:**
```
Obrigado por revisar o PedeJá!

IMPORTANTE:
- Use as credenciais de teste fornecidas
- Backend e Firebase estão em produção
- Pagamento via Mercado Pago está ativo (modo produção)
- Para testar sem pagamento real, use "Dinheiro" como forma de pagamento
- Chat funciona em tempo real via Pusher
- Notificações requerem permissão do usuário

Se tiver dúvidas, contate: suporte@pedeja.com.br
```

#### 15. Enviar para Revisão

**Checklist final:**
- [x] Build carregado e processado
- [x] Screenshots adicionados (3 tamanhos mínimos)
- [x] Ícone 1024x1024 adicionado
- [x] Descrição completa
- [x] Classificação de conteúdo
- [x] Política de privacidade
- [x] Credenciais de teste
- [x] Informações de contato

**Clicar em:** "Submit for Review"

**Tempo de revisão:** 1-7 dias (média 24-72 horas)

**Status:**
1. Waiting for Review
2. In Review (1-24 horas)
3. Pending Developer Release (aprovado!)
4. Ready for Sale (publicado!)

---

## 📊 Comparação de Processos

| Aspecto | Google Play | Apple App Store |
|---------|-------------|----------------|
| **Custo** | R$ 150 (único) | US$ 99/ano |
| **Tempo de revisão** | 1-2 dias | 2-7 dias |
| **Aprovação** | ~90% no primeiro envio | ~60% no primeiro envio |
| **Processo** | Mais simples | Mais rigoroso |
| **Requisitos** | Windows/Mac/Linux | Apenas Mac |
| **Atualizações** | Rápidas (horas) | Moderadas (1-3 dias) |
| **Política** | Menos restritiva | Muito restritiva |
| **Distribuição** | AAB/APK | IPA via Xcode |

---

## ⚠️ Problemas Comuns e Soluções

### Google Play

**❌ Erro: "Upload failed: Invalid package"**
- ✅ Verificar applicationId único
- ✅ Verificar assinatura com keystore de release
- ✅ Regenerar AAB com `flutter build appbundle --release`

**❌ Erro: "Política de privacidade ausente"**
- ✅ Adicionar URL válida em Play Console → Ficha da loja

**❌ Erro: "Classificação de conteúdo incompleta"**
- ✅ Preencher questionário completo em Classificação de conteúdo

**❌ Rejeição: "Violação de permissões"**
- ✅ Justificar cada permissão no AndroidManifest
- ✅ Remover permissões não utilizadas

### Apple App Store

**❌ Erro: "Invalid Bundle"**
- ✅ Verificar Bundle ID único em Xcode
- ✅ Verificar Signing com certificado de distribuição
- ✅ Rebuild com Xcode → Product → Archive

**❌ Erro: "Missing compliance"**
- ✅ Preencher questionário de criptografia (Export Compliance)
- ✅ Se usar HTTPS apenas, responder "No" para criptografia customizada

**❌ Rejeição: "Guideline 2.1 - Performance - App Completeness"**
- ✅ Fornecer credenciais de teste funcionais
- ✅ Testar login antes de submeter
- ✅ Verificar backend em produção

**❌ Rejeição: "Guideline 4.0 - Design"**
- ✅ Interface deve ser nativa do iOS (não webview)
- ✅ Splash screen não deve parecer propaganda
- ✅ Ícone deve seguir design guidelines da Apple

**❌ Rejeição: "Guideline 5.1.1 - Legal - Privacy"**
- ✅ Adicionar política de privacidade válida
- ✅ Explicar uso de localização, câmera, notificações
- ✅ Permitir usuário deletar conta

---

## 📅 Timeline Estimado

### Google Play Store
- **Dia 1:** Preparar build, keystore, recursos visuais
- **Dia 2:** Criar conta Play Console, preencher informações
- **Dia 3:** Upload AAB, enviar para revisão
- **Dias 4-5:** Aguardar aprovação
- **Dia 6:** **APP PUBLICADO! 🎉**

**Total:** 5-7 dias

### Apple App Store
- **Dia 1:** Configurar Xcode, certificados, provisioning
- **Dia 2:** Build IPA, preparar recursos visuais
- **Dia 3:** Criar conta App Store Connect, preencher informações
- **Dia 4:** Upload via Xcode, aguardar processing
- **Dia 5:** Preencher credenciais de teste, enviar para revisão
- **Dias 6-12:** Aguardar aprovação
- **Dia 13:** **APP PUBLICADO! 🎉**

**Total:** 10-14 dias

---

## 🎯 Checklist Final

### Antes de Submeter

**Geral:**
- [ ] Testar app em dispositivo físico
- [ ] Testar todas as funcionalidades (login, pedido, pagamento, chat, GPS)
- [ ] Verificar que backend está em produção
- [ ] Confirmar Firebase configurado
- [ ] Confirmar Mercado Pago em modo produção
- [ ] Testar notificações push
- [ ] Verificar performance (sem crashes)

**Google Play:**
- [ ] AAB gerado com assinatura de release
- [ ] Screenshots preparados (5-8 imagens)
- [ ] Ícone 512x512px pronto
- [ ] Descrição completa escrita
- [ ] Política de privacidade publicada
- [ ] Conta Google Play Console ativa

**Apple App Store:**
- [ ] IPA compilado no Mac com Xcode
- [ ] Screenshots para 3 tamanhos de tela
- [ ] Ícone 1024x1024px sem transparência
- [ ] Descrição completa escrita
- [ ] Credenciais de teste criadas e testadas
- [ ] Política de privacidade publicada
- [ ] Conta Apple Developer ativa ($99/ano pago)

---

## 🚀 Pós-Lançamento

### Monitoramento

**Google Play Console:**
- Acessar diariamente para ver downloads
- Responder avaliações de usuários
- Monitorar crashes via Android Vitals
- Acompanhar estatísticas de instalação

**App Store Connect:**
- Acessar semanalmente para ver downloads
- Responder avaliações de usuários
- Monitorar crashes via Xcode Organizer
- Acompanhar Analytics

### Atualizações

**Quando atualizar:**
- Bugs críticos: atualizar em 1-2 dias
- Novos recursos: atualizar mensalmente
- Melhorias de performance: atualizar quando acumular várias

**Processo de atualização:**

**Google Play:**
1. Incrementar `versionCode` e `versionName` em `android/app/build.gradle.kts`
2. `flutter build appbundle --release`
3. Play Console → Produção → Criar nova versão
4. Upload novo AAB
5. Escrever notas da versão
6. Enviar para revisão (1-2 dias)

**Apple App Store:**
1. Incrementar Version e Build em Xcode
2. `flutter build ios --release`
3. Xcode → Product → Archive → Upload
4. App Store Connect → Nova versão
5. Escrever notas da versão
6. Enviar para revisão (2-5 dias)

---

## 📞 Suporte e Recursos

### Documentação Oficial

**Flutter:**
- Build e Deploy: https://docs.flutter.dev/deployment
- Android: https://docs.flutter.dev/deployment/android
- iOS: https://docs.flutter.dev/deployment/ios

**Google Play:**
- Play Console Help: https://support.google.com/googleplay/android-developer
- Políticas do desenvolvedor: https://play.google.com/about/developer-content-policy/

**Apple:**
- App Store Connect: https://developer.apple.com/app-store-connect/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/

### Comunidades

- Flutter Brasil: https://t.me/flutterbrasil
- Stack Overflow: flutter tag
- Reddit: r/FlutterDev

---

## ✅ Conclusão

Seguindo este guia completo, você terá o PedeJá publicado em ambas as lojas com sucesso! 

**Resumo:**
1. ✅ **Google Play:** Processo mais rápido (5-7 dias), menos restritivo, custo único
2. ✅ **Apple App Store:** Processo mais longo (10-14 dias), mais rigoroso, custo anual

**Prioridade recomendada:**
1. Lançar primeiro no **Google Play** (processo mais simples)
2. Usar feedback dos usuários Android para melhorar
3. Lançar depois no **App Store** (processo mais rigoroso, menor chance de rejeição)

**BOA SORTE COM O LANÇAMENTO! 🚀🎉**

---

*Guia criado em Novembro 2025 - PedeJá v1.0.0*
