# 📱 PedeJá - Documentação Completa do Projeto

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Histórico de Desenvolvimento](#histórico-de-desenvolvimento)
3. [Arquitetura do Sistema](#arquitetura-do-sistema)
4. [Funcionalidades Implementadas](#funcionalidades-implementadas)
5. [Estrutura de Código](#estrutura-de-código)
6. [Guia de Uso](#guia-de-uso)
7. [Próximos Passos](#próximos-passos)

---

## 🎯 Visão Geral

**PedeJá** é um aplicativo de delivery de comida desenvolvido em Flutter, permitindo que usuários:
- Naveguem por restaurantes e produtos
- Adicionem itens ao carrinho com personalização (adicionais)
- Completem seu cadastro antes de finalizar pedidos
- Realizem autenticação (login/cadastro)

### 🛠️ Tecnologias Utilizadas
- **Framework**: Flutter (Web + Mobile)
- **Linguagem**: Dart
- **Gerenciamento de Estado**: Provider
- **API Backend**: https://api-pedeja.vercel.app
- **Plataformas**: Android, Web (Chrome)

### 🎨 Paleta de Cores
- **Verde Escuro**: `#022E28` - Background principal
- **Vinho**: `#74241F` - Botões primários
- **Vinho Escuro**: `#5A1C18` - Hover states
- **Dourado**: `#E39110` - Destaques e CTAs
- **Verde Musgo**: `#0D3B3B` - Componentes secundários

---

## 📖 Histórico de Desenvolvimento

### Fase 1: Estrutura Inicial (Mensagens 1-10)
**Objetivo**: Criar a base do aplicativo com catálogo de produtos e restaurantes

#### 1.1 Criação do Projeto
```bash
flutter create pedeja_clean
cd pedeja_clean
```

#### 1.2 Implementação de Modelos de Dados
**Arquivos Criados**:
- `lib/models/product_model.dart` - Modelo de Produto
- `lib/models/restaurant_model.dart` - Modelo de Restaurante

**Estrutura Product**:
```dart
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final String restaurantId;
  final String restaurantName; // Adicionado posteriormente
  final List<Addon> addons;
}

class Addon {
  final String name;
  final double price;
}
```

**Estrutura Restaurant**:
```dart
class Restaurant {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final double rating;
  final int deliveryTime;
  final double deliveryFee;
}
```

#### 1.3 Gerenciamento de Estado com Provider
**Arquivo**: `lib/state/catalog_state.dart`

**Funcionalidades**:
- Carregamento de produtos da API
- Carregamento de restaurantes da API
- Filtragem por categoria
- Logs detalhados de debug

```dart
class CatalogProvider with ChangeNotifier {
  Future<void> loadProducts();
  Future<void> loadRestaurants();
  void setSelectedCategory(String category);
}
```

#### 1.4 Criação do Theme System
**Arquivo**: `lib/core/theme/app_theme.dart`

**Características**:
- Dark theme personalizado
- Cores consistentes com identidade visual
- Typography personalizada
- Componentes reutilizáveis

#### 1.5 Tela Principal (HomePage)
**Arquivo**: `lib/pages/home/home_page.dart` (1228 linhas)

**Componentes**:
- **Header**: Logo, busca, badge do carrinho
- **Categorias**: ScrollView horizontal com categorias
- **Produtos em Destaque**: Grid de produtos
- **Restaurantes Parceiros**: Lista de restaurantes
- **Drawer**: Menu lateral com opções

**Features Especiais**:
- Animações de scroll (logo aparecer/desaparecer)
- Cache de imagens
- Navegação fluida
- Integração com CartState

### Fase 2: Sistema de Carrinho de Compras (Mensagens 11-25)
**Objetivo**: Implementar carrinho completo com state management

#### 2.1 Modelo CartItem
**Arquivo**: `lib/models/cart_item.dart` (52 linhas)

**Estrutura**:
```dart
class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  int quantity;
  final List<Addon> addons;
  final String restaurantId;
  final String restaurantName;
  
  double get totalPrice; // Preço * quantidade + addons
  String get addonsDescription; // Lista formatada de addons
}
```

#### 2.2 CartState Provider
**Arquivo**: `lib/state/cart_state.dart` (130 linhas)

**Métodos Principais**:
```dart
class CartState with ChangeNotifier {
  void addItem(CartItem item); // Detecta duplicatas e atualiza quantidade
  void updateItemQuantity(String id, int quantity);
  void removeItem(String id);
  void clear();
  
  int get itemCount; // Total de itens
  double get total; // Valor total do carrinho
}
```

**Funcionalidade de Detecção de Duplicatas**:
- Verifica se produto + addons já existe
- Se existe: incrementa quantidade
- Se não: adiciona novo item

#### 2.3 Interface do Carrinho
**Arquivo**: `lib/pages/cart/cart_page.dart` (578 linhas)

**Design Pattern**: DraggableScrollableSheet
- **initialChildSize**: 0.9 (90% da tela)
- **minChildSize**: 0.5 (50% da tela)
- **maxChildSize**: 0.95 (95% da tela)

**Componentes**:
1. **Header**: Título "Carrinho" + botão fechar
2. **Lista de Itens**: 
   - Imagem do produto
   - Nome + restaurante
   - Addons (se houver)
   - Controles de quantidade (+/-)
   - Preço unitário e total
   - Botão remover
3. **Resumo**: 
   - Subtotal
   - Taxa de entrega
   - Total geral
4. **Botão Checkout**: "Finalizar Pedido" com validação

#### 2.4 Integração ProductDetailPage
**Arquivo**: `lib/pages/product/product_detail_page.dart`

**Adições**:
- Badge do carrinho no header
- Seleção de addons com checkboxes
- Botão "Adicionar ao Carrinho" que chama `CartState.addItem()`
- Feedback visual ao adicionar

#### 2.5 Integração HomePage
**Adições**:
- Badge do carrinho no header com `Consumer<CartState>`
- Contador de itens atualizado em tempo real
- Botão de carrinho que abre `CartPage.show()`

#### 2.6 Controle de Qualidade
**Comandos Executados**:
```bash
flutter analyze  # Verificação de código
# Resultado: No issues found! ✅
```

**Correções Feitas**:
- Removido imports não utilizados
- Corrigido variáveis não utilizadas
- Tornado `_items` final em CartState

#### 2.7 Versionamento Git
**Commit**: `ec37e4b`
```bash
git add .
git commit -m "feat: implementar sistema completo de carrinho de compras"
git push origin main
```

**Arquivos Modificados**:
- `lib/models/cart_item.dart` (novo)
- `lib/state/cart_state.dart` (novo)
- `lib/pages/cart/cart_page.dart` (novo)
- `lib/main.dart` (atualizado MultiProvider)
- `lib/pages/home/home_page.dart` (badge carrinho)
- `lib/pages/product/product_detail_page.dart` (integração)
- `lib/models/product_model.dart` (campo restaurantName)

### Fase 3: Sistema de Autenticação (Mensagens 26-40)
**Objetivo**: Criar telas de login, cadastro e onboarding

#### 3.1 Migração de Assets
**Origem**: Projeto `pede_ja_v_t_x` (FlutterFlow)

**Assets Copiados**:
```
assets/images/
  ├── logo-pede-ja.png
  ├── Img.png        # Onboarding 1
  ├── Img_(1).png    # Onboarding 2
  ├── Img_(2).png    # Onboarding 3
  └── [outros assets...]
```

**Atualização**: `pubspec.yaml`
```yaml
flutter:
  assets:
    - assets/images/
```

#### 3.2 Tela de Onboarding
**Arquivo**: `lib/pages/onboarding/onboarding_page.dart` (233 linhas)

**Estrutura**:
- **PageController**: Controla navegação entre slides
- **3 Slides**: 
  1. Slide 1: Apresentação do app
  2. Slide 2: Funcionalidades
  3. Slide 3: Call-to-action

**Componentes**:
```dart
class OnboardingItem {
  final String image;
  final String title;
  final String description;
}
```

**Features**:
- Indicadores de página animados
- Botão "Pular" no topo direito
- Botão "Próximo" / "Começar" dinâmico
- Navegação para LoginPage ao finalizar

#### 3.3 Tela de Login
**Arquivo**: `lib/pages/auth/login_page.dart` (293 linhas)

**Campos**:
- Email (com validação)
- Senha (obscureText)

**Funcionalidades**:
- Validação de formulário
- Loading state durante login
- Link "Esqueceu senha?" (placeholder)
- Link "Cadastre-se" → SignupPage
- Simulação de login (2s delay)
- Navegação para HomePage após sucesso

**Validações**:
```dart
validator: (value) {
  if (value == null || value.isEmpty) {
    return 'Por favor, insira seu email';
  }
  if (!value.contains('@')) {
    return 'Email inválido';
  }
  return null;
}
```

#### 3.4 Tela de Cadastro
**Arquivo**: `lib/pages/auth/signup_page.dart` (346 linhas)

**Campos**:
1. Nome completo
2. Email
3. Telefone
4. Senha
5. Confirmar senha
6. Checkbox: Aceitar termos

**Validações**:
- Todos os campos obrigatórios
- Email deve conter @
- Senhas devem coincidir
- Termos devem ser aceitos

**Fluxo**:
```dart
_handleSignup() {
  // 1. Valida formulário
  if (!_formKey.currentState!.validate()) return;
  
  // 2. Verifica termos
  if (!_acceptTerms) {
    showSnackBar("Você precisa aceitar os termos");
    return;
  }
  
  // 3. Mostra loading
  setState(() => _loading = true);
  
  // 4. Simula cadastro (2s)
  await Future.delayed(Duration(seconds: 2));
  
  // 5. Navega para HomePage
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => HomePage()),
    (route) => false,
  );
}
```

#### 3.5 Atualização do Main
**Arquivo**: `lib/main.dart`

**Mudanças**:
- `home: const OnboardingPage()` (antes era HomePage)
- Fluxo: Onboarding → Login → HomePage
- Ou: Onboarding → Signup → HomePage

### Fase 4: Sistema de Validação de Perfil (Mensagens 41-60)
**Objetivo**: Garantir cadastro completo antes do checkout

#### 4.1 UserState Provider
**Arquivo**: `lib/state/user_state.dart` (125 linhas)

**Estrutura de Dados**:
```dart
Map<String, dynamic>? userData = {
  'name': String?,
  'phone': String?,
  'address': {
    'zipCode': String?,
    'street': String?,
    'number': String?,
    'complement': String?,
    'neighborhood': String?,
    'city': String?,
    'state': String?,
  }
}
```

**Validação de Completude**:
```dart
bool get isProfileComplete {
  if (userData == null) return false;
  
  // Valida nome
  final name = userData!['name'];
  if (name == null || name.trim().isEmpty) return false;
  
  // Valida telefone
  final phone = userData!['phone'];
  if (phone == null || phone.trim().isEmpty) return false;
  
  // Valida endereço completo
  final address = userData!['address'];
  if (address == null || address is! Map) return false;
  
  final requiredFields = [
    'street', 'number', 'neighborhood', 
    'city', 'state', 'zipCode'
  ];
  
  for (var field in requiredFields) {
    if (address[field] == null || 
        address[field].toString().trim().isEmpty) {
      return false;
    }
  }
  
  return true;
}
```

**Lista de Campos Faltantes**:
```dart
List<String> get missingFields {
  List<String> missing = [];
  
  if (userData == null) {
    return ['Nome completo', 'Telefone', 'Endereço completo'];
  }
  
  if (userData!['name']?.trim().isEmpty ?? true) {
    missing.add('Nome completo');
  }
  
  if (userData!['phone']?.trim().isEmpty ?? true) {
    missing.add('Telefone');
  }
  
  // Verifica cada campo do endereço...
  
  return missing;
}
```

**Métodos**:
- `loadUserData()`: Carrega dados do usuário (placeholder)
- `updateUserData(Map<String, dynamic>)`: Atualiza perfil
- `mockLogin()`: Simula login com dados vazios (para teste)

#### 4.2 Tela de Completar Perfil
**Arquivo**: `lib/pages/profile/complete_profile_page.dart` (511 linhas)

**Campos do Formulário**:
1. Nome completo
2. Telefone (com máscara)
3. CEP (com máscara)
4. Rua
5. Número
6. Complemento (opcional)
7. Bairro
8. Cidade
9. Estado (UF - 2 caracteres)

**Máscaras Customizadas**:

**1. PhoneMaskFormatter**:
```dart
class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(old, newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    if (text.isEmpty) return newValue.copyWith(text: '');
    
    String formatted = '(';
    if (text.length >= 1) formatted += text.substring(0, min(2, text.length));
    if (text.length >= 3) formatted += ') ${text.substring(2, min(7, text.length))}';
    if (text.length >= 8) formatted += '-${text.substring(7, min(11, text.length))}';
    
    // Resultado: (11) 91234-5678
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
```

**2. CepMaskFormatter**:
```dart
class _CepMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(old, newValue) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    if (text.isEmpty) return newValue.copyWith(text: '');
    
    String formatted = text.substring(0, min(5, text.length));
    if (text.length >= 6) formatted += '-${text.substring(5, min(8, text.length))}';
    
    // Resultado: 12345-678
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
```

**Carregamento de Dados**:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadUserData();
  });
}

void _loadUserData() {
  final userState = context.read<UserState>();
  final userData = userState.userData;
  
  if (userData != null) {
    setState(() {
      _nameController.text = userData['name'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      
      final address = userData['address'];
      if (address != null && address is Map) {
        _zipCodeController.text = address['zipCode'] ?? '';
        _streetController.text = address['street'] ?? '';
        // ... outros campos
      }
    });
  }
}
```

**Salvamento**:
```dart
Future<void> _saveProfile() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() => _loading = true);
  
  final userState = context.read<UserState>();
  
  await userState.updateUserData({
    'name': _nameController.text,
    'phone': _phoneController.text,
    'address': {
      'zipCode': _zipCodeController.text,
      'street': _streetController.text,
      'number': _numberController.text,
      'complement': _complementController.text,
      'neighborhood': _neighborhoodController.text,
      'city': _cityController.text,
      'state': _stateController.text,
    },
  });
  
  if (mounted) {
    Navigator.pop(context); // Volta para tela anterior
  }
}
```

#### 4.3 Validação no Checkout
**Arquivo**: `lib/pages/cart/cart_page.dart`

**Método _processCheckout**:
```dart
static Future<void> _processCheckout(BuildContext context) async {
  final userState = context.read<UserState>();
  
  // 1️⃣ CARREGA DADOS DO USUÁRIO
  if (userState.userData == null) {
    showDialog(/* CircularProgressIndicator */);
    await userState.mockLogin();
    Navigator.pop(context); // Fecha loading
  }
  
  if (!context.mounted) return;
  
  // 2️⃣ VALIDA PERFIL COMPLETO
  if (!userState.isProfileComplete) {
    // Fecha carrinho
    Navigator.pop(context);
    await Future.delayed(Duration(milliseconds: 100));
    
    // Mostra diálogo de aviso
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded),
            Text('Cadastro Incompleto'),
          ],
        ),
        content: Column(
          children: [
            Text('Para finalizar seu pedido, precisamos que você complete seu cadastro com:'),
            
            // Lista campos faltantes
            ...userState.missingFields.map((field) => 
              Row(
                children: [
                  Icon(Icons.circle, size: 6),
                  Text(field),
                ],
              )
            ),
            
            Text('Deseja completar agora?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Agora não'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Completar Cadastro'),
          ),
        ],
      ),
    );
    
    // 3️⃣ NAVEGA PARA FORMULÁRIO
    if (shouldProceed == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompleteProfilePage(),
        ),
      );
    }
    
    return; // Interrompe checkout
  }
  
  // 4️⃣ PROSSEGUE COM CHECKOUT
  Navigator.pop(context); // Fecha carrinho
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('✅ Processando pedido...'),
    ),
  );
}
```

**Botão de Checkout Atualizado**:
```dart
ElevatedButton(
  onPressed: () => _processCheckout(context),
  child: Text('Finalizar Pedido'),
)
```

#### 4.4 Menu de Teste
**Arquivo**: `lib/pages/home/home_page.dart`

**Item do Drawer**:
```dart
ListTile(
  leading: Icon(Icons.science, color: Color(0xFFE39110)),
  title: Text('🧪 Testar Cadastro'),
  onTap: () async {
    Navigator.pop(context); // Fecha drawer
    
    final userState = context.read<UserState>();
    await userState.mockLogin(); // Carrega dados vazios
    
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CompleteProfilePage(),
        ),
      );
    }
  },
)
```

#### 4.5 Integração no Main
**Arquivo**: `lib/main.dart`

**MultiProvider Atualizado**:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => CatalogProvider()),
    ChangeNotifierProvider(create: (_) => CartState()),
    ChangeNotifierProvider(create: (_) => UserState()), // ← Novo
  ],
  child: MaterialApp(
    title: 'PedeJá',
    theme: AppTheme.darkTheme,
    home: const OnboardingPage(),
  ),
)
```

### Fase 5: Correções de Bugs (Mensagens 61-70)
**Objetivo**: Resolver problemas de navegação e context

#### 5.1 Bug: CompleteProfilePage não abre
**Problema**: Dialog aparece mas página não navega

**Diagnóstico**:
1. `UserState.userData` estava null
2. `CompleteProfilePage._loadUserData()` tentava ler null
3. Navegação falhava silenciosamente

**Solução 1**: Adicionar loading antes de validação
```dart
// Em _processCheckout
if (userState.userData == null) {
  showDialog(
    barrierDismissible: false,
    builder: (ctx) => Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(Color(0xFFE39110)),
      ),
    ),
  );
  
  await userState.mockLogin();
  
  if (context.mounted) {
    Navigator.pop(context); // Fecha loading
  }
}
```

**Solução 2**: PostFrameCallback em CompleteProfilePage
```dart
@override
void initState() {
  super.initState();
  
  // Carrega dados após primeiro frame (evita erro de context)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadUserData();
  });
}
```

**Solução 3**: Debug logs
```dart
// Em _processCheckout
debugPrint('🚀 Navegando para CompleteProfilePage...');

await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CompleteProfilePage(),
  ),
);

debugPrint('🔙 Retornou de CompleteProfilePage');

// Em _loadUserData
debugPrint('📋 Carregando dados do usuário: $userData');
```

#### 5.2 Bug: Scaffold.of() context error
**Problema**: Erro ao abrir drawer na HomePage (linha 962)

**Erro**:
```
Scaffold.of() called with a context that does not contain a Scaffold.
```

**Solução**: Usar Builder para obter context correto
```dart
// ANTES (ERRO)
IconButton(
  onPressed: () {
    Scaffold.of(context).openDrawer(); // ❌ context errado
  },
)

// DEPOIS (CORRETO)
Builder(
  builder: (ctx) => IconButton(
    onPressed: () {
      Scaffold.of(ctx).openDrawer(); // ✅ context correto
    },
  ),
)
```

#### 5.3 Análise Estática
**Comandos**:
```bash
flutter analyze
# No issues found! ✅
```

**Verificações**:
- Imports não utilizados
- Variáveis não utilizadas
- Warnings de tipo
- Problemas de null-safety

---

## 🏗️ Arquitetura do Sistema

### Estrutura de Pastas
```
lib/
├── main.dart                    # Entry point + MultiProvider
├── core/
│   ├── constants/
│   │   └── api_constants.dart   # URLs da API
│   └── theme/
│       └── app_theme.dart       # Theme system
├── models/
│   ├── product_model.dart       # Product + Addon
│   ├── restaurant_model.dart    # Restaurant
│   └── cart_item.dart           # CartItem
├── state/
│   ├── catalog_state.dart       # CatalogProvider
│   ├── cart_state.dart          # CartState
│   └── user_state.dart          # UserState
└── pages/
    ├── onboarding/
    │   └── onboarding_page.dart
    ├── auth/
    │   ├── login_page.dart
    │   └── signup_page.dart
    ├── home/
    │   └── home_page.dart
    ├── product/
    │   └── product_detail_page.dart
    ├── restaurant/
    │   └── restaurant_detail_page.dart
    ├── cart/
    │   └── cart_page.dart
    └── profile/
        └── complete_profile_page.dart
```

### Fluxo de Dados (Provider)

```
┌─────────────────────────────────────┐
│         MultiProvider (main)        │
├─────────────────────────────────────┤
│  • CatalogProvider                  │
│    - products: List<Product>        │
│    - restaurants: List<Restaurant>  │
│    - selectedCategory: String       │
│                                      │
│  • CartState                         │
│    - _items: List<CartItem>         │
│    - itemCount: int                 │
│    - total: double                  │
│                                      │
│  • UserState                         │
│    - userData: Map<String, dynamic> │
│    - isProfileComplete: bool        │
│    - missingFields: List<String>    │
└─────────────────────────────────────┘
           ↓ Provider.of / Consumer
┌─────────────────────────────────────┐
│              Widgets                 │
│  • HomePage                          │
│  • ProductDetailPage                │
│  • CartPage                          │
│  • CompleteProfilePage              │
└─────────────────────────────────────┘
```

### Navegação entre Telas

```
OnboardingPage (3 slides)
    ↓ Skip / Finalizar
LoginPage
    ↓ Login Success           SignupPage
    ↓ ←─────────────────────────┘
HomePage
    ├→ ProductDetailPage → CartPage
    ├→ RestaurantDetailPage
    └→ CompleteProfilePage (via Drawer ou Checkout)

Checkout Flow:
CartPage → Clica "Finalizar Pedido"
    ↓ Valida perfil
    ├→ Se incompleto: Dialog → CompleteProfilePage
    └→ Se completo: Processa pedido
```

### API Integration

**Base URL**: `https://api-pedeja.vercel.app`

**Endpoints Utilizados**:
```dart
// CatalogProvider
GET /api/products           // Lista todos os produtos
GET /api/restaurants        // Lista todos os restaurantes

// Planejado (não implementado)
POST /api/auth/login        // Autenticação
POST /api/auth/signup       // Cadastro
POST /api/payments/mp/create-with-split  // Checkout
```

---

## ✨ Funcionalidades Implementadas

### 1. Catálogo de Produtos
- ✅ Carregamento de produtos da API
- ✅ Grid responsivo de produtos
- ✅ Filtro por categorias
- ✅ Scroll infinito
- ✅ Cache de imagens
- ✅ Loading states

### 2. Detalhes do Produto
- ✅ Imagem do produto
- ✅ Nome, descrição, preço
- ✅ Informações do restaurante
- ✅ Seleção de adicionais (addons)
- ✅ Botão "Adicionar ao Carrinho"
- ✅ Feedback visual

### 3. Carrinho de Compras
- ✅ Adicionar produtos
- ✅ Remover produtos
- ✅ Atualizar quantidade (+/-)
- ✅ Cálculo automático de totais
- ✅ Suporte a adicionais
- ✅ Detecção de duplicatas
- ✅ Badge com contador
- ✅ Bottom sheet animado
- ✅ Validação antes do checkout

### 4. Autenticação
- ✅ Onboarding (3 slides)
- ✅ Tela de login
- ✅ Tela de cadastro
- ✅ Validação de formulários
- ✅ Loading states
- ✅ Navegação entre telas

### 5. Perfil de Usuário
- ✅ Validação de completude
- ✅ Lista de campos faltantes
- ✅ Formulário de completar perfil
- ✅ Máscaras de input (telefone, CEP)
- ✅ Salvamento de dados
- ✅ Pré-preenchimento de campos
- ✅ Validações customizadas

### 6. Validação de Checkout
- ✅ Verificação de perfil completo
- ✅ Dialog explicativo
- ✅ Navegação para completar perfil
- ✅ Loading durante carregamento
- ✅ Feedback ao usuário
- ✅ Interrupção de checkout se incompleto

---

## 📝 Estrutura de Código

### Principais Classes e Métodos

#### CatalogProvider
```dart
class CatalogProvider with ChangeNotifier {
  List<Product> _products = [];
  List<Restaurant> _restaurants = [];
  String _selectedCategory = 'Todos';
  bool _isLoadingProducts = false;
  
  List<Product> get products;
  List<Product> get filteredProducts;
  List<Restaurant> get restaurants;
  List<String> get categories;
  
  Future<void> loadProducts();
  Future<void> loadRestaurants();
  void setSelectedCategory(String category);
}
```

#### CartState
```dart
class CartState with ChangeNotifier {
  final List<CartItem> _items = [];
  
  List<CartItem> get items;
  int get itemCount;
  double get total;
  
  void addItem(CartItem item);
  void updateItemQuantity(String id, int quantity);
  void removeItem(String id);
  void clear();
}
```

#### UserState
```dart
class UserState with ChangeNotifier {
  Map<String, dynamic>? userData;
  
  bool get isProfileComplete;
  List<String> get missingFields;
  
  Future<void> loadUserData();
  Future<void> updateUserData(Map<String, dynamic> data);
  Future<void> mockLogin(); // Para testes
}
```

### Widgets Reutilizáveis

#### ProductCard
```dart
Widget _buildProductCard(Product product) {
  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(product: product),
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Color(0xFF0D3B3B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Imagem
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              product.imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Info
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: TextStyle(fontWeight: FontWeight.bold)),
                Text(product.restaurantName, style: TextStyle(color: Colors.grey)),
                Text('R\$ ${product.price.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

#### CategoryChip
```dart
Widget _buildCategoryChip(String category) {
  final isSelected = _selectedCategory == category;
  
  return ChoiceChip(
    label: Text(category),
    selected: isSelected,
    selectedColor: Color(0xFFE39110),
    backgroundColor: Color(0xFF0D3B3B),
    onSelected: (selected) {
      if (selected) {
        catalogProvider.setSelectedCategory(category);
      }
    },
  );
}
```

#### CartBadge
```dart
Widget _buildCartBadge() {
  return Consumer<CartState>(
    builder: (context, cart, child) {
      return Stack(
        children: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () => CartPage.show(context),
          ),
          if (cart.itemCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFE39110),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${cart.itemCount}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
```

---

## 🎮 Guia de Uso

### Para Desenvolvedores

#### 1. Setup Inicial
```bash
# Clone o repositório
git clone <repo-url>
cd pedeja1.02

# Instale dependências
flutter pub get

# Execute o app
flutter run -d chrome  # Web
flutter run -d emulator-5554  # Android
```

#### 2. Variáveis de Ambiente
**Arquivo**: `lib/core/constants/api_constants.dart`
```dart
class ApiConstants {
  static const String baseUrl = 'https://api-pedeja.vercel.app';
  static const String productsEndpoint = '/api/products';
  static const String restaurantsEndpoint = '/api/restaurants';
}
```

#### 3. Adicionar Nova Feature

**Exemplo: Adicionar favoritos**

**1. Criar Model**:
```dart
// lib/models/favorite_model.dart
class Favorite {
  final String userId;
  final String productId;
  final DateTime createdAt;
}
```

**2. Criar State**:
```dart
// lib/state/favorites_state.dart
class FavoritesState with ChangeNotifier {
  List<String> _favoriteIds = [];
  
  bool isFavorite(String productId) => _favoriteIds.contains(productId);
  
  void toggleFavorite(String productId) {
    if (isFavorite(productId)) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }
    notifyListeners();
  }
}
```

**3. Registrar Provider**:
```dart
// lib/main.dart
MultiProvider(
  providers: [
    // ... outros providers
    ChangeNotifierProvider(create: (_) => FavoritesState()),
  ],
)
```

**4. Usar no Widget**:
```dart
// Em ProductDetailPage
Consumer<FavoritesState>(
  builder: (context, favorites, _) {
    return IconButton(
      icon: Icon(
        favorites.isFavorite(product.id)
            ? Icons.favorite
            : Icons.favorite_border,
      ),
      onPressed: () => favorites.toggleFavorite(product.id),
    );
  },
)
```

#### 4. Debug

**Logs de Debug**:
```dart
// Produtos carregados
debugPrint('📦 [CatalogProvider] Recebidos ${products.length} produtos');

// Navegação
debugPrint('🚀 Navegando para CompleteProfilePage...');

// Estado do carrinho
debugPrint('🛒 Total de itens: ${cart.itemCount}');
```

**Flutter DevTools**:
```bash
flutter run -d chrome
# Abre: http://127.0.0.1:9100
```

**Verificar Estado**:
- Widget Inspector: Ver árvore de widgets
- Network: Verificar chamadas API
- Performance: Identificar lags
- Logging: Ver todos os debugPrint

### Para Usuários

#### Fluxo Completo

**1. Primeira Abertura**:
1. Ver onboarding (3 slides)
2. Clicar "Pular" ou "Começar"
3. Fazer login ou cadastrar

**2. Navegação**:
1. Ver produtos em destaque
2. Filtrar por categoria
3. Clicar em produto
4. Selecionar adicionais
5. Adicionar ao carrinho

**3. Checkout**:
1. Abrir carrinho (ícone no header)
2. Revisar itens
3. Ajustar quantidades
4. Clicar "Finalizar Pedido"
5. Se cadastro incompleto:
   - Ver diálogo com campos faltantes
   - Clicar "Completar Cadastro"
   - Preencher formulário
   - Salvar
6. Se cadastro completo:
   - Prosseguir com pagamento

**4. Completar Perfil**:
1. Acessar via:
   - Checkout (obrigatório)
   - Menu → "🧪 Testar Cadastro"
2. Preencher campos:
   - Nome completo
   - Telefone (11) 91234-5678
   - CEP 12345-678
   - Rua, número, complemento
   - Bairro, cidade, UF
3. Clicar "Salvar Alterações"
4. Voltar para tela anterior

---

## 🚀 Próximos Passos

### Curto Prazo (1-2 semanas)

#### 1. Autenticação Real
- [ ] Integrar Firebase Authentication
- [ ] Implementar login com email/senha
- [ ] Implementar cadastro de novos usuários
- [ ] Implementar "Esqueceu senha?"
- [ ] Persistir sessão do usuário

```dart
// Exemplo Firebase Auth
import 'package:firebase_auth/firebase_auth.dart';

Future<void> signIn(String email, String password) async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  } catch (e) {
    print('Erro ao fazer login: $e');
  }
}
```

#### 2. Persistência de Dados
- [ ] Implementar SharedPreferences para carrinho
- [ ] Salvar favoritos localmente
- [ ] Cache de produtos offline
- [ ] Recuperar estado ao reabrir app

```dart
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveCart() async {
  final prefs = await SharedPreferences.getInstance();
  final cartJson = jsonEncode(_items.map((item) => item.toJson()).toList());
  await prefs.setString('cart', cartJson);
}
```

#### 3. Integração de Pagamento
- [ ] Implementar Mercado Pago SDK
- [ ] Criar fluxo de pagamento PIX
- [ ] Exibir QR Code de pagamento
- [ ] Confirmar pagamento via webhook
- [ ] Salvar pedidos no histórico

```dart
// POST /api/payments/mp/create-with-split
Future<Map<String, dynamic>> createPayment() async {
  final response = await http.post(
    Uri.parse('${ApiConstants.baseUrl}/api/payments/mp/create-with-split'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'amount': cart.total,
      'restaurantId': cart.items.first.restaurantId,
      'items': cart.items.map((item) => item.toJson()).toList(),
    }),
  );
  
  return jsonDecode(response.body);
}
```

### Médio Prazo (3-4 semanas)

#### 4. Sistema de Busca
- [ ] Implementar busca por nome de produto
- [ ] Busca por restaurante
- [ ] Filtros avançados (preço, categoria, rating)
- [ ] Sugestões de busca
- [ ] Histórico de buscas

#### 5. Sistema de Avaliações
- [ ] Permitir avaliar restaurantes
- [ ] Permitir avaliar produtos
- [ ] Exibir média de avaliações
- [ ] Comentários de usuários
- [ ] Fotos de usuários

#### 6. Rastreamento de Pedidos
- [ ] Tela de "Meus Pedidos"
- [ ] Status do pedido em tempo real
- [ ] Notificações push
- [ ] Estimativa de tempo de entrega
- [ ] Chat com entregador

#### 7. Sistema de Cupons
- [ ] Aplicar cupons de desconto
- [ ] Validação de cupons
- [ ] Exibir cupons disponíveis
- [ ] Cupons de primeiro pedido
- [ ] Cashback

### Longo Prazo (2-3 meses)

#### 8. Features Avançadas
- [ ] Pedidos agendados
- [ ] Programa de fidelidade
- [ ] Favoritos e listas
- [ ] Compartilhar pedidos
- [ ] Pedidos em grupo
- [ ] Assinatura mensal

#### 9. Melhorias de Performance
- [ ] Lazy loading de imagens
- [ ] Paginação de produtos
- [ ] Cache de API
- [ ] Otimização de builds
- [ ] Reduzir tamanho do APK

#### 10. Acessibilidade
- [ ] Suporte a leitores de tela
- [ ] Contraste de cores
- [ ] Tamanhos de fonte ajustáveis
- [ ] Navegação por teclado
- [ ] Testes de acessibilidade

---

## 📊 Métricas do Projeto

### Código
- **Total de Linhas**: ~4.500 linhas
- **Arquivos Dart**: 18 arquivos
- **Telas**: 8 páginas
- **Providers**: 3 providers
- **Modelos**: 4 modelos

### Distribuição por Arquivo
```
HomePage:               1228 linhas
CompleteProfilePage:     511 linhas
CartPage:               578 linhas
SignupPage:             346 linhas
LoginPage:              293 linhas
OnboardingPage:         233 linhas
CatalogProvider:        ~200 linhas
CartState:              130 linhas
UserState:              125 linhas
```

### Funcionalidades
- ✅ **Implementadas**: 35 features
- 🚧 **Em Desenvolvimento**: 0 features
- 📋 **Planejadas**: 40+ features

### Testes
- **Análise Estática**: ✅ Sem issues
- **Build Web**: ✅ Funcionando
- **Build Android**: 🔄 Testado parcialmente

---

## 🐛 Problemas Conhecidos e Soluções

### 1. "Scaffold.of() called with a context that does not contain a Scaffold"
**Causa**: Context usado não está abaixo do Scaffold na árvore

**Solução**:
```dart
// Usar Builder
Builder(
  builder: (ctx) => IconButton(
    onPressed: () => Scaffold.of(ctx).openDrawer(),
  ),
)
```

### 2. CompleteProfilePage não abre após dialog
**Causa**: UserState.userData estava null

**Solução**:
```dart
// Carregar dados antes de validar
if (userState.userData == null) {
  await userState.mockLogin();
}
```

### 3. Imagens não carregam
**Causa**: URLs inválidas ou rede lenta

**Solução**:
```dart
Image.network(
  product.imageUrl,
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.image_not_supported);
  },
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator();
  },
)
```

### 4. Hot reload não funciona
**Causa**: Mudanças em Providers ou StatefulWidgets

**Solução**:
```bash
# Usar Hot Restart (R maiúsculo)
# No terminal: apertar R

# Ou reiniciar completamente
flutter run -d chrome
```

---

## 🔧 Configuração do Ambiente

### Requisitos
- Flutter SDK: >=3.0.0
- Dart SDK: >=3.0.0
- VS Code ou Android Studio
- Chrome (para web)
- Android Studio + Emulador (para mobile)

### Dependências (pubspec.yaml)
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  http: ^1.0.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0
```

### Comandos Úteis
```bash
# Verificar instalação
flutter doctor

# Atualizar dependências
flutter pub get
flutter pub upgrade

# Limpar build
flutter clean

# Análise de código
flutter analyze

# Rodar testes
flutter test

# Build para produção
flutter build apk --release
flutter build web --release
```

---

## 📚 Referências

### Documentação
- [Flutter Docs](https://docs.flutter.dev/)
- [Provider Package](https://pub.dev/packages/provider)
- [Material Design](https://material.io/design)

### APIs Utilizadas
- API PedeJá: https://api-pedeja.vercel.app
  - GET /api/products
  - GET /api/restaurants

### Inspiração de Design
- Projeto original FlutterFlow: `pede_ja_v_t_x`
- Material Design 3
- Apps de delivery: iFood, Rappi, Uber Eats

---

## 👥 Contribuidores

### Desenvolvimento
- **nalbe** - Proprietário do projeto
- **GitHub Copilot** - Assistente de desenvolvimento

### Repositório
- **Organização**: projetoescolaparatodos
- **Repositório**: pedeja1.02
- **Branch**: main
- **Último Commit**: ec37e4b (feat: implementar sistema completo de carrinho de compras)

---

## 📄 Licença

Este projeto foi desenvolvido como parte de um projeto educacional.

---

## 📞 Suporte

Para dúvidas ou problemas:
1. Verificar esta documentação
2. Consultar logs de debug
3. Executar `flutter analyze`
4. Verificar issues no GitHub

---

**Última atualização**: 24 de outubro de 2025
**Versão**: 1.0.2
