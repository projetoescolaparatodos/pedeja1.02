# 🎯 Flutter - Como Mostrar Taxa de Entrega Dinâmica

## 📋 Contexto

A API agora retorna dois campos para taxa de entrega:
- **`deliveryFee`**: Taxa total (o que o entregador recebe). Ex: R$ 3,00
- **`customerDeliveryFee`**: Taxa que o cliente paga (modo parcial). Ex: R$ 1,50

Quando o restaurante usa **modo parcial**, ele subsidia a diferença:
- Cliente paga: R$ 1,50 (`customerDeliveryFee`)
- Entregador recebe: R$ 3,00 (`deliveryFee`)
- Restaurante subsidia: R$ 1,50 (diferença)

## ✅ Solução Implementada na API

### Endpoint: `GET /api/mobile/restaurants/:id`

**Retorna agora:**
```json
{
  "id": "rest123",
  "name": "Pizza Place",
  "deliveryFee": 3.0,           // Taxa total (sempre presente)
  "customerDeliveryFee": 1.5,   // Taxa que cliente paga (pode ser null)
  "minimumOrder": 20,
  ...
}
```

### Endpoint: `POST /api/orders`

**Prioriza automaticamente:**
1. Se app enviar `deliveryFee` no body → usa esse valor
2. Se não, verifica `customerDeliveryFee` do restaurante → **usa esse (NOVO)**
3. Se não, usa `deliveryFee` do restaurante → fallback
4. Se nenhum, usa R$ 0,00

## 🎨 Como Implementar no Flutter

### Lógica Simples (Recomendado)

```dart
class Restaurant {
  final String id;
  final String name;
  final double deliveryFee;          // Taxa total
  final double? customerDeliveryFee; // Taxa que cliente paga (opcional)
  
  // Getter para obter a taxa que será exibida/cobrada
  double get displayDeliveryFee {
    return customerDeliveryFee ?? deliveryFee;
  }
  
  // Se quiser saber se está em modo parcial
  bool get isPartialDeliveryMode {
    return customerDeliveryFee != null && customerDeliveryFee! < deliveryFee;
  }
  
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      customerDeliveryFee: (json['customerDeliveryFee'] as num?)?.toDouble(),
      ...
    );
  }
}
```

### Uso na Interface

```dart
// No card do restaurante ou checkout
Text('Taxa de entrega: ${restaurant.displayDeliveryFee.toStringAsFixed(2)}')

// Se quiser mostrar que é subsidiado
if (restaurant.isPartialDeliveryMode) {
  Text(
    'Taxa subsidiada pelo restaurante!',
    style: TextStyle(color: Colors.green, fontSize: 12),
  )
}

// No cálculo do total
double calculateTotal() {
  final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.price);
  final delivery = restaurant.displayDeliveryFee;
  return subtotal + delivery;
}
```

### Exemplo Completo - Tela de Checkout

```dart
class CheckoutScreen extends StatelessWidget {
  final Restaurant restaurant;
  final List<CartItem> items;
  
  @override
  Widget build(BuildContext context) {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final deliveryFee = restaurant.displayDeliveryFee;
    final total = subtotal + deliveryFee;
    
    return Column(
      children: [
        // Items do carrinho
        ...items.map((item) => CartItemWidget(item)),
        
        Divider(),
        
        // Resumo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Subtotal'),
            Text('R\$ ${subtotal.toStringAsFixed(2)}'),
          ],
        ),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Taxa de entrega'),
                if (restaurant.isPartialDeliveryMode)
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.discount,
                      size: 16,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
            Text('R\$ ${deliveryFee.toStringAsFixed(2)}'),
          ],
        ),
        
        if (restaurant.isPartialDeliveryMode)
          Padding(
            padding: EdgeInsets.only(left: 16, top: 4),
            child: Text(
              'Restaurante está subsidiando R\$ ${(restaurant.deliveryFee - restaurant.customerDeliveryFee!).toStringAsFixed(2)}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        
        Divider(),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'R\$ ${total.toStringAsFixed(2)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ],
    );
  }
}
```

## 🔄 Ao Criar o Pedido

**IMPORTANTE:** Não envie `deliveryFee` no body do POST. Deixe a API decidir automaticamente:

```dart
Future<Order> createOrder(Order order) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/orders'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'restaurantId': order.restaurantId,
      'customerId': order.customerId,
      'items': order.items.map((i) => i.toJson()).toList(),
      'deliveryAddress': order.deliveryAddress.toJson(),
      'payment': order.payment.toJson(),
      // NÃO enviar deliveryFee - API decide automaticamente
      // deliveryFee: restaurant.displayDeliveryFee, ❌ NÃO FAZER
    }),
  );
  
  return Order.fromJson(jsonDecode(response.body));
}
```

**Por quê não enviar?** A API agora prioriza automaticamente:
1. `customerDeliveryFee` (se configurado)
2. `deliveryFee` (fallback)

Se você enviar manualmente, pode sobrescrever essa lógica.

## 📊 Cenários de Uso

### Cenário 1: Restaurante Modo Completo
```json
{
  "deliveryFee": 3.0,
  "customerDeliveryFee": null
}
```
**Flutter mostra:** R$ 3,00 (sem subsídio)

### Cenário 2: Restaurante Modo Parcial
```json
{
  "deliveryFee": 3.0,
  "customerDeliveryFee": 1.5
}
```
**Flutter mostra:** R$ 1,50 (com ícone de desconto/subsídio)

### Cenário 3: Restaurante sem Taxa
```json
{
  "deliveryFee": 0,
  "customerDeliveryFee": null
}
```
**Flutter mostra:** Frete grátis! 🎉

## ✅ Checklist de Implementação

- [ ] Adicionar campo `customerDeliveryFee` no modelo `Restaurant`
- [ ] Criar getter `displayDeliveryFee` para simplificar uso
- [ ] Atualizar UI para usar `displayDeliveryFee` ao invés de `deliveryFee` direto
- [ ] (Opcional) Mostrar badge "Subsidiado" quando `isPartialDeliveryMode == true`
- [ ] **IMPORTANTE:** Remover envio de `deliveryFee` no POST /orders (deixar API decidir)
- [ ] Testar com restaurantes em modo completo e parcial

## 🎯 Resumo

**Uma linha para resolver tudo:**

```dart
// Sempre use isso ao invés de restaurant.deliveryFee
final taxaQueClientePaga = restaurant.customerDeliveryFee ?? restaurant.deliveryFee;
```

Ou melhor ainda, use o getter:

```dart
final taxaQueClientePaga = restaurant.displayDeliveryFee;
```

Pronto! 🚀
