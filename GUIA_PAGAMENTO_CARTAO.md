# 💳 Guia de Implementação - Pagamento com Cartão no Flutter

## 🎯 Objetivo

Implementar captura de dados de cartão de crédito/débito no app Flutter do PedeJá com tokenização segura via SDK do Mercado Pago e processamento de pagamento com split automático.

---

## ⚙️ Credenciais - Mercado Pago

### **Public Key (Para usar no Flutter)**
```
APP_USR-6a4168d2-ffa3-44f5-8719-208361af3696
```

⚠️ **ATENÇÃO:** Esta é a **Public Key** e pode ser exposta no código do app. Ela é usada apenas para tokenização no cliente.

### **Access Token (Já configurado no backend)**
O Access Token do restaurante já está armazenado no Firestore e é usado pelo backend para processar pagamentos.

---

## 📦 1. Instalação de Dependências

### **pubspec.yaml**
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # SDK do Mercado Pago para tokenização
  mercadopago_sdk: ^2.0.0
  
  # Para requisições HTTP
  http: ^1.1.0
  
  # Para formatação de texto (opcional, mas recomendado)
  mask_text_input_formatter: ^2.5.0
  
  # Para validação de CPF (opcional)
  cpf_cnpj_validator: ^2.0.0
```

Execute:
```bash
flutter pub get
```

---

## 🚀 2. Inicializar SDK do Mercado Pago

### **lib/main.dart**
```dart
import 'package:flutter/material.dart';
import 'package:mercadopago_sdk/mercadopago_sdk.dart';

void main() {
  // ⚠️ INICIALIZAR COM A PUBLIC KEY
  MercadoPago.initialize('APP_USR-6a4168d2-ffa3-44f5-8719-208361af3696');
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PedeJá',
      theme: ThemeData(primarySwatch: Colors.orange),
      home: HomeScreen(),
    );
  }
}
```

---

## 💳 3. Criar Tela de Pagamento com Cartão

### **lib/screens/card_payment_screen.dart**
```dart
import 'package:flutter/material.dart';
import 'package:mercadopago_sdk/mercadopago_sdk.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CardPaymentScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final String userToken;
  final String userEmail;

  const CardPaymentScreen({
    Key? key,
    required this.orderId,
    required this.totalAmount,
    required this.userToken,
    required this.userEmail,
  }) : super(key: key);

  @override
  _CardPaymentScreenState createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores de texto
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _cvvController = TextEditingController();
  final _expirationController = TextEditingController();
  final _cpfController = TextEditingController();
  
  // Máscaras de formatação
  final _cardNumberMask = MaskTextInputFormatter(
    mask: '#### #### #### ####',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  final _expirationMask = MaskTextInputFormatter(
    mask: '##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  final _cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
  );
  
  bool _isProcessing = false;
  String? _cardBrand;
  int _installments = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pagamento com Cartão'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card com valor
              _buildAmountCard(),
              SizedBox(height: 24),
              
              // Número do cartão
              _buildCardNumberField(),
              SizedBox(height: 16),
              
              // Nome no cartão
              _buildCardHolderField(),
              SizedBox(height: 16),
              
              // Validade e CVV
              Row(
                children: [
                  Expanded(child: _buildExpirationField()),
                  SizedBox(width: 12),
                  Expanded(child: _buildCvvField()),
                ],
              ),
              SizedBox(height: 16),
              
              // CPF do titular
              _buildCpfField(),
              SizedBox(height: 16),
              
              // Parcelas
              _buildInstallmentsDropdown(),
              SizedBox(height: 32),
              
              // Botão de pagamento
              _buildPaymentButton(),
              SizedBox(height: 16),
              
              // Informações de segurança
              _buildSecurityInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Card(
      elevation: 4,
      color: Colors.orange,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Valor Total',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'R\$ ${widget.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardNumberField() {
    return TextFormField(
      controller: _cardNumberController,
      inputFormatters: [_cardNumberMask],
      decoration: InputDecoration(
        labelText: 'Número do Cartão',
        hintText: '0000 0000 0000 0000',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.credit_card),
        suffixIcon: _cardBrand != null
            ? Padding(
                padding: EdgeInsets.all(8),
                child: Image.asset(
                  'assets/card_brands/$_cardBrand.png',
                  height: 24,
                  errorBuilder: (_, __, ___) => Icon(Icons.credit_card),
                ),
              )
            : null,
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) => _identifyCardBrand(value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Digite o número do cartão';
        }
        if (value.replaceAll(' ', '').length < 13) {
          return 'Número do cartão inválido';
        }
        return null;
      },
    );
  }

  Widget _buildCardHolderField() {
    return TextFormField(
      controller: _cardHolderController,
      decoration: InputDecoration(
        labelText: 'Nome no Cartão',
        hintText: 'NOME COMPLETO',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.person),
      ),
      textCapitalization: TextCapitalization.characters,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Digite o nome no cartão';
        }
        if (!value.contains(' ')) {
          return 'Digite nome e sobrenome';
        }
        return null;
      },
    );
  }

  Widget _buildExpirationField() {
    return TextFormField(
      controller: _expirationController,
      inputFormatters: [_expirationMask],
      decoration: InputDecoration(
        labelText: 'Validade',
        hintText: 'MM/AAAA',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.calendar_today),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Data de validade';
        }
        if (value.length < 7) {
          return 'MM/AAAA';
        }
        
        final parts = value.split('/');
        final month = int.tryParse(parts[0]) ?? 0;
        final year = int.tryParse(parts[1]) ?? 0;
        
        if (month < 1 || month > 12) {
          return 'Mês inválido';
        }
        
        if (year < DateTime.now().year) {
          return 'Cartão expirado';
        }
        
        return null;
      },
    );
  }

  Widget _buildCvvField() {
    return TextFormField(
      controller: _cvvController,
      decoration: InputDecoration(
        labelText: 'CVV',
        hintText: '123',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.lock),
      ),
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'CVV';
        }
        if (value.length < 3) {
          return 'Inválido';
        }
        return null;
      },
    );
  }

  Widget _buildCpfField() {
    return TextFormField(
      controller: _cpfController,
      inputFormatters: [_cpfMask],
      decoration: InputDecoration(
        labelText: 'CPF do Titular',
        hintText: '000.000.000-00',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.badge),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Digite o CPF';
        }
        if (value.replaceAll(RegExp(r'[.-]'), '').length != 11) {
          return 'CPF inválido';
        }
        return null;
      },
    );
  }

  Widget _buildInstallmentsDropdown() {
    return DropdownButtonFormField<int>(
      value: _installments,
      decoration: InputDecoration(
        labelText: 'Parcelas',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: Icon(Icons.payments),
      ),
      items: List.generate(12, (index) {
        final installment = index + 1;
        final installmentAmount = widget.totalAmount / installment;
        return DropdownMenuItem(
          value: installment,
          child: Text(
            '$installment x R\$ ${installmentAmount.toStringAsFixed(2)}',
          ),
        );
      }),
      onChanged: (value) {
        setState(() => _installments = value ?? 1);
      },
    );
  }

  Widget _buildPaymentButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _processPayment,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.orange,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isProcessing
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              'Pagar R\$ ${widget.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildSecurityInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock, size: 16, color: Colors.grey),
        SizedBox(width: 8),
        Text(
          'Pagamento seguro via Mercado Pago',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  // Identificar bandeira do cartão
  void _identifyCardBrand(String value) async {
    final cleanNumber = value.replaceAll(' ', '');
    if (cleanNumber.length >= 6) {
      try {
        final mp = MercadoPago();
        final paymentMethod = await mp.getPaymentMethodByBin(cleanNumber.substring(0, 6));
        setState(() {
          _cardBrand = paymentMethod?.id;
        });
      } catch (e) {
        print('Erro ao identificar bandeira: $e');
      }
    }
  }

  // Processar pagamento
  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      // 1. TOKENIZAR CARTÃO (SDK do Mercado Pago)
      print('🔐 Tokenizando cartão...');
      final mp = MercadoPago();
      
      final expirationParts = _expirationController.text.split('/');
      final cardToken = await mp.createCardToken(
        cardNumber: _cardNumberController.text.replaceAll(' ', ''),
        expirationMonth: int.parse(expirationParts[0]),
        expirationYear: int.parse(expirationParts[1]),
        securityCode: _cvvController.text,
        cardholderName: _cardHolderController.text,
        identificationType: 'CPF',
        identificationNumber: _cpfController.text.replaceAll(RegExp(r'[.-]'), ''),
      );

      print('✅ Token gerado: ${cardToken.id}');

      // 2. ENVIAR TOKEN PARA SEU BACKEND
      print('📡 Enviando para backend...');
      final response = await http.post(
        Uri.parse('https://api-pedeja.vercel.app/api/payments/mp/create-direct'),
        headers: {
          'Authorization': 'Bearer ${widget.userToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'orderId': widget.orderId,
          'paymentMethodId': _cardBrand ?? 'credit_card',
          'token': cardToken.id,
          'installments': _installments,
          'payerEmail': widget.userEmail,
          'identificationType': 'CPF',
          'identificationNumber': _cpfController.text.replaceAll(RegExp(r'[.-]'), ''),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // ✅ PAGAMENTO APROVADO
        print('✅ Pagamento aprovado!');
        
        _showSuccessDialog();
        
        // Aguardar 2 segundos e voltar para home
        await Future.delayed(Duration(seconds: 2));
        Navigator.of(context).popUntil((route) => route.isFirst);
        
      } else {
        // ❌ ERRO NO PAGAMENTO
        final errorMsg = data['error'] ?? 'Erro ao processar pagamento';
        print('❌ Erro: $errorMsg');
        _showErrorDialog(errorMsg);
      }

    } catch (e) {
      print('❌ Exceção: $e');
      _showErrorDialog('Erro ao processar pagamento: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Pagamento Aprovado!'),
          ],
        ),
        content: Text('Seu pedido foi confirmado e já está sendo preparado.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Erro no Pagamento'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _cvvController.dispose();
    _expirationController.dispose();
    _cpfController.dispose();
    super.dispose();
  }
}
```

---

## 🔄 4. Integrar na Tela de Checkout

### **lib/screens/checkout_screen.dart**
```dart
// Na tela onde o usuário escolhe a forma de pagamento:

void _selectPaymentMethod(String method) {
  if (method == 'credit_card' || method == 'debit_card') {
    // Navegar para tela de cartão
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardPaymentScreen(
          orderId: _currentOrderId,
          totalAmount: _calculateTotal(),
          userToken: _getUserToken(), // Pegar do SharedPreferences/SecureStorage
          userEmail: _getUserEmail(), // Pegar do usuário logado
        ),
      ),
    );
  } else if (method == 'pix') {
    // Já implementado - gerar QR Code PIX
    _generatePixPayment();
  } else if (method == 'cash') {
    // Pagamento na entrega
    _confirmCashPayment();
  }
}
```

---

## 🧪 5. Cartões de Teste

Para testar **SEM cobrar de verdade**, use estes cartões:

### **Cartões que APROVAM:**
| Bandeira | Número | CVV | Validade | Nome |
|----------|--------|-----|----------|------|
| Visa | `4509 9535 6623 3704` | 123 | 11/2025 | APRO |
| Mastercard | `5031 4332 1540 6351` | 123 | 11/2025 | APRO |
| Elo | `6362 9701 2384 5678` | 123 | 11/2025 | APRO |

### **Cartões que RECUSAM (para testar erro):**
| Bandeira | Número | CVV | Validade | Nome | Erro |
|----------|--------|-----|----------|------|------|
| Visa | `4235 6477 2802 5682` | 123 | 11/2025 | CALL | Saldo insuficiente |
| Mastercard | `5031 7557 3453 0604` | 123 | 11/2025 | OTHE | Genérico |

**CPF para teste:** `123.456.789-00`

---

## 🔐 6. Segurança - PCI Compliance

✅ **O que você NÃO precisa fazer:**
- ❌ Não precisa de certificação PCI-DSS
- ❌ Não precisa criptografar dados do cartão
- ❌ Não precisa de servidor seguro para cartões

✅ **O que o SDK do Mercado Pago faz:**
- ✅ Tokeniza o cartão no dispositivo
- ✅ Usa criptografia end-to-end
- ✅ É certificado PCI-DSS Level 1
- ✅ Nunca expõe dados sensíveis

**Regra de Ouro:** Nunca envie dados do cartão para seu backend. **Apenas o token!**

---

## 📊 7. Fluxo de Pagamento

```
┌─────────────┐
│   Flutter   │
│     App     │
└──────┬──────┘
       │ 1. Usuário preenche cartão
       ▼
┌─────────────┐
│  Mercado    │
│  Pago SDK   │
└──────┬──────┘
       │ 2. Tokeniza cartão (no dispositivo)
       ▼
┌─────────────┐
│  Backend    │
│   PedeJá    │
└──────┬──────┘
       │ 3. Processa com Access Token do restaurante
       ▼
┌─────────────┐
│  Mercado    │
│   Pago API  │
└──────┬──────┘
       │ 4. Split: 85% restaurante + 15% plataforma
       ▼
┌─────────────┐
│   Webhook   │
│  Confirmação│
└──────┬──────┘
       │ 5. Atualiza pedido → "preparing"
       ▼
┌─────────────┐
│  Firestore  │
└─────────────┘
```

---

## ✅ Checklist de Implementação

- [ ] Adicionar `mercadopago_sdk: ^2.0.0` no `pubspec.yaml`
- [ ] Inicializar SDK com Public Key no `main.dart`
- [ ] Criar `card_payment_screen.dart`
- [ ] Adicionar máscaras de formatação (opcional)
- [ ] Integrar na tela de checkout
- [ ] Testar com cartões de teste
- [ ] Validar fluxo completo:
  - [ ] Tokenização funciona
  - [ ] Backend recebe token
  - [ ] Pagamento é aprovado
  - [ ] Webhook atualiza pedido
  - [ ] Split de 85/15 é aplicado
- [ ] Testar cenários de erro (cartão recusado)
- [ ] Adicionar loading states
- [ ] Implementar tratamento de erros
- [ ] Testar em produção com cartão real

---

## 📞 Suporte

**Documentação Mercado Pago:**
- SDK Flutter: https://github.com/mercadopago/sdk-flutter
- API Checkout: https://www.mercadopago.com.br/developers/pt/docs/checkout-api/integration-configuration
- Cartões de Teste: https://www.mercadopago.com.br/developers/pt/docs/checkout-api/testing

**Painel Mercado Pago:**
- Dashboard: https://www.mercadopago.com.br/developers/panel
- Credenciais: https://www.mercadopago.com.br/developers/panel/credentials

---

## 🚀 Resultado Final

Após a implementação, o app terá:

✅ Formulário completo de cartão
✅ Tokenização segura (PCI compliant)
✅ Suporte a parcelas (1x a 12x)
✅ Identificação automática da bandeira
✅ Validação de campos
✅ Split automático de pagamento
✅ Feedback visual (loading, sucesso, erro)
✅ Integração com backend existente

**A API já está pronta! Só falta implementar a interface no Flutter.** 🎉
