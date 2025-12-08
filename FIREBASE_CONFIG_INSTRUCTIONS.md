# 🔥 Instruções: Configuração Firebase

## ⚠️ CRÍTICO: Arquivos Firebase Faltando!

O app está configurado para usar Firebase, mas os arquivos de configuração estão faltando:

### 📱 Android: `google-services.json`
### 🍎 iOS: `GoogleService-Info.plist`

---

## 📋 Como Obter os Arquivos:

### 1. Acesse o Firebase Console
- URL: https://console.firebase.google.com/
- Faça login com sua conta Google

### 2. Selecione ou Crie um Projeto
- Se já tem projeto: Selecione **pedeja** ou **pedeja-app**
- Se não tem: Clique em **"Adicionar projeto"**

### 3. Baixar `google-services.json` (Android)

1. No Firebase Console, clique no ⚙️ **Configurações do Projeto**
2. Role até **"Seus apps"**
3. Clique no ícone **Android** (ou clique em **"Adicionar app" > Android**)
4. Preencha:
   - **Nome do pacote Android**: `com.pedeja.app`
   - **Apelido do app** (opcional): PedeJá Android
   - **Certificado SHA-1** (opcional agora, obrigatório para Google Sign-In):
     ```bash
     # No Windows PowerShell:
     cd android
     .\gradlew signingReport
     # Copie o SHA-1 que aparece em "Variant: release"
     ```
5. Clique em **"Registrar app"**
6. **Baixe o arquivo `google-services.json`**
7. Coloque em: `android/app/google-services.json`

### 4. Baixar `GoogleService-Info.plist` (iOS)

1. No Firebase Console, ⚙️ **Configurações do Projeto**
2. Role até **"Seus apps"**
3. Clique no ícone **iOS** (ou clique em **"Adicionar app" > iOS**)
4. Preencha:
   - **ID do pacote iOS**: `com.pedeja.app`
   - **Apelido do app** (opcional): PedeJá iOS
   - **ID da App Store** (deixe em branco por enquanto)
5. Clique em **"Registrar app"**
6. **Baixe o arquivo `GoogleService-Info.plist`**
7. Coloque em: `ios/Runner/GoogleService-Info.plist`

---

## ✅ Checklist Pós-Download:

### Android (`android/app/google-services.json`):
- [ ] Arquivo baixado do Firebase Console
- [ ] Colocado em `android/app/google-services.json`
- [ ] Verificar se `package_name` é `"com.pedeja.app"`
- [ ] Plugin `google-services` já adicionado no `build.gradle.kts` ✅

### iOS (`ios/Runner/GoogleService-Info.plist`):
- [ ] Arquivo baixado do Firebase Console  
- [ ] Colocado em `ios/Runner/GoogleService-Info.plist`
- [ ] Verificar se `BUNDLE_ID` é `com.pedeja.app`
- [ ] Importar no Xcode (se tiver Mac):
  1. Abrir `ios/Runner.xcworkspace` no Xcode
  2. Arrastar `GoogleService-Info.plist` para a pasta `Runner`
  3. Marcar **"Copy items if needed"**
  4. Target: **Runner** ✅

---

## 🔧 Próximos Passos Após Adicionar os Arquivos:

```bash
# 1. Adicionar arquivos ao git
git add android/app/google-services.json
git add ios/Runner/GoogleService-Info.plist

# 2. Commit
git commit -m "Add Firebase configuration files (google-services.json and GoogleService-Info.plist)"

# 3. Push
git push

# 4. Rodar novo build no Codemagic
```

---

## ⚠️ IMPORTANTE:

### O build vai FALHAR sem esses arquivos!

**Erro Android sem `google-services.json`:**
```
File google-services.json is missing. The Google Services Plugin cannot function without it.
```

**Erro iOS sem `GoogleService-Info.plist`:**
```
FirebaseApp.configure() failed because GoogleService-Info.plist is missing
```

---

## 🔒 Segurança:

- ✅ `google-services.json` **PODE** ser commitado (contém apenas IDs públicos)
- ✅ `GoogleService-Info.plist` **PODE** ser commitado (contém apenas IDs públicos)
- ⚠️ **NUNCA** commite chaves de API privadas (`FIREBASE_API_KEY` server-side)

---

## 📞 Precisa de Ajuda?

Se não conseguir acessar o Firebase Console ou baixar os arquivos, me avise que eu posso:
1. Criar templates dos arquivos para você preencher
2. Guiar passo a passo com screenshots
3. Ajudar a configurar Authentication, Firestore, Cloud Messaging, etc.

---

**Última atualização**: Dezembro 2025
**Status**: ⚠️ BLOQUEADOR - Adicione os arquivos para continuar!
