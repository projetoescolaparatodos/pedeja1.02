# 📱 Instruções para Build iOS - v1.0.17+18

## ✅ Versão Atual
- **Versão**: 1.0.17+18
- **Build Number**: 18
- **Commit**: c12fb03

## 🔧 Correções desta Versão

### 1. **Fix Logout no iPhone** 🍎
- **Problema**: App fechava ao invés de fazer logout
- **Causa**: Race condition com delays do iOS no signOut()
- **Solução**: Navega para LoginPage ANTES de executar signOut() em background
- **Código**: `lib/pages/home/home_page.dart` linha ~1808

### 2. **Mensagens de Erro Amigáveis** 📡
- **Antes**: "ClientException with SocketException: Failed host lookup..."
- **Depois**: "Sem conexão com a internet"
- **Arquivos**: `lib/providers/catalog_provider.dart`

### 3. **Chat Protegido** 💬
- **Problema**: NullPointerException no Pusher
- **Solução**: Verificação `if (!mounted)` antes de setState
- **Mensagens simplificadas**: "Erro no chat. Tente novamente."
- **Arquivo**: `lib/pages/orders/order_details_page.dart`

---

## 🚀 Como Fazer Build para iOS

### Pré-requisitos
- ✅ macOS (Big Sur ou superior)
- ✅ Xcode 14.0+
- ✅ CocoaPods instalado
- ✅ Certificados da Apple Developer configurados

### Passo 1: Preparar Ambiente
```bash
cd /caminho/para/pedeja1.02

# Limpar builds anteriores
flutter clean

# Atualizar dependências
flutter pub get

# Instalar pods do iOS
cd ios
pod install
cd ..
```

### Passo 2: Abrir no Xcode
```bash
open ios/Runner.xcworkspace
```

### Passo 3: Configurar no Xcode
1. **Selecionar Target**: Runner
2. **General Tab**:
   - Display Name: `PedeJá`
   - Bundle Identifier: `com.pedeja.app`
   - Version: `1.0.17`
   - Build: `18`

3. **Signing & Capabilities**:
   - Team: Selecionar sua conta Apple Developer
   - Signing Certificate: Apple Distribution
   - Provisioning Profile: App Store

4. **Verificar Bundle ID** em todos os alvos:
   - Runner
   - RunnerTests (se existir)

### Passo 4: Build via Flutter
```bash
# Build para Archive (App Store)
flutter build ios --release

# OU Build direto no Xcode:
# Product > Archive
```

### Passo 5: Archive e Upload
1. No Xcode: **Product** > **Archive**
2. Aguardar build completar
3. Window > Organizer
4. Selecionar o archive
5. **Distribute App**
6. **App Store Connect**
7. **Upload**
8. Aguardar processamento (~10-30 min)

### Passo 6: TestFlight
1. Acessar [App Store Connect](https://appstoreconnect.apple.com)
2. Ir para app PedeJá
3. TestFlight > iOS builds
4. Adicionar "What's New":
   ```
   Versão 1.0.17
   
   ✅ Corrigido: Logout agora funciona corretamente no iPhone
   ✅ Melhorado: Mensagens de erro mais claras
   ✅ Corrigido: Estabilidade do chat
   ```
5. Salvar e enviar para revisão

---

## 📝 Notas Importantes

### GoogleService-Info.plist
- **Localização**: `ios/Runner/GoogleService-Info.plist`
- **Bundle ID**: Deve ser `com.pedeja.app`
- **Verificar**: `BUNDLE_ID` e `REVERSED_CLIENT_ID`

### Info.plist Permissions
Verificar se tem todas as permissões:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para encontrar restaurantes próximos</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para rastrear entregas</string>

<key>NSCameraUsageDescription</key>
<string>Precisamos da câmera para escanear QR codes</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Precisamos acessar suas fotos para atualizar seu perfil</string>
```

### Podfile
Versão mínima do iOS deve ser >= 13.0:
```ruby
platform :ios, '13.0'
```

---

## 🐛 Troubleshooting

### Erro: "Signing for requires a development team"
**Solução**: Configurar Team no Xcode (General > Signing)

### Erro: "The bundle identifier is invalid"
**Solução**: Verificar se Bundle ID é `com.pedeja.app` em todos os targets

### Erro: "Could not find GoogleService-Info.plist"
**Solução**:
```bash
cd ios/Runner
ls -la GoogleService-Info.plist
# Se não existir, baixar do Firebase Console
```

### Build demora muito
**Solução**:
```bash
# Limpar cache do Xcode
rm -rf ~/Library/Developer/Xcode/DerivedData

# Limpar pods
cd ios
pod deintegrate
pod install
```

### CocoaPods erros
**Solução**:
```bash
sudo gem install cocoapods
pod repo update
cd ios
pod install --repo-update
```

---

## ✅ Checklist Pré-Upload

- [ ] Versão atualizada (1.0.17+18)
- [ ] Build limpo (`flutter clean`)
- [ ] Certificados válidos
- [ ] GoogleService-Info.plist correto
- [ ] Permissions no Info.plist
- [ ] Testes no simulador OK
- [ ] Testes em device físico OK
- [ ] Archive gerado sem erros
- [ ] Upload para App Store Connect
- [ ] Build processado no TestFlight

---

## 📱 Testar Antes de Enviar

### Simulador
```bash
flutter run -d "iPhone 15 Pro"
```

### Device Físico
```bash
flutter run -d <DEVICE_ID>
```

### Testes Críticos
1. ✅ Login/Logout (TESTADO - CORRIGIDO)
2. ✅ Chat de pedido
3. ✅ Sem internet (mensagens amigáveis)
4. ✅ Detalhes do pedido
5. ✅ Notificações push
6. ✅ Geolocalização
7. ✅ Pagamento

---

## 📞 Suporte
- **GitHub**: https://github.com/projetoescolaparatodos/pedeja1.02
- **Commit atual**: c12fb03
- **Branch**: main
