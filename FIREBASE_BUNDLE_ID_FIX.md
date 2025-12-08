# ⚠️ ATENÇÃO: Bundle ID Incorreto no Firebase

## Problema Detectado

O arquivo `GoogleService-Info.plist` que você tem usa:
- **Bundle ID**: `pedeJA.vtx` ❌

Mas o projeto iOS está configurado para:
- **Bundle ID**: `com.pedeja.app` ✅

## ✅ Correção Temporária Aplicada

Eu já corrigi o arquivo `ios/Runner/GoogleService-Info.plist` com o Bundle ID correto (`com.pedeja.app`).

**MAS** você precisa atualizar o Firebase Console também!

---

## 🔧 Como Corrigir no Firebase Console:

### Opção 1: Adicionar Novo App iOS (RECOMENDADO)

1. Acesse: https://console.firebase.google.com/project/pedeja-ec420/settings/general
2. Role até a seção **"Seus apps"**
3. Clique em **"Adicionar app"** → Selecione **iOS**
4. Preencha:
   - **ID do pacote iOS**: `com.pedeja.app` ✅
   - **Apelido do app**: PedeJá iOS (novo)
   - **ID da App Store**: (deixe vazio por enquanto)
5. Clique em **"Registrar app"**
6. **Baixe o novo `GoogleService-Info.plist`** gerado
7. Substitua o arquivo que eu criei por este novo (deve ser idêntico, só o GOOGLE_APP_ID vai mudar)

### Opção 2: Editar App Existente (SE POSSÍVEL)

1. Acesse: https://console.firebase.google.com/project/pedeja-ec420/settings/general
2. Procure o app iOS existente (Bundle ID: `pedeJA.vtx`)
3. Clique nos **3 pontinhos** → **"Configurações do app"**
4. **NÃO DÁ PRA MUDAR O BUNDLE ID!** 😔

**Por isso, use a Opção 1.**

---

## 📋 Checklist Pós-Correção:

- [x] ✅ Arquivo `ios/Runner/GoogleService-Info.plist` criado com Bundle ID correto
- [ ] ⏳ Adicionar novo app iOS no Firebase Console (`com.pedeja.app`)
- [ ] ⏳ Baixar novo `GoogleService-Info.plist` (opcional - o atual deve funcionar)
- [ ] ⏳ Verificar se `google-services.json` (Android) também tem Bundle ID correto

---

## ⚠️ E o Android?

Você também precisa do arquivo `android/app/google-services.json`!

Verifique se o `package_name` é `com.pedeja.app`:

1. Acesse: https://console.firebase.google.com/project/pedeja-ec420/settings/general
2. Role até **"Seus apps"**
3. Procure o app **Android**
4. Se o `package_name` for `com.pedeja.app` ✅:
   - Baixe o `google-services.json`
   - Coloque em `android/app/google-services.json`
5. Se o `package_name` for diferente ❌:
   - Adicione novo app Android com `com.pedeja.app`
   - Baixe o `google-services.json`
   - Coloque em `android/app/google-services.json`

---

## 🎯 Próximos Passos:

```bash
# 1. Adicionar google-services.json (Android)
# Baixe do Firebase Console e coloque em android/app/

# 2. (Opcional) Substituir GoogleService-Info.plist por versão oficial
# Baixe do Firebase Console (após adicionar app com com.pedeja.app)

# 3. Commit
git add ios/Runner/GoogleService-Info.plist
git add android/app/google-services.json  # quando tiver
git commit -m "Add Firebase configuration files with correct Bundle ID"
git push

# 4. Rodar build no Codemagic
```

---

## 🔍 Como Verificar se Está Correto:

### iOS:
```bash
# Verificar Bundle ID no GoogleService-Info.plist
grep -A 1 "BUNDLE_ID" ios/Runner/GoogleService-Info.plist
# Deve retornar: <string>com.pedeja.app</string>
```

### Android:
```bash
# Verificar package_name no google-services.json
grep "package_name" android/app/google-services.json
# Deve retornar: "package_name": "com.pedeja.app"
```

---

**Status**: ✅ iOS corrigido temporariamente | ⏳ Aguardando google-services.json (Android)
