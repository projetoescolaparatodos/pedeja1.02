# 🏪 Adicionar Endereço do Restaurante nos Pedidos (Backend)

## 🎯 Objetivo
Incluir o campo `restaurantAddress` no documento do pedido para que o app do entregador possa exibir o endereço de coleta sem precisar fazer queries adicionais.

## 📍 Localização no Backend
**Arquivo:** Projeto da API (api-pedeja.vercel.app)
**Endpoint:** `POST /api/orders`
**Procurar por:** Código que cria o documento do pedido no Firestore

---

## 🔧 Implementação Cirúrgica

### Passo 1: Localizar o Endpoint
No projeto backend (api-pedeja), encontre o arquivo que trata `POST /api/orders`. Geralmente está em:
- `api/orders.js` ou
- `api/orders/index.js` ou
- `routes/orders.js`

### Passo 2: Buscar os Dados do Restaurante

Adicione esta busca **ANTES** de criar o documento do pedido:

```javascript
// ✅ Buscar dados completos do restaurante (incluindo endereço)
const restaurantRef = admin.firestore().collection('restaurants').doc(restaurantId);
const restaurantDoc = await restaurantRef.get();

if (!restaurantDoc.exists) {
  return res.status(404).json({ 
    success: false, 
    message: 'Restaurante não encontrado' 
  });
}

const restaurantData = restaurantDoc.data();
```

### Passo 3: Adicionar o Campo no Documento do Pedido

Localize onde o `orderData` é montado e adicione o campo `restaurantAddress`:

```javascript
// Objeto do pedido que será salvo no Firestore
const orderData = {
  orderId: orderId,
  userId: req.user.uid,
  userName: req.body.userName || '',
  userEmail: req.user.email || '',
  userPhone: req.body.userPhone || '',
  
  // Dados do restaurante
  restaurantId: restaurantId,
  restaurantName: req.body.restaurantName || restaurantData.name || '',
  
  // ✅ NOVO CAMPO - Endereço do restaurante para o entregador
  restaurantAddress: {
    street: restaurantData.address?.street || '',
    number: restaurantData.address?.number || '',
    neighborhood: restaurantData.address?.neighborhood || '',
    complement: restaurantData.address?.complement || '',
    city: restaurantData.address?.city || '',
    state: restaurantData.address?.state || '',
    zipCode: restaurantData.address?.zipCode || restaurantData.address?.cep || ''
  },
  
  // Dados do pedido
  items: normalizedItems,
  subtotal: req.body.subtotal || 0,
  deliveryFee: req.body.deliveryFee || 0,
  totalAmount: req.body.totalAmount || 0,
  
  // Endereço de entrega (do cliente)
  deliveryAddress: normalizedDeliveryAddress,
  
  // Resto dos campos...
  payment: normalizedPayment,
  status: 'pending',
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  // ...
};

// Salvar no Firestore
await admin.firestore().collection('orders').doc(orderId).set(orderData);
```

---

## 📋 Exemplo de Documento Final

Após a implementação, o documento do pedido ficará assim:

```javascript
{
  "orderId": "Ig38QqvePDMVnJRc4Dkl",
  "restaurantId": "h5S1PDEPIjkO44SPLKRP",
  "restaurantName": "Drogaria Vitória",
  
  // ✅ NOVO - Endereço do restaurante (coleta)
  "restaurantAddress": {
    "street": "Av. Central",
    "number": "500",
    "neighborhood": "Centro",
    "complement": "Próximo ao banco",
    "city": "Vitória do Xingu",
    "state": "PA",
    "zipCode": "68383-000"
  },
  
  // Endereço de entrega (cliente)
  "deliveryAddress": {
    "street": "R. Isabel Leocádia da Silva",
    "number": "932",
    "neighborhood": "Jardim Dall'Acqua",
    "complement": "oie",
    "city": "Vitória do Xingu",
    "state": "PA",
    "zipCode": "68383-000"
  },
  
  // ... resto dos campos
}
```

---

## ✅ Checklist de Implementação

1. [ ] Localizar arquivo do endpoint `POST /api/orders` no backend
2. [ ] Adicionar busca do documento do restaurante no Firestore
3. [ ] Adicionar campo `restaurantAddress` no objeto `orderData`
4. [ ] Testar criando um pedido no app
5. [ ] Verificar no Firestore Console se o campo `restaurantAddress` aparece
6. [ ] Fazer deploy do backend na Vercel

---

## 🚀 Deploy

Após fazer as alterações:

```bash
# No projeto backend
git add .
git commit -m "feat: Adicionar restaurantAddress nos pedidos para app entregador"
git push origin main

# Vercel fará deploy automático
```

---

## 🔍 Validação

Para validar que funcionou:

1. Crie um pedido pelo app Flutter
2. Acesse o Firestore Console
3. Navegue até `orders/{orderId}`
4. Verifique se existe o campo `restaurantAddress` com todos os subcampos

---

## 📱 Uso no App do Entregador

Com esse campo disponível, o app do entregador pode exibir:

**Coleta (Restaurante):**
```
🏪 Drogaria Vitória
📍 Av. Central, 500 - Centro
   Próximo ao banco
   Vitória do Xingu - PA
   CEP: 68383-000
```

**Entrega (Cliente):**
```
🏠 teste70
📍 R. Isabel Leocádia da Silva, 932 - Jardim Dall'Acqua
   Apto 101 (oie)
   Vitória do Xingu - PA
   CEP: 68383-000
📞 (67) 99801-8243
```

---

## ⚠️ Observações Importantes

1. **Compatibilidade**: Pedidos antigos não terão o campo `restaurantAddress`. O app do entregador deve ter fallback.
2. **Performance**: A busca do restaurante adiciona ~200ms na criação do pedido (aceitável).
3. **Cache**: Considere cachear dados de restaurante se o volume for alto (não necessário agora).
4. **Zero impacto no Flutter**: Esta mudança é 100% backend, o app cliente continua funcionando normalmente.

---

**Status**: 🔴 Aguardando implementação no backend
