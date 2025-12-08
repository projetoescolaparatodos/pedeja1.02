# 🔥 URGENTE: Adicionar App Android no Firebase

## ⚠️ Problema Identificado

O arquivo `google-services.json` que você tem contém apps com package names ERRADOS:
- ❌ `com.pedeja.correja`
- ❌ `pedeJA.vtx`

**Você precisa**: `com.pedeja.app` ✅

---

## 📱 Como Adicionar App Android Correto:

### Passo 1: Acessar Firebase Console
1. Abra: https://console.firebase.google.com/project/pedeja-ec420/settings/general
2. Faça login (se necessário)

### Passo 2: Adicionar Novo App Android
1. Role a página até a seção **"Seus apps"**
2. Clique no botão **"Adicionar app"**
3. Selecione o ícone **Android** (robozinho verde)

### Passo 3: Preencher Informações
```
┌─────────────────────────────────────────────────┐
│ Nome do pacote Android (obrigatório)           │
│ com.pedeja.app                                  │ ✅ COPIE EXATAMENTE
├─────────────────────────────────────────────────┤
│ Apelido do app (opcional)                       │
│ PedeJá Android                                  │
├─────────────────────────────────────────────────┤
│ Certificado de assinatura SHA-1 (opcional)      │
│ [deixe em branco por enquanto]                  │
└─────────────────────────────────────────────────┘
```

4. Clique em **"Registrar app"**

### Passo 4: Baixar google-services.json
1. O Firebase vai mostrar uma tela com um botão **"Baixar google-services.json"**
2. **CLIQUE NELE!** ⬇️
3. Salve o arquivo

### Passo 5: Verificar Conteúdo
Abra o arquivo baixado e procure por:
```json
"android_client_info": {
  "package_name": "com.pedeja.app"  ← DEVE TER ISSO!
}
```

Se tiver `com.pedeja.app`, está correto! ✅

---

## 🎯 Depois de Baixar o Arquivo Correto:

### Me envie o novo arquivo `google-services.json`

OU

### Copie manualmente:
```bash
# No PowerShell:
Copy-Item "C:\Users\nalbe\Downloads\google-services.json" "C:\Users\nalbe\Downloads\pedeja1.02\android\app\google-services.json"
```

---

## 🔍 Como Eu Vou Verificar se Está Correto:

Quando você me enviar o arquivo, eu vou procurar por:
```json
"package_name": "com.pedeja.app"
```

Se não tiver, vou te avisar para baixar de novo! 😊

---

## ⏱️ Não Pule Este Passo!

**SEM** o `google-services.json` correto:
- ❌ Firebase Authentication não vai funcionar
- ❌ Cloud Firestore não vai conectar
- ❌ Push notifications não vão chegar
- ❌ Todos os serviços Firebase vão falhar

**COM** o arquivo correto:
- ✅ Autenticação funcionando
- ✅ Database sincronizado
- ✅ Notificações recebidas
- ✅ App 100% funcional! 🚀

---

**Status**: ⏳ Aguardando `google-services.json` com `package_name: com.pedeja.app`
