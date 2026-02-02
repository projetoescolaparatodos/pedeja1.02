📦 Produtos com Retirada Obrigatória (Pickup Only)

## 📋 Objetivo

Permitir que produtos sejam marcados como "apenas retirada no local", impedindo que sejam entregues a domicílio. Útil para:
- 🍺 Bebidas alcoólicas (exigem documento na retirada)
- 🎂 Bolos e tortas personalizadas
- 🍕 Pizzas que devem ser consumidas na hora
- 🧊 Produtos congelados que não suportam tempo de entrega
- 🔪 Produtos frágeis ou perecíveis

---

## 🏗️ Arquitetura da Solução

### 1️⃣ **Estrutura do Produto (Firestore)**

```javascript
{
  "id": "prod_123",
  "name": "Cerveja Artesanal 500ml",
  "price": 15.00,
  "category": "Bebidas",
  
  // ✅ NOVO CAMPO
  "pickupOnly": true,  // Se true, produto NÃO pode ser entregue
  "pickupOnlyReason": "Exige verificação de documento (18+)",  // Opcional: motivo
  
  "available": true,
  "stock": 50,
  // ... outros campos
}
```

**Campos adicionados:**
- `pickupOnly` (boolean): Define se produto só pode ser retirado no local
- `pickupOnlyReason` (string, opcional): Motivo para exibir no app

---

### 2️⃣ **Validação no Backend**

#### **A. Validação ao Criar Pedido** (POST `/api/orders`)

**Regra:** Se o carrinho contém **QUALQUER produto** com `pickupOnly: true`, o pedido **DEVE ser pickup**.

```javascript
// Localização: index.js, linha ~12520 (antes de validar restaurante)

// 🔒 VALIDAR PRODUTOS QUE EXIGEM PICKUP
const productsWithPickupOnly = [];
for (const item of items) {
  const productDoc = await db.collection('products').doc(item.productId).get();
  if (productDoc.exists) {
    const productData = productDoc.data();
    if (productData.pickupOnly === true) {
      productsWithPickupOnly.push({
        id: item.productId,
        name: productData.name,
        reason: productData.pickupOnlyReason || 'Este produto só pode ser retirado no local'
      });
    }
  }
}

// Se há produtos que exigem pickup, validar se pedido é pickup
if (productsWithPickupOnly.length > 0) {
  const isPickup = req.body.deliveryAddress?.method === 'pickup' || req.body.delivery === null;
  
  if (!isPickup) {
    return res.status(400).json({
      success: false,
      error: 'PICKUP_REQUIRED',
      message: 'Seu carrinho contém produtos que só podem ser retirados no local',
      pickupOnlyProducts: productsWithPickupOnly,
      code: 'PICKUP_REQUIRED'
    });
  }
  
  console.log(`📦 [PICKUP-ONLY] Pedido validado: ${productsWithPickupOnly.length} produto(s) exigem retirada`);
}
```

---

#### **B. Validação ao Criar/Editar Produto**

**Permitir definir campo ao criar produto:**

```javascript
// POST /api/restaurants/:id/products (linha ~11435)

const newProduct = {
  name,
  price,
  // ... outros campos
  
  // ✅ ADICIONAR
  pickupOnly: typeof pickupOnly === 'boolean' ? pickupOnly : false,
  pickupOnlyReason: pickupOnlyReason || null,
};
```

**E ao editar:**

```javascript
// PATCH /api/products/:id (linha ~11540)

const allowedFields = [
  'name', 'price', 'description', 'category', 'badges', 
  'addons', 'available', 'stock', 'imageUrl',
  'pickupOnly', 'pickupOnlyReason'  // ✅ ADICIONAR
];
```

---

### 3️⃣ **Frontend Flutter**

#### **A. Modelo de Produto**

```dart
class Product {
  final String id;
  final String name;
  final double price;
  
  // ✅ NOVOS CAMPOS
  final bool pickupOnly;
  final String? pickupOnlyReason;
  
  Product({
    required this.id,
    required this.name,
    required this.price,
    this.pickupOnly = false,
    this.pickupOnlyReason,
  });
  
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      price: (json['price'] as num).toDouble(),
      pickupOnly: json['pickupOnly'] ?? false,
      pickupOnlyReason: json['pickupOnlyReason'],
    );
  }
}
```

#### **B. Lógica do Carrinho**

```dart
class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  
  // ✅ Verificar se QUALQUER produto exige pickup
  bool get hasPickupOnlyProducts {
    return _items.any((item) => item.product.pickupOnly == true);
  }
  
  // ✅ Listar produtos que exigem pickup
  List<Product> get pickupOnlyProducts {
    return _items
        .where((item) => item.product.pickupOnly == true)
        .map((item) => item.product)
        .toList();
  }
}
```

#### **C. Página de Detalhes do Produto** (product_detail_page.dart)

**Badge "Somente Retirada" em cima da imagem:**

```dart
class ProductDetailPage extends StatelessWidget {
  final Product product;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Imagem do produto
          Container(
            height: 300,
            child: Image.network(product.imageUrl, fit: BoxFit.cover),
          ),
          
          // ✅ Badge "Somente Retirada" em cima da imagem
          if (product.pickupOnly)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Somente retirada no local',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // ... resto da página (nome, preço, descrição, etc.)
        ],
      ),
    );
  }
}
```

**Opcional: Motivo do pickup-only na descrição:**

```dart
// Abaixo da descrição do produto
if (product.pickupOnly && product.pickupOnlyReason != null)
  Container(
    margin: EdgeInsets.only(top: 12),
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      border: Border.all(color: Colors.orange.shade200),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.orange, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            product.pickupOnlyReason!,
            style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  ),
```

#### **D. Página de Método de Recebimento** (checkout/payment)

**Esconder/Desabilitar "Entrega em casa" se há produtos pickupOnly:**

```dart
class DeliveryMethodPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final bool hasPickupOnlyProducts = cart.hasPickupOnlyProducts;
    
    return Scaffold(
      appBar: AppBar(title: Text('Como quer receber?')),
      body: Column(
        children: [
          // ✅ AVISO se tem produtos que exigem retirada
          if (hasPickupOnlyProducts)
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seu pedido contém produtos que só podem ser retirados no local',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // ✅ OPÇÃO 1: Entrega em casa
          // Se hasPickupOnlyProducts == true, NÃO EXIBIR esta opção
          if (!hasPickupOnlyProducts)
            ListTile(
              title: Text('Entrega em casa'),
              subtitle: Text('Receba no seu endereço'),
              leading: Radio(
                value: 'delivery',
                groupValue: selectedMethod,
                onChanged: (value) {
                  setState(() => selectedMethod = value);
                },
              ),
              trailing: Icon(Icons.delivery_dining),
            ),
          
          // ✅ OPÇÃO 2: Consumo no local (UI) → pickup (API)
          // Sempre disponível, mas é a ÚNICA opção se hasPickupOnlyProducts
          ListTile(
            title: Text('Consumo no local'),  // ← Texto para o cliente
            subtitle: Text('Retirar no estabelecimento'),
            leading: Radio(
              value: 'pickup',  // ← Valor enviado para API
              groupValue: hasPickupOnlyProducts ? 'pickup' : selectedMethod,
              onChanged: (value) {
                setState(() => selectedMethod = value);  // value = 'pickup'
              },
            ),
            trailing: Icon(Icons.store),
          ),
          
          // ✅ Botão de continuar
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () => _continueToPayment(),
              child: Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Lógica alternativa (manter opção delivery mas desabilitada):**

```dart
// Se preferir MOSTRAR mas DESABILITAR a opção delivery:
ListTile(
  title: Text(
    'Entrega em casa',
    style: TextStyle(
      color: hasPickupOnlyProducts ? Colors.grey : Colors.black,
    ),
  ),
  subtitle: Text(
    hasPickupOnlyProducts 
        ? 'Indisponível (produtos exigem retirada)'
        : 'Receba no seu endereço',
    style: TextStyle(fontSize: 12),
  ),
  leading: Radio(
    value: 'delivery',
    groupValue: selectedMethod,
    onChanged: hasPickupOnlyProducts ? null : (value) {
      setState(() => selectedMethod = value);
    },
  ),
  trailing: Icon(
    Icons.delivery_dining,
    color: hasPickupOnlyProducts ? Colors.grey : null,
  ),
  enabled: !hasPickupOnlyProducts,
),

// ⚠️ IMPORTANTE: Ao enviar para API, sempre usar 'pickup':
void _continueToPayment() {
  // Se tem produtos pickupOnly, garantir que método é 'pickup'
  final method = hasPickupOnlyProducts ? 'pickup' : selectedMethod;
  
  // Enviar para próxima página/API
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => PaymentPage(deliveryMethod: method),  // 'pickup' ou 'delivery'
  ));
}
```

**📝 Nota importante sobre nomenclatura:**
- **Interface (Cliente vê)**: "Consumo no local" ← Mais amigável e claro
- **API (Backend recebe)**: `method: 'pickup'` ← Valor técnico existente
- **Lógica interna**: Sem mudanças, usa a mesma validação de `pickup` que já existe

---

## 🔄 Fluxo Completo da Feature

### **Fluxo 1: Cliente navega e adiciona produto normal**
```
1. Cliente vê produto na home (sem badge)
2. Clica no produto → Abre página de detalhes (sem badge)
3. Adiciona ao carrinho
4. No checkout → Página "Como quer receber?":
   ✅ "Entrega em casa" disponível
   ✅ "Consumo no local" disponível
5. App envia para API: { deliveryAddress: { method: 'pickup' } }
   ↑ Internamente usa 'pickup', mas cliente viu "Consumo no local"
7. Backend valida:
   ✅ Tem produto pickupOnly?
   ✅ Pedido é pickup?
   ✅ APROVADO
8## **Fluxo 2: Cliente navega e adiciona produto pickupOnly**
```
1. Cliente vê produto na home (sem badge - igual aos outros)
2. Clica no produto → Abre página de detalhes
   🏪 Badge laranja "Somente retirada no local" aparece em cima da imagem
   ℹ️ Motivo exibido abaixo (se configurado): "Exige verificação de documento (18+)"
3. Cliente adiciona ao carrinho
4. No checkout → Página "Como quer receber?":
   ⚠️ Aviso: "Seu pedido contém produtos que só podem ser retirados no local"
   ❌ "Entrega em casa" NÃO APARECE (ou aparece desabilitada)
   ✅ "Consumo no local" é a ÚNICA opção disponível
5. Cliente seleciona "Consumo no local" (automático ou forçado)
6. Backend valida:
   ✅ Tem produto pickupOnly?
   ✅ Pedido é pickup?
   ✅ APROVADO
7. ✅ Pedido criado com sucesso
```

### **Fluxo 3: Pedido misto (produtos normais + pickupOnly)**
```
1. Cliente adiciona:
   - 2x Açaí (normal)
   - 1x Cerveja Artesanal (pickupOnly: true)
2. No checkout → Página "Como quer receber?":
   ⚠️ Aviso: "Seu pedido contém produtos que só podem ser retirados no local"
   ❌ "Entrega em casa" NÃO DISPONÍVEL
   ✅ Apenas "Consumo no local" disponível
3. Cliente obrigado a escolher pickup
4. ✅ Pedido criado com sucesso (todos produtos retirados juntos)
```

### **Cenário 3: Tentativa de Burlar (delivery com pickup-only)**
```
1. Usuário malicioso tenta enviar:
   - items: [{ productId: "cerveja_123" }]  // pickupOnly: true
   - deliveryAddress: { method: "delivery" }  // ❌ INVÁLIDO
   
2. Backend valida:
   - ❌ Produto exige pickup mas pedido é delivery
   - 🚫 REJEITA com erro 400
   
3. Resposta:
   {
     "success": false,
     "error": "PICKUP_REQUIRED",
     "message": "Seu carrinho contém produtos que só podem ser retirados no local",
     "pickupOnlyProducts": [
       {
         "id": "cerveja_123",
         "name": "Cerveja Artesanal",
         "reason": "Exige verificação de documento (18+)"
       }
     ]
   }
```

---

## 📊 Implementação no Painel Admin

### **Tela de Criar/Editar Produto**

```html
<!-- Adicionar checkbox -->
<div class="form-group">
  <label>
    <input type="checkbox" id="pickupOnly" name="pickupOnly">
    Somente retirada no local
  </label>
  <small class="form-text text-muted">
    Se marcado, este produto NÃO poderá ser entregue a domicílio
  </small>
</div>

<div class="form-group" id="pickupReasonGroup" style="display: none;">
  <label for="pickupOnlyReason">Motivo (opcional)</label>
  <input 
    type="text" 
    class="form-control" 
    id="pickupOnlyReason" 
    name="pickupOnlyReason"
    placeholder="Ex: Exige verificação de documento (18+)"
  >
</div>

<script>
  // Mostrar campo de motivo apenas se checkbox marcado
  document.getElementById('pickupOnly').addEventListener('change', function() {
    const reasonGroup = document.getElementById('pickupReasonGroup');
    reasonGroup.style.display = this.checked ? 'block' : 'none';
  });
</script>
```

---

## 🧪 Casos de Teste

### **Backend (Jest/Mocha)**

```javascript
describe('POST /api/orders - Pickup Only Validation', () => {
  it('deve ACEITAR pedido pickup com produto pickupOnly', async () => {
    const response = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        restaurantId: 'rest_123',
        items: [{ productId: 'cerveja_123', quantity: 1 }],  // pickupOnly: true
        deliveryAddress: { method: 'pickup', street: 'X', number: '1' }
      });
    
    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
  });
  
  it('deve REJEITAR pedido delivery com produto pickupOnly', async () => {
    const response = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        restaurantId: 'rest_123',
        items: [{ productId: 'cerveja_123', quantity: 1 }],  // pickupOnly: true
        deliveryAddress: { method: 'delivery', street: 'X', number: '1' }  // ❌
      });
    
    expect(response.status).toBe(400);
    expect(response.body.error).toBe('PICKUP_REQUIRED');
    expect(response.body.pickupOnlyProducts).toHaveLength(1);
  });
  
  it('deve ACEITAR pedido delivery SEM produtos pickupOnly', async () => {
    const response = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${token}`)
      .send({
        restaurantId: 'rest_123',
        items: [{ productId: 'acai_123', quantity (`pickupOnly`, `pickupOnlyReason`)
- [ ] Adicionar getter `hasPickupOnlyProducts` no CartProvider
- [ ] **Página de Detalhes do Produto** (product_detail_page.dart):
  - [ ] Adicionar badge 🏪 "Somente retirada no local" em cima da imagem
  - [ ] Exibir motivo abaixo da descrição (se configurado)
- [ ] **Página "Como quer receber?"** (delivery_method/checkout):
  - [ ] Esconder/desabilitar opção "Entrega em casa" se `hasPickupOnlyProducts == true`
  - [ ] Deixar apenas "Consumo no local" disponível
  - [ ] Exibir aviso: "Seu pedido contém produtos que só podem ser retirados no local"
  });
});
```

---

## ✅ Checklist de Implementação

### **Backend (Node.js/Express)**
- [ ] Adicionar campo `pickupOnly` e `pickupOnlyReason` ao criar produto
- [ ] Adicionar campo `pickupOnly` e `pickupOnlyReason` ao editar produto
- [ ] Validar pickup-only ao criar pedido (POST /api/orders)
- [ ] Retornar erro detalhado se violação detectada
- [ ] Adicionar logs de segurança

### **Frontend (Flutter)**
- [ ] Atualizar modelo `Product` com novos campos
- [ ] Adicionar getter `hasPickupOnlyProducts` no CartProvider
- [ ] Desabilitar opção "Delivery" se `hasPickupOnlyProducts == true`
- [ ] Exibir aviso visual no checkout
- [ ] Adicionar badge "Somente retirada" nos cards de produto
- [ ] Forçar `method: 'pickup'` ao criar pedido se necessário
- [ ] Tratar erro `PICKUP_REQUIRED` do backend

### **Painel Admin** ✅ CONCLUÍDO
- [x] Adicionar checkbox "Somente retirada no local"
- [x] Adicionar campo "Motivo" (opcional)
- [x] Exibir indicador visual na lista de produtos
- [x] Validar ao salvar produto
- [x] Carregar campos ao editar produto
- [x] Atualizar interfaces TypeScript
- [x] Salvar campos no Firebase

**Implementado em:** 31/01/2026  
**Commit:** `79e7f19` - "feat: Implementar Produtos Somente Retirada (Pickup Only)"  
**Arquivos modificados:**
- `client/src/components/ProductsTab.tsx` (UI + lógica)

### **Testes**
- [ ] Testar criação de produto com pickupOnly
- [ ] Testar pedido pickup com produto pickupOnly (ACEITAR)
- [ ] Testar pedido delivery com produto pickupOnly (REJEITAR)
- [ ] Testar pedido misto (pickup + normal)
- [ ] Testar UI do Flutter (desabilitação de opção)

---

## 🎯 Próximos Passos

1. ✅ ~~**Implementar no Painel Admin**~~ - **CONCLUÍDO (31/01/2026)**
2. **Implementar no Backend** (validação crítica) - PRÓXIMO
3. **Implementar no Flutter** (UX/UI)
4. **Testar end-to-end**
5. **Deploy gradual** (feature flag opcional)

---

## 📦 Implementação Realizada - Painel Admin

### **O que foi implementado:**

#### **1. Interface do Formulário (ProductsTab.tsx)**
- ✅ Card com borda laranja (`border-orange-200 bg-orange-50/50`)
- ✅ Ícone de pacote (`Package` do lucide-react)
- ✅ Switch "Somente Retirada no Local"
- ✅ Descrição clara: "Produto NÃO pode ser entregue a domicílio"
- ✅ Campo de motivo (opcional) que aparece condicionalmente
- ✅ Placeholder sugestivo: "Ex: Exige verificação de documento (18+), Produto frágil, etc."
- ✅ Feedback visual: "Este motivo será exibido para o cliente no app"

**Localização:** Após grid de preço/categoria, antes do card de Multimarcas

#### **2. Persistência de Dados**
- ✅ Campos salvos no Firebase ao criar produto:
  - `pickupOnly: boolean`
  - `pickupOnlyReason: string | null`
- ✅ Campos carregados ao editar produto
- ✅ Campos limpos ao resetar formulário
- ✅ Mapeamento correto em ambos carregamentos (inicial + loadMore)

#### **3. Badge Visual na Lista**
- ✅ Badge laranja com emoji 🏪
- ✅ Texto: "Somente Retirada"
- ✅ Classe: `bg-orange-500 hover:bg-orange-600 text-white`
- ✅ Aparece ao lado dos badges "Disponível/Indisponível"
- ✅ Usa `flex-wrap` para responsividade

**Código:**
```tsx
{(product as any).pickupOnly && (
  <Badge className="bg-orange-500 hover:bg-orange-600 text-white">
    🏪 Somente Retirada
  </Badge>
)}
```

#### **4. Interfaces TypeScript Atualizadas**

**Product:**
```typescript
interface Product {
  // ... campos existentes
  pickupOnly?: boolean;
  pickupOnlyReason?: string;
}
```

**ProductFormData:**
```typescript
interface ProductFormData {
  // ... campos existentes
  pickupOnly: boolean;
  pickupOnlyReason: string;
}
```

#### **5. Como Usar (Painel Admin)**
1. Acesse: Dashboard → Produtos
2. Clique em "Adicionar Produto" ou edite um existente
3. Role até a seção laranja "Somente Retirada no Local"
4. Ative o switch
5. (Opcional) Adicione um motivo no campo que aparece
6. Salve o produto
7. Veja o badge 🏪 na lista de produtos

---

## 📝 Notas Importantes
## 📝 Notas Importantes

- ✅ **Compatibilidade**: Produtos antigos terão `pickupOnly: false` por padrão
- ⚠️ **Validação obrigatória**: Backend SEMPRE deve validar (nunca confiar apenas no app)
- 🔒 **Segurança**: Impedir burlar via API direta (validação server-side)
- 📱 **UX**: Badge aparece APENAS na página de detalhes, não nos cards da home
- 🎯 **Localização dos Badges**:
  - ❌ **NÃO** aparece nos cards da home/listagem
  - ✅ **SIM** aparece na página de detalhes do produto (em cima da imagem)
  - ✅ **SIM** na página "Como quer receber?" (aviso + desabilitar delivery)
- 🎨 **Design**: Badge laranja com ícone de loja (🏪), sombra para destaque sobre imagem
- 🔤 **Nomenclatura**:
  - **Cliente vê**: "Consumo no local" (mais amigável)
  - **API recebe**: `method: 'pickup'` (valor técnico, mesma lógica existente)
  - **Sem mudanças na API**: Usa validação de `pickup` que já existe

---

**Documento criado em:** 31/01/2026  
**Última atualização:** 31/01/2026  
**Versão:** 1.2  
**Status:** 🚧 Implementação Parcial
- ✅ Painel Admin: **CONCLUÍDO**
- ⏳ Backend: **PENDENTE**
- ⏳ Flutter App: **PENDENTE**
