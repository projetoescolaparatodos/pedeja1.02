# 🔥 Configuração do Firebase para PedeJá

## 📋 Passo a Passo

### 1. Criar Projeto no Firebase Console

1. Acesse [Firebase Console](https://console.firebase.google.com/)
2. Clique em "Adicionar projeto"
3. Nome do projeto: `pedeja` (ou o nome de sua preferência)
4. Desabilite Google Analytics (opcional)
5. Clique em "Criar projeto"

---

### 2. Adicionar App Web ao Projeto

1. No Firebase Console, clique no ícone **Web** (`</>`)
2. Nome do app: `PedeJá Web`
3. **NÃO** marque "Configure Firebase Hosting"
4. Clique em "Registrar app"
5. **Copie a configuração** que aparecerá (você vai usar no passo 3)

Exemplo da configuração:
```javascript
const firebaseConfig = {
  apiKey: "AIza....",
  authDomain: "pedeja-xxxxx.firebaseapp.com",
  projectId: "pedeja-xxxxx",
  storageBucket: "pedeja-xxxxx.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef"
};
```

---

### 3. Criar Arquivo de Configuração Web

Crie o arquivo `web/firebase-config.js`:

```javascript
// web/firebase-config.js

// Import the functions you need from the SDKs you need
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js";
import { getFirestore } from "https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js";

// COLE AQUI A SUA CONFIGURAÇÃO DO FIREBASE
const firebaseConfig = {
  apiKey: "SUA_API_KEY_AQUI",
  authDomain: "SEU_PROJECT_ID.firebaseapp.com",
  projectId: "SEU_PROJECT_ID",
  storageBucket: "SEU_PROJECT_ID.appspot.com",
  messagingSenderId: "SEU_SENDER_ID",
  appId: "SEU_APP_ID"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const firestore = getFirestore(app);

export { app, auth, firestore };
```

---

### 4. Atualizar web/index.html

Adicione o script do Firebase no `web/index.html` **ANTES** do script principal:

```html
<!DOCTYPE html>
<html>
<head>
  <!-- ... outros metas ... -->
  <title>PedeJá</title>
</head>
<body>
  <!-- Firebase SDK -->
  <script type="module" src="firebase-config.js"></script>
  
  <!-- Flutter -->
  <script src="flutter.js" defer></script>
  
  <!-- ... resto do body ... -->
</body>
</html>
```

---

### 5. Habilitar Authentication

1. No Firebase Console, vá em **Authentication**
2. Clique em "Começar"
3. Vá na aba **Sign-in method**
4. Habilite **Email/Password**
   - Clique em "Email/Password"
   - Ative o primeiro toggle (Email/Password)
   - Salve

---

### 6. Criar Firestore Database

1. No Firebase Console, vá em **Firestore Database**
2. Clique em "Criar banco de dados"
3. Escolha **Modo de teste** (pode mudar depois)
4. Escolha a localização: `southamerica-east1` (São Paulo)
5. Clique em "Ativar"

---

### 7. Configurar Regras de Segurança do Firestore

Vá em **Firestore Database → Regras** e cole:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Regras para usuários autenticados
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Regras para pedidos
    match /orders/{orderId} {
      // Permitir criar pedido se autenticado
      allow create: if request.auth != null;
      
      // Permitir ler e atualizar apenas próprios pedidos
      allow read, update: if request.auth != null && 
                            resource.data.userId == request.auth.uid;
      
      // Deletar não permitido
      allow delete: if false;
    }
    
    // Regras para restaurantes (apenas leitura)
    match /restaurants/{restaurantId} {
      allow read: if true; // Qualquer um pode ler
      allow write: if false; // Apenas admin pode escrever
    }
    
    // Regras para produtos (apenas leitura)
    match /products/{productId} {
      allow read: if true; // Qualquer um pode ler
      allow write: if false; // Apenas admin pode escrever
    }
  }
}
```

Clique em "Publicar".

---

### 8. Instalar Firebase CLI (Opcional - para Android/iOS)

```bash
npm install -g firebase-tools

# Login no Firebase
firebase login

# Configurar projeto Flutter
flutterfire configure
```

---

### 9. Configurar Android (Opcional)

Se for rodar no Android, siga estes passos:

1. No Firebase Console, clique em "Adicionar app" → Android
2. **Android package name**: `com.pedeja.pedeja_clean` (ou o que está no seu `android/app/build.gradle`)
3. Baixe o arquivo `google-services.json`
4. Cole em `android/app/google-services.json`
5. Adicione ao `android/build.gradle`:

```gradle
buildscript {
  dependencies {
    // ... outras dependências
    classpath 'com.google.gms:google-services:4.4.0'
  }
}
```

6. Adicione ao `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'
```

---

### 10. Testar Autenticação

Crie um usuário de teste manualmente:

1. Firebase Console → **Authentication** → **Users**
2. Clique em "Adicionar usuário"
3. Email: `teste@pedeja.com`
4. Senha: `teste123`
5. Clique em "Adicionar usuário"

---

### 11. Estrutura de Dados no Firestore

O app criará automaticamente estas coleções:

#### 📦 Collection: `orders`

```javascript
{
  id: "abc123",
  restaurantId: "rest_001",
  restaurantName: "Restaurante Exemplo",
  userId: "user_xyz",
  userEmail: "user@example.com",
  items: [
    {
      productId: "prod_001",
      name: "Pizza Margherita",
      price: 35.90,
      quantity: 1,
      imageUrl: "https://...",
      addons: [
        { name: "Borda Recheada", price: 5.00 }
      ],
      totalPrice: 40.90
    }
  ],
  total: 40.90,
  totalAmount: 40.90,
  deliveryAddress: "Rua ABC, 123 - Centro, São Paulo - SP CEP: 01234-567",
  status: "pending", // pending | preparing | ready | delivered
  paymentStatus: "pending", // pending | approved | paid | rejected
  payment: {
    method: "mercadopago",
    provider: "mercadopago",
    status: "pending",
    transactionId: "mp_123456",
    initPoint: "https://mercadopago.com/checkout/..."
  },
  createdAt: Timestamp
}
```

---

## 🔐 Variáveis de Ambiente (Segurança)

**IMPORTANTE**: Nunca commite as credenciais do Firebase no Git!

Crie um arquivo `.env` na raiz do projeto:

```env
FIREBASE_API_KEY=SUA_API_KEY
FIREBASE_AUTH_DOMAIN=SEU_PROJECT.firebaseapp.com
FIREBASE_PROJECT_ID=SEU_PROJECT_ID
FIREBASE_STORAGE_BUCKET=SEU_PROJECT.appspot.com
FIREBASE_MESSAGING_SENDER_ID=SEU_SENDER_ID
FIREBASE_APP_ID=SEU_APP_ID
```

Adicione ao `.gitignore`:

```
.env
web/firebase-config.js
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

---

## 🧪 Testar o Fluxo Completo

1. **Instalar dependências**:
   ```bash
   flutter pub get
   ```

2. **Rodar o app**:
   ```bash
   flutter run -d chrome
   ```

3. **Criar conta** (ou usar conta de teste)

4. **Adicionar produtos ao carrinho**

5. **Finalizar pedido**:
   - Verifica perfil completo
   - Cria pedido no Firestore
   - Abre checkout do Mercado Pago
   - Aguarda confirmação de pagamento

6. **Verificar no Firebase Console**:
   - Ir em **Firestore Database**
   - Ver coleção `orders`
   - Ver documento do pedido criado

---

## 📊 Monitoramento

Para ver os logs em tempo real:

```bash
# Web
flutter run -d chrome --web-renderer html

# Android
flutter run -d emulator-5554

# Ver logs do Firestore
firebase firestore:log
```

---

## 🚨 Troubleshooting

### Erro: "Firebase not initialized"

Verifique se:
1. `firebase-config.js` está em `web/`
2. `index.html` carrega o script
3. As credenciais estão corretas

### Erro: "Permission denied" no Firestore

Verifique:
1. Regras de segurança publicadas
2. Usuário está autenticado (`FirebaseAuth.instance.currentUser`)

### Erro: "Network request failed"

Verifique:
1. Internet conectada
2. Firebase project está ativo
3. Billing habilitado (se necessário)

---

## 📚 Próximos Passos

- [ ] Configurar Firebase Cloud Functions para webhooks
- [ ] Implementar Firebase Cloud Messaging (notificações)
- [ ] Adicionar Firebase Analytics
- [ ] Configurar Firebase Performance Monitoring
- [ ] Implementar backup automático do Firestore

---

## 🔗 Links Úteis

- [Firebase Console](https://console.firebase.google.com/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
