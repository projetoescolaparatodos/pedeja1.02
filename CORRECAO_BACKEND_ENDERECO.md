# 🐛 CORREÇÃO URGENTE: Backend salvando endereço incorretamente

**Data:** 17 de janeiro de 2026  
**Prioridade:** 🔴 CRÍTICA  
**Impacto:** Pedidos não podem ser finalizados

---

## 🔍 PROBLEMA IDENTIFICADO VIA LOGS DO DISPOSITIVO

### O que o Flutter envia:
```json
POST /api/auth/complete-registration
{
  "displayName": "testre",
  "phone": "(67) 99801-8243",
  "address": "R. Isabel Leocádia da Silva, 932 - Jardim Dall'Acqua, Vitória do Xingu/PA",
  "userType": "customer",
  "addressDetails": {
    "zipCode": "68383-000",
    "street": "R. Isabel Leocádia da Silva",
    "number": "932",
    "complement": "",
    "neighborhood": "Jardim Dall'Acqua",
    "city": "Vitória do Xingu",
    "state": "PA",
    "formatted": "R. Isabel Leocádia da Silva, 932 - Jardim Dall'Acqua, Vitória do Xingu/PA"
  }
}
```

### O que o Backend retorna (ERRADO):
```json
{
  "user": {
    "address": {
      "complement": "",
      "number": "",           ← ❌ VAZIO! (deveria ser "932")
      "zipCode": "",          ← ❌ VAZIO! (deveria ser "68383-000")
      "city": "",             ← ❌ VAZIO! (deveria ser "Vitória do Xingu")
      "street": "R. Isabel Leocádia da Silva, 932 - Jardim Dall'Acqua, Vitória do Xingu/PA",  ← ❌ ENDEREÇO COMPLETO AQUI!
      "neighborhood": "",     ← ❌ VAZIO! (deveria ser "Jardim Dall'Acqua")
      "state": ""             ← ❌ VAZIO! (deveria ser "PA")
    },
    "addresses": [
      {
        "zipCode": "",        ← ❌ VAZIO!
        "city": "",           ← ❌ VAZIO!
        "neighborhood": "",   ← ❌ VAZIO!
        "number": "",         ← ❌ VAZIO!
        "street": "R. Isabel Leocádia da Silva, 932 - Jardim Dall'Acqua, Vitória do Xingu/PA",  ← ❌ TUDO AQUI!
        "state": ""           ← ❌ VAZIO!
      }
    ]
  }
}
```

---

## 💥 IMPACTO NO APP

Quando usuário tenta finalizar pedido:

```
🔍 [Validação] Validando endereço: {
  street: "R. Isabel Leocádia da Silva, 932 - Jardim Dall'Acqua, Vitória do Xingu/PA",
  number: "",         ← ❌ VAZIO!
  neighborhood: "",   ← ❌ VAZIO!
  city: "",           ← ❌ VAZIO!
  state: "",          ← ❌ VAZIO!
  zipCode: ""         ← ❌ VAZIO!
}

   Campo street (Rua/Avenida): "R. Isabel Leocádia da Silva..." ✅
   Campo number (Número): "" ❌ VAZIO
   Campo neighborhood (Bairro): "" ❌ VAZIO
   Campo city (Cidade): "" ❌ VAZIO
   Campo state (Estado): "" ❌ VAZIO
   Campo zipCode (CEP): "" ❌ VAZIO

❌ [Validação] ERRO: Complete o endereço: Número, Bairro, Cidade, Estado, CEP
```

**RESULTADO:** Pedido NÃO finaliza!

---

## ✅ CORREÇÃO NECESSÁRIA NO BACKEND

**Arquivo:** `index.js` ou `api/auth/complete-registration.js`  
**Endpoint:** `POST /api/auth/complete-registration`

### ❌ CÓDIGO ATUAL (ERRADO):
```javascript
app.post('/api/auth/complete-registration', async (req, res) => {
  const { displayName, phone, address, addressDetails, userType } = req.body;
  
  // ❌ PROBLEMA: Está usando 'address' (string) ao invés de 'addressDetails' (objeto)
  const userUpdate = {
    displayName,
    phone,
    address: address || addressDetails?.formatted, // ← ERRADO!
    userType,
    dadoscompletos: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };
  
  await db.collection('users').doc(uid).update(userUpdate);
});
```

### ✅ CÓDIGO CORRETO:
```javascript
app.post('/api/auth/complete-registration', async (req, res) => {
  const { displayName, phone, address, addressDetails, userType } = req.body;
  
  // ✅ CORRETO: Usar addressDetails (objeto com campos separados)
  const addressToSave = addressDetails ? {
    street: addressDetails.street || '',
    number: addressDetails.number || '',
    complement: addressDetails.complement || '',
    neighborhood: addressDetails.neighborhood || '',
    city: addressDetails.city || '',
    state: addressDetails.state || '',
    zipCode: addressDetails.zipCode || ''
  } : {
    street: address || '', // Fallback para string antiga
    number: '',
    complement: '',
    neighborhood: '',
    city: '',
    state: '',
    zipCode: ''
  };
  
  const userUpdate = {
    displayName,
    phone,
    address: addressToSave,  // ✅ Objeto com campos separados
    addresses: [addressToSave], // ✅ Array com mesmo formato
    userType,
    dadoscompletos: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  };
  
  await db.collection('users').doc(uid).update(userUpdate);
  
  console.log('✅ Endereço salvo corretamente:', addressToSave);
});
```

---

## 🧪 COMO TESTAR APÓS CORREÇÃO

1. **No celular, ir em "Completar Cadastro"**
2. **Preencher endereço via GPS**
3. **Salvar**
4. **Verificar logs do backend:**
```
✅ Endereço salvo corretamente: {
  street: 'R. Isabel Leocádia da Silva',
  number: '932',
  neighborhood: 'Jardim Dall\'Acqua',
  city: 'Vitória do Xingu',
  state: 'PA',
  zipCode: '68383-000'
}
```

5. **No app, tentar finalizar pedido**
6. **Verificar logs do app:**
```
🔍 [Validação] Validando endereço: {
  street: "R. Isabel Leocádia da Silva",
  number: "932",
  neighborhood: "Jardim Dall'Acqua",
  city: "Vitória do Xingu",
  state: "PA",
  zipCode: "68383-000"
}

   Campo street (Rua/Avenida): "R. Isabel Leocádia da Silva" ✅
   Campo number (Número): "932" ✅
   Campo neighborhood (Bairro): "Jardim Dall'Acqua" ✅
   Campo city (Cidade): "Vitória do Xingu" ✅
   Campo state (Estado): "PA" ✅
   Campo zipCode (CEP): "68383-000" ✅

✅ [Validação] Endereço completo!
```

---

## 📊 VALIDAÇÃO FINAL

**ANTES (com bug):**
```json
{
  "address": {
    "street": "R. Isabel Leocádia da Silva, 932 - Jardim Dall'Acqua, Vitória do Xingu/PA",
    "number": "",
    "neighborhood": "",
    "city": "",
    "state": "",
    "zipCode": ""
  }
}
```

**DEPOIS (corrigido):**
```json
{
  "address": {
    "street": "R. Isabel Leocádia da Silva",
    "number": "932",
    "complement": "",
    "neighborhood": "Jardim Dall'Acqua",
    "city": "Vitória do Xingu",
    "state": "PA",
    "zipCode": "68383-000"
  }
}
```

---

## 🚨 AÇÃO IMEDIATA NECESSÁRIA

1. **Corrigir endpoint `/api/auth/complete-registration`** no backend
2. **Fazer deploy do backend**
3. **Pedir para usuários atualizarem cadastro** (reentrar em "Completar Cadastro" e salvar novamente)
4. **Testar finalização de pedido**

---

## 📝 ALTERNATIVA TEMPORÁRIA (Se não puder corrigir backend agora)

Podemos fazer o Flutter aceitar endereço parseando o campo `street`:

```dart
// WORKAROUND temporário no Flutter:
if (address is Map && address['number']?.isEmpty == true) {
  // Parsear de street se outros campos vazios
  final fullStreet = address['street'] ?? '';
  
  // Regex: "R. Fulana, 123 - Bairro, Cidade/Estado"
  final match = RegExp(r'^(.+),\s*(\d+)\s*-\s*([^,]+),\s*([^/]+)/(.+)$')
      .firstMatch(fullStreet);
  
  if (match != null) {
    address = {
      'street': match.group(1),
      'number': match.group(2),
      'neighborhood': match.group(3),
      'city': match.group(4),
      'state': match.group(5),
      'zipCode': address['zipCode'] ?? '',
    };
  }
}
```

**MAS ISSO É GAMBIARRA!** A solução correta é **CORRIGIR O BACKEND**.

---

## 🎯 RESUMO

| Item | Status |
|------|--------|
| **Problema identificado** | ✅ Backend salvando errado |
| **Causa** | ❌ Usa `address` (string) ao invés de `addressDetails` (objeto) |
| **Solução** | ✅ Código correto fornecido acima |
| **Impacto** | 🔴 CRÍTICO - Pedidos não finalizam |
| **Prioridade** | 🔴 URGENTE - Corrigir HOJE |

---

**LOGS COMPLETOS ANEXADOS NO TERMINAL**
