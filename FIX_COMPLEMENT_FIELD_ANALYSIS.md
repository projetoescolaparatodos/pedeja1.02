# 🔍 Diagnóstico Final: Campo de Complemento (Address Fix)

## 🚨 O Problema Identificado

Os pedidos estão chegando no painel/banco de dados **sem o campo de complemento** (ex: "Apto 101"), mesmo que o usuário tenha digitado esse dado no cadastro e mesmo que ele esteja salvo no banco de dados do usuário (`users` collection).

## 🕵️‍♂️ Análise de Causa Raiz

Após analisar o fluxo de dados entre o Flutter e a API, identificamos que o problema **NÃO** está no envio dos dados (Flutter -> Banco), mas sim na **leitura** dos dados (API -> Flutter).

### 1. Escrita (Cadastro/Edição) - ✅ OK
Quando o usuário edita o endereço no App:
- O Flutter envia o campo `complement` corretamente.
- O Firestore salva corretamente (confirmado pela sua verificação dos logs onde aparece `"oie"`).

### 2. Leitura (Login/Splash) - ❌ FALHA
Quando o usuário abre o app, o `AuthService` chama a API para pegar os dados do usuário:

**Arquivo:** `lib/services/auth_service.dart`
**Método:** `checkRegistrationComplete`
```dart
// Linha 344
final url = 'https://api-pedeja.vercel.app/api/auth/check-registration';

// ... (request acontece) ...

// Linha 356
if (data['user'] != null) {
  _userData = data['user']; // ⚠️ O Flutter subscreve tudo com o que a API manda
}
```

O problema é que o endpoint `/api/auth/check-registration` (rodando na Vercel) monta o objeto de resposta JSON e **provavelmente esqueceu de incluir o campo `complement`** dentro do objeto `address`.

Como o Flutter confia na API e sobrescreve o `_userData` com a resposta da API, o campo `complement` é apagado da memória do App. Quando o usuário vai fazer um pedido, o App usa esse dado incompleto da memória.

## 🛠️ Solução Necessária (Backend)

Você precisa acessar o código fonte do **Backend (Node.js/Vercel)** e localizar o controlador que responde pela rota `/auth/check-registration` (e também `/auth/me` ou login Google se houver).

Procurar onde o objeto de resposta é montado, algo parecido com:

```javascript
// CÓDIGO DO BACKEND (Ilustrativo)
const userResponse = {
  id: user.uid,
  email: user.email,
  address: {
    street: user.address.street,
    number: user.address.number,
    neighborhood: user.address.neighborhood,
    city: user.address.city,
    zipCode: user.address.zipCode
    // ❌ ERRO: Faltou 'complement: user.address.complement' aqui!
  }
};
res.json({ success: true, user: userResponse });
```

**Correção:** Adicionar o campo faltante no backend.

## 🛡️ Solução de Contorno (Flutter)

Já aplicamos uma "vacina" no Frontend para evitar crashs (`payment_method_page.dart`), garantindo que o app não quebre se o campo vier nulo. Mas para o **dado aparecer no pedido**, a correção do backend acima é obrigatória.

Se não for possível corrigir o backend agora, a única alternativa no Flutter seria ignorar o objeto `address` da API e fazer um `fetch` direto no Firestore dentro do `checkRegistrationComplete`, mas isso aumentaria o tempo de loading e duplicaria lógica.

---

## ✅ CORREÇÃO APLICADA NO BACKEND

**Data**: 02/02/2026
**Arquivo**: Backend API (linha 2200)
**Rota**: `/api/auth/check-registration`

O bug foi localizado e corrigido! O objeto `normalizedAddress` estava sendo recriado manualmente sem o campo `complement`:

```javascript
// ✅ CÓDIGO CORRIGIDO
normalizedAddress = {
  street: userData.address.street || '',
  number: userData.address.number || '',
  neighborhood: userData.address.neighborhood || '',
  complement: userData.address.complement || '', // ✅ CAMPO ADICIONADO!
  city: userData.address.city || '',
  state: userData.address.state || '',
  zipCode: userData.address.zipCode || userData.address.cep || ''
};
```

**Status**:
- [x] Restrição de Bairro (Frontend)
- [x] Prevenção de erro nulo no Checkout (Frontend)
- [x] ✅ Correção do retorno da API (Backend) - **CORRIGIDO NA LINHA 2200**
