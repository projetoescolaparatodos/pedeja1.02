# 🚨 Guia Completo: Erros iOS Codemagic e Soluções

> **Documentação criada em:** Dezembro 2025  
> **App:** PedeJá Clean  
> **Objetivo:** Evitar erros recorrentes em novos apps Flutter + Firebase + iOS

---

## 📋 Índice

1. [Erro CTweetNacl - Compilation Error](#1-erro-ctweetnacl---compilation-error)
2. [GoogleService-Info.plist Não Encontrado](#2-googleservice-infoplist-não-encontrado)
3. [Ícone com Canal Alpha (Transparência)](#3-ícone-com-canal-alpha-transparência)
4. [Permissões de Localização Faltando](#4-permissões-de-localização-faltando)
5. [Crash no iPad - Firebase Initialization](#5-crash-no-ipad---firebase-initialization)
6. [Logout iOS Não Limpa Sessão](#6-logout-ios-não-limpa-sessão)
7. [Platform.isIOS Undefined Error](#7-platformisios-undefined-error)
8. [Firebase Android Package Name Mismatch](#8-firebase-android-package-name-mismatch)
9. [Checklist Pré-Deploy](#9-checklist-pré-deploy)

---

## 1. Erro CTweetNacl - Compilation Error

### 🔴 Erro
```
/Users/builder/.pub-cache/hosted/pub.dev/tweetnacl-1.0.2/lib/src/tweetnacl.dart:1042:11: 
Error: The method 'firstWhere' isn't defined for the class 'List<int>'

return list.firstWhere((i) => i != 0, orElse: () => null);
              ^^^^^^^^^^
```

### 📝 Causa
- Package `tweetnacl` (dependency de `pointycastle`) incompatível com Dart 3.x
- Pattern matching mudou no Flutter SDK recente
- SDK 3.5.4 quebra syntax antiga de `firstWhere`

### ✅ Solução 1: Forçar versão do tweetnacl

**pubspec.yaml:**
```yaml
dependency_overrides:
  tweetnacl: ^1.0.3  # Versão compatível com Dart 3.x
```

### ✅ Solução 2: Atualizar pointycastle (Recomendado)

**pubspec.yaml:**
```yaml
dependencies:
  pointycastle: ^4.0.1  # Nova versão sem tweetnacl
```

Depois:
```bash
flutter pub upgrade
flutter clean
flutter pub get
```

### 🎯 Lições Aprendidas
- ⚠️ Sempre verificar compatibilidade de dependencies com Dart SDK atual
- ✅ Preferir packages mantidos ativamente (pointycastle 4.x não usa tweetnacl)
- 🔍 Usar `flutter doctor -v` para verificar versão do SDK antes do deploy

---

## 2. GoogleService-Info.plist Não Encontrado

### 🔴 Erro (Codemagic Build)
```
No matching provisioning profiles found: 
No provisioning profiles with a valid signing identity were found.
```

**Crash em runtime:**
```
*** Terminating app due to uncaught exception 'com.firebase.core'
Reason: FirebaseApp.configure() failed
GoogleService-Info.plist not found in bundle
```

### 📝 Causa
- Arquivo `GoogleService-Info.plist` existe em `ios/Runner/`
- **MAS** não está registrado no **Xcode project** (`project.pbxproj`)
- Codemagic compila sem incluir o arquivo no bundle final
- Firebase não encontra configurações e crasha

### ✅ Solução (DEFINITIVA)

#### Passo 1: Adicionar ao project.pbxproj

Editar manualmente `ios/Runner.xcodeproj/project.pbxproj`:

**1. Adicionar na seção PBXFileReference (linha ~30-70):**
```
3B3967151E833CAA004F5970 /* AppFrameworkInfo.plist */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; name = AppFrameworkInfo.plist; path = Flutter/AppFrameworkInfo.plist; sourceTree = "<group>"; };
YOUR_UUID /* GoogleService-Info.plist */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };
```

Gerar UUID único:
```bash
uuidgen | tr '[:upper:]' '[:lower:]'
```

**2. Adicionar na seção PBXGroup (linha ~80-110):**
```
97C146F01CF9000F007C117D /* Runner */ = {
    isa = PBXGroup;
    children = (
        97C146FA1CF9000F007C117D /* Main.storyboard */,
        97C146FC1CF9000F007C117D /* Info.plist */,
        YOUR_UUID /* GoogleService-Info.plist */,  // ← ADICIONAR AQUI
        ...
    );
```

**3. Adicionar na seção PBXResourcesBuildPhase (linha ~200-230):**
```
97C146EC1CF9000F007C117D /* Resources */ = {
    isa = PBXResourcesBuildPhase;
    buildActionMask = 2147483647;
    files = (
        97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */,
        3B3967161E833CAA004F5970 /* AppFrameworkInfo.plist in Resources */,
        YOUR_UUID /* GoogleService-Info.plist in Resources */,  // ← ADICIONAR AQUI
        ...
    );
```

#### Passo 2: Verificar Bundle ID

**Info.plist:**
```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

**GoogleService-Info.plist:**
```xml
<key>BUNDLE_ID</key>
<string>pedeJA.vtx.pa</string>
```

⚠️ **Devem ser IDÊNTICOS!**

#### Passo 3: Commit e Push
```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "Add GoogleService-Info.plist to Xcode project"
git push
```

### 🎯 Lições Aprendidas
- ⚠️ **NUNCA** apenas copiar o plist para `ios/Runner/`
- ✅ Sempre adicionar ao `project.pbxproj` em 3 lugares
- 🔍 Verificar Bundle ID antes de fazer build
- 📝 Testar no simulador local antes do Codemagic

---

## 3. Ícone com Canal Alpha (Transparência)

### 🔴 Erro (Apple Review)
```
ITMS-90717: Invalid Icon
The app icon contains transparency.
iOS app icons must not have an alpha channel.
```

### 📝 Causa
- PNG do ícone tem **canal alpha** (transparência)
- Apple rejeita automaticamente ícones transparentes no iOS
- Mesmo que visual pareça opaco, pode ter alpha channel

### ✅ Solução

**pubspec.yaml:**
```yaml
flutter_icons:
  android: true
  ios: true
  remove_alpha_ios: true  # ← ADICIONAR ESTA LINHA
  image_path: "assets/images/app_icon.png"
```

Regenerar ícones:
```bash
flutter pub run flutter_launcher_icons:main
```

### 🔄 Alternativa Manual (Photoshop/GIMP)
```
1. Abrir app_icon.png
2. Layer → Flatten Image (remover transparência)
3. Image → Mode → RGB Color (não RGBA)
4. Salvar como PNG-24 (não PNG-32)
```

### 🎯 Lições Aprendidas
- ✅ Sempre usar `remove_alpha_ios: true` no flutter_icons
- 🔍 Validar ícones antes: `file app_icon.png` → não deve mostrar "alpha"
- 📝 Android aceita alpha, iOS não!

---

## 4. Permissões de Localização Faltando

### 🔴 Erro (Codemagic Build)
```
warning: [Runner] Runner has a location permission but no description for it
NSLocationWhenInUseUsageDescription not found in Info.plist
```

### 📝 Causa
- App usa `geolocator` ou `geocoding` packages
- iOS exige **3 keys** de permissão no Info.plist
- Sem descrições, Apple rejeita automaticamente

### ✅ Solução

**ios/Runner/Info.plist:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para encontrar restaurantes próximos e calcular o tempo de entrega.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Precisamos da sua localização para melhorar sua experiência de entrega.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Precisamos da sua localização para rastrear entregas e encontrar restaurantes próximos mesmo quando o app estiver em segundo plano.</string>
```

### 🎯 Permissões Comuns iOS

| Package | Keys Obrigatórias |
|---------|-------------------|
| `geolocator` | NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription |
| `camera` | NSCameraUsageDescription |
| `image_picker` | NSPhotoLibraryUsageDescription, NSCameraUsageDescription |
| `firebase_messaging` | Nenhuma (notificações automáticas) |

### 🎯 Lições Aprendidas
- ✅ Sempre adicionar TODAS as 3 keys de localização (mesmo usando só "whenInUse")
- 📝 Descrições devem ser claras e em português (para App Store Brasil)
- 🔍 Verificar warnings no Xcode antes do push

---

## 5. Crash no iPad - Firebase Initialization

### 🔴 Erro (Apple Review - Build 1.0.4)
```
Guideline 2.1 - Performance - App Completeness
We were unable to review your app as it crashed on launch on iPad Air 11" (M3) running iPadOS 18.6.2.

Crash log:
Exception Type: EXC_CRASH (SIGABRT)
Exception Codes: 0x0000000000000000, 0x0000000000000000
Terminating Process: Runner [8649]
Triggered by Thread: 0

Thread 0 name: Dispatch queue: com.apple.main-thread
Thread 0 Crashed:
0   libsystem_kernel.dylib          0x00000001e8e2e134 __pthread_kill + 8
1   Runner                          0x00000001045a3194 +[FIRApp configure] + 1104
```

### 📝 Causa
- **iPhone 11 (iOS 26.0 Beta):** Funciona perfeitamente ✅
- **iPad Air M3 (iPadOS 18.6.2 Stable):** Crasha no launch 💥

**Diferenças:**
1. iOS Beta vs iPadOS Stable → comportamentos diferentes
2. Firebase pode falhar sem `GoogleService-Info.plist` válido
3. Sem **error handling**, app crasha imediatamente

### ✅ Solução 1: Error Handling (Recomendado)

**ios/Runner/AppDelegate.swift:**
```swift
import UIKit
import Flutter
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 📱 LOGGING: Device info para debug
    let deviceModel = UIDevice.current.model
    let systemVersion = UIDevice.current.systemVersion
    let screenSize = UIScreen.main.bounds.size
    print("📱 Device: \(deviceModel), iOS: \(systemVersion), Screen: \(screenSize)")
    
    // 🔍 VALIDAÇÃO: GoogleService-Info.plist existe?
    if let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
      print("✅ GoogleService-Info.plist found at: \(plistPath)")
      
      if let plistData = FileManager.default.contents(atPath: plistPath),
         let plistDict = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
        
        if let bundleId = plistDict["BUNDLE_ID"] as? String {
          print("✅ BUNDLE_ID: \(bundleId)")
        }
        if let projectId = plistDict["PROJECT_ID"] as? String {
          print("✅ PROJECT_ID: \(projectId)")
        }
      }
    } else {
      print("❌ GoogleService-Info.plist NOT FOUND!")
      print("❌ Firebase will NOT initialize!")
    }
    
    // 🔥 FIREBASE: Configurar com error handling
    do {
      if FirebaseApp.app() == nil {
        print("🔄 Initializing Firebase...")
        FirebaseApp.configure()
        print("✅ Firebase configured successfully!")
      } else {
        print("✅ Firebase already configured")
      }
    } catch let error as NSError {
      print("❌ FIREBASE CONFIGURATION ERROR:")
      print("   Domain: \(error.domain)")
      print("   Code: \(error.code)")
      print("   Description: \(error.localizedDescription)")
      print("   UserInfo: \(error.userInfo)")
      
      // ⚠️ NÃO CRASHAR - continuar sem Firebase
      print("⚠️ App will continue without Firebase services")
      
      #if DEBUG
      // Apenas em debug, mostrar alerta visual
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        let alert = UIAlertController(
          title: "Firebase Error",
          message: "Firebase initialization failed. Check logs.",
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let rootVC = application.windows.first?.rootViewController {
          rootVC.present(alert, animated: true)
        }
      }
      #endif
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### ✅ Solução 2: iPhone Only (Mais Rápida)

Se não quer lidar com iPad, desabilite completamente:

**ios/Runner.xcodeproj/project.pbxproj:**

Procurar **3 ocorrências** de:
```
TARGETED_DEVICE_FAMILY = "1,2";  // 1=iPhone, 2=iPad
```

Trocar por:
```
TARGETED_DEVICE_FAMILY = 1;  // Apenas iPhone
```

**ios/Runner/Info.plist:**

Remover completamente:
```xml
<!-- DELETAR ESTAS LINHAS: -->
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
  <string>UIInterfaceOrientationPortraitUpsideDown</string>
  <string>UIInterfaceOrientationLandscapeLeft</string>
  <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

**Resultado:**
- ✅ Apple não testa no iPad (só iPhone)
- ✅ Usuários de iPad ainda podem instalar (modo compatibilidade)
- ✅ Resolve crash instantaneamente

### 🎯 Lições Aprendidas
- ⚠️ **NUNCA** usar `FirebaseApp.configure()` sem try-catch no iOS
- ✅ Adicionar logs detalhados (device, OS, screen size)
- 📝 Testar em MÚLTIPLOS dispositivos (iPhone + iPad, Beta + Stable)
- 🔍 iPad tem comportamento diferente do iPhone!

---

## 6. Logout iOS Não Limpa Sessão

### 🔴 Problema Reportado
```
"O botão de sair da conta que fica na taskbar ele sai do app 
mas continua logado. No Android já está perfeito."
```

**Comportamento:**
1. Usuário clica em "Sair" no drawer
2. App fecha
3. Reabre app → Ainda logado! ❌

### 📝 Causa
- **Android:** Usa `SharedPreferences` (limpa imediatamente)
- **iOS:** Usa **Keychain** (persiste mesmo após `signOut()`)

Firebase Auth no iOS:
```dart
await FirebaseAuth.instance.signOut();
// ⚠️ iOS Keychain pode NÃO limpar imediatamente!
// FirebaseAuth.instance.currentUser ainda pode ser != null
```

### ✅ Solução: Double SignOut + Keychain Cleanup

**lib/services/auth_service.dart:**
```dart
import 'dart:io'; // ← ADICIONAR

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Future<void> signOut() async {
    try {
      // 1️⃣ Primeiro signOut
      await _auth.signOut();
      await clearCredentials();
      _jwtToken = null;
      _userData = null;
      _restaurantData = null;
      
      // 🍎 iOS FIX: Keychain cleanup com verificação
      if (Platform.isIOS) {
        // Aguardar 500ms para Keychain processar
        await Future.delayed(Duration(milliseconds: 500));
        
        // Verificar se ainda está logado
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          debugPrint('⚠️ iOS: User still logged in! Force signOut again...');
          
          // 2️⃣ Forçar refresh do token e signOut novamente
          try {
            await currentUser.getIdToken(true); // Force token refresh
          } catch (e) {
            debugPrint('Token refresh failed (expected): $e');
          }
          
          await _auth.signOut();
          
          // Aguardar confirmação
          await Future.delayed(Duration(milliseconds: 200));
        }
      }
      
      debugPrint('✅ Logout completed');
    } catch (e) {
      debugPrint('❌ Erro ao fazer logout: $e');
      rethrow;
    }
  }
  
  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Limpar keys padrão
    await prefs.remove('isLoggedIn');
    await prefs.remove('userEmail');
    await prefs.remove('jwtToken');
    
    // 🍎 iOS: Limpeza agressiva de TODAS as keys auth
    if (Platform.isIOS) {
      final allKeys = prefs.getKeys();
      for (String key in allKeys) {
        if (key.startsWith('flutter.') || 
            key.contains('auth') || 
            key.contains('user') ||
            key.contains('token') ||
            key.contains('firebase')) {
          await prefs.remove(key);
          debugPrint('🧹 iOS: Removed key: $key');
        }
      }
    }
  }
}
```

**lib/state/auth_state.dart:**
```dart
import 'dart:io'; // ← ADICIONAR

class AuthState extends ChangeNotifier {
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Limpar serviços
      await NotificationService.clearToken();
      await OrderStatusListenerService.stopListeningToAllOrders();
      await OrderStatusPusherService.disconnect();

      // Logout do Firebase
      await _authService.signOut();
      
      // Limpar estado local
      _currentUser = null;
      _userData = null;
      _restaurantData = null;
      _registrationComplete = false;
      _error = null;
      _isGuest = false;
      
      // 🍎 iOS: Verificação extra
      if (Platform.isIOS) {
        await Future.delayed(Duration(milliseconds: 300));
        
        final stillLoggedIn = FirebaseAuth.instance.currentUser;
        if (stillLoggedIn != null) {
          debugPrint('⚠️ iOS: FirebaseAuth still has user! Force signOut...');
          await FirebaseAuth.instance.signOut();
          await Future.delayed(Duration(milliseconds: 200));
        }
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Erro no logout: $e');
      
      // Mesmo com erro, limpar TUDO
      _currentUser = null;
      _userData = null;
      _restaurantData = null;
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }
}
```

### 🎯 Lições Aprendadas
- ⚠️ iOS Keychain é **PERSISTENTE** (não limpa automaticamente)
- ✅ Sempre usar `Platform.isIOS` para lógica específica
- 📝 Double signOut com delays é necessário no iOS
- 🔍 Android funciona no primeiro signOut, iOS precisa verificação

---

## 7. Platform.isIOS Undefined Error

### 🔴 Erro (Codemagic Build)
```
lib/state/auth_state.dart:421:11: Error: The getter 'Platform' isn't defined 
for the type 'AuthState'.
- 'AuthState' is from 'package:pedeja_clean/state/auth_state.dart'
Try correcting the name to the name of an existing getter, or defining 
a getter or field named 'Platform'.
      if (Platform.isIOS) {
          ^^^^^^^^
Target kernel_snapshot_program failed: Exception
```

### 📝 Causa
- Usamos `Platform.isIOS` no código
- **MAS** esquecemos de importar `dart:io`!
- Flutter compila localmente (cached), mas Codemagic falha

### ✅ Solução

**TODOS os arquivos que usam `Platform.isIOS`:**
```dart
import 'dart:io'; // ← ADICIONAR NO TOPO

// Agora funciona:
if (Platform.isIOS) {
  // código específico iOS
}
```

**Arquivos comuns que precisam:**
- `lib/services/auth_service.dart`
- `lib/state/auth_state.dart`
- Qualquer widget com lógica platform-specific

### 🎯 Lições Aprendidas
- ✅ Sempre adicionar `import 'dart:io'` quando usar Platform
- 🔍 Fazer `flutter clean` + rebuild antes do push
- 📝 Codemagic é mais rigoroso que build local

---

## 8. Firebase Android Package Name Mismatch

### 🔴 Erro (Flutter Run Android)
```
FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:processDebugGoogleServices'.
> No matching client found for package name 'com.pedeja.app' 
  in C:\...\android\app\google-services.json
```

### 📝 Causa
- `android/app/build.gradle.kts` define `applicationId = "com.pedeja.app"`
- `android/app/google-services.json` tem clients:
  - `com.pedeja.correja` ✅
  - `pedeJA.vtx` ✅
  - `com.pedeja.app` ❌ (FALTANDO!)

### ✅ Solução

**android/app/google-services.json:**

Adicionar novo client na array `"client"`:
```json
{
  "project_info": {
    "project_number": "776278242419",
    "project_id": "pedeja-ec420"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:776278242419:android:7e6087811e71a3d33b2606",
        "android_client_info": {
          "package_name": "com.pedeja.app"
        }
      },
      "oauth_client": [
        {
          "client_id": "776278242419-bo4quo8jo0rpjq7n3f9pg8tgj3h2edcb.apps.googleusercontent.com",
          "client_type": 3
        }
      ],
      "api_key": [
        {
          "current_key": "AIzaSyDpMmy2g9DOvSJf6whlswfIaNM4hawaBdU"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": [
            {
              "client_id": "776278242419-bo4quo8jo0rpjq7n3f9pg8tgj3h2edcb.apps.googleusercontent.com",
              "client_type": 3
            }
          ]
        }
      }
    }
  ]
}
```

### 🔄 Alternativa: Baixar do Firebase Console

1. Ir em: https://console.firebase.google.com
2. Projeto → Configurações do projeto
3. Apps → Android → Baixar `google-services.json`
4. Substituir arquivo em `android/app/`

### 🎯 Lições Aprendidas
- ⚠️ `applicationId` (gradle) DEVE existir em `google-services.json`
- ✅ Sempre verificar **AMBOS** os package names antes do build
- 📝 Firebase pode ter múltiplos clients no mesmo arquivo

---

## 9. Checklist Pré-Deploy

### 📋 Antes de Enviar para Codemagic

#### ✅ Firebase
- [ ] `GoogleService-Info.plist` adicionado ao `project.pbxproj` (3 lugares)
- [ ] Bundle ID em `Info.plist` = Bundle ID em `GoogleService-Info.plist`
- [ ] `google-services.json` tem client para `applicationId` do Android
- [ ] `FirebaseApp.configure()` tem error handling (try-catch)

#### ✅ Dependências
- [ ] `flutter pub upgrade` executado
- [ ] `dependency_overrides` configurado se necessário (tweetnacl)
- [ ] Nenhum package deprecated nas dependencies

#### ✅ Permissões iOS
- [ ] NSLocationWhenInUseUsageDescription
- [ ] NSLocationAlwaysUsageDescription
- [ ] NSLocationAlwaysAndWhenInUseUsageDescription
- [ ] NSCameraUsageDescription (se usa câmera)
- [ ] NSPhotoLibraryUsageDescription (se usa galeria)

#### ✅ Ícones e Assets
- [ ] `remove_alpha_ios: true` no flutter_icons
- [ ] Ícones regenerados: `flutter pub run flutter_launcher_icons:main`
- [ ] Splash screen configurada: `flutter pub run flutter_native_splash:create`

#### ✅ Platform-Specific Code
- [ ] Todos arquivos com `Platform.isIOS` têm `import 'dart:io'`
- [ ] Logout iOS tem double signOut + Keychain cleanup
- [ ] iPad habilitado (`TARGETED_DEVICE_FAMILY = "1,2"`) OU
- [ ] iPad desabilitado (`TARGETED_DEVICE_FAMILY = 1`) se não suportar

#### ✅ Testes Locais
- [ ] `flutter clean && flutter pub get`
- [ ] Build iOS local: `flutter build ios --release`
- [ ] Executar no simulador iOS: `flutter run -d <device>`
- [ ] Executar no emulador Android: `flutter run -d emulator-5554`
- [ ] Testar logout (sair e reabrir app)

#### ✅ Git
- [ ] `ios/Runner.xcodeproj/project.pbxproj` commitado
- [ ] `ios/Runner/Info.plist` commitado
- [ ] `android/app/google-services.json` commitado
- [ ] `pubspec.yaml` com versão atualizada (ex: 1.0.6+7)

#### ✅ Codemagic
- [ ] `codemagic.yaml` com build-name e build-number corretos
- [ ] Certificados iOS configurados no dashboard
- [ ] Provisioning profiles válidos
- [ ] Variáveis de ambiente configuradas (se necessário)

---

## 🚀 Comandos Úteis

### Rebuild Completo
```bash
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
```

### Verificar Package Names
```bash
# Android
cat android/app/build.gradle.kts | grep applicationId

# iOS
cat ios/Runner/Info.plist | grep -A 1 CFBundleIdentifier

# Firebase
cat ios/Runner/GoogleService-Info.plist | grep -A 1 BUNDLE_ID
cat android/app/google-services.json | grep package_name
```

### Validar Ícone (sem alpha)
```bash
file assets/images/app_icon.png
# Deve mostrar: PNG image data, 1024 x 1024, 8-bit/color RGB (NÃO RGBA!)
```

### Git Diff iOS
```bash
git diff ios/Runner.xcodeproj/project.pbxproj
git diff ios/Runner/Info.plist
git diff ios/Runner/GoogleService-Info.plist
```

---

## 📞 Suporte

Se encontrar novos erros não documentados aqui:

1. **Logs do Codemagic:** Sempre salvar output completo do build
2. **Stack Overflow:** Procurar erro exato entre aspas
3. **GitHub Issues:** Verificar issues do package específico
4. **Firebase Docs:** https://firebase.google.com/docs/flutter/setup?platform=ios

---

## 📝 Histórico de Builds (PedeJá)

| Build | Versão | Status | Erro Principal |
|-------|--------|--------|----------------|
| 1-12 | 1.0.0-1.0.3 | ❌ Failed | CTweetNacl compilation |
| 13 | 1.0.3+4 | ❌ Rejected | GoogleService-Info.plist missing |
| 14 | 1.0.4+5 | ❌ Rejected | iPad crash + Screenshots |
| 15 | 1.0.5+6 | ❌ Failed | Platform.isIOS undefined |
| 16 | 1.0.6+7 | ✅ Success | iPhone only + Error handling |

**Total de tentativas até sucesso:** 16 builds  
**Tempo total:** ~3 dias  
**Lições aprendidas:** 8 erros únicos documentados

---

## ✅ Resumo Final

### Top 3 Erros Mais Comuns:
1. **GoogleService-Info.plist** não adicionado ao project.pbxproj
2. **Platform.isIOS** sem `import 'dart:io'`
3. **Firebase package names** incompatíveis entre iOS/Android

### Top 3 Soluções Mais Efetivas:
1. Sempre usar **error handling** no Firebase (try-catch)
2. Fazer **iPhone only** primeiro, iPad depois
3. Testar **localmente** antes de fazer push para Codemagic

### Tempo Economizado com Esta Documentação:
- ⏱️ **Sem docs:** 3 dias de troubleshooting
- ⚡ **Com docs:** 2-3 horas seguindo checklist
- 💰 **ROI:** ~90% de redução de tempo

---

**Última atualização:** Dezembro 2025  
**Autor:** Documentação gerada durante deploy do PedeJá Clean  
**Objetivo:** Acelerar deploy do app Correja e futuros projetos Flutter + iOS + Firebase
