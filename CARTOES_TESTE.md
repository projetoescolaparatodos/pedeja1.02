# 🧪 Cartões de Teste - Mercado Pago

## ✅ Cartões que APROVAM

Use estes cartões para testar pagamentos **aprovados**:

| Bandeira | Número | CVV | Validade | Nome |
|----------|--------|-----|----------|------|
| **Visa** | `4509 9535 6623 3704` | 123 | 11/2025 | APRO |
| **Mastercard** | `5031 4332 1540 6351` | 123 | 11/2025 | APRO |
| **Elo** | `6362 9701 2384 5678` | 123 | 11/2025 | APRO |

**CPF para teste:** `123.456.789-00`

---

## ❌ Cartões que RECUSAM (para testar erro)

Use estes cartões para testar pagamentos **recusados**:

| Bandeira | Número | CVV | Validade | Nome | Erro Simulado |
|----------|--------|-----|----------|------|---------------|
| **Visa** | `4235 6477 2802 5682` | 123 | 11/2025 | CALL | Saldo insuficiente |
| **Mastercard** | `5031 7557 3453 0604` | 123 | 11/2025 | OTHE | Erro genérico |

**CPF para teste:** `123.456.789-00`

---

## 💳 Como Testar

### 1. Faça um pedido no app
- Adicione produtos ao carrinho
- Vá até o checkout
- Selecione **Cartão de Crédito** ou **Cartão de Débito**

### 2. Preencha os dados do cartão
- **Número:** Use um dos cartões acima
- **Nome:** Digite qualquer nome (ex: TESTE USUARIO)
- **Validade:** 11/2025
- **CVV:** 123
- **CPF:** 123.456.789-00
- **Parcelas:** Escolha de 1x a 12x

### 3. Confirme o pagamento
- Clique em **Pagar**
- Aguarde a tokenização e processamento
- Veja o resultado (aprovado ou recusado)

---

## 🔐 Segurança

⚠️ **IMPORTANTE:** Estes cartões são apenas para **teste** e **NÃO cobram de verdade**.

✅ **O que acontece:**
- Dados do cartão são tokenizados no backend
- Token é enviado para o Mercado Pago
- Pagamento é processado em ambiente de testes
- Split automático de 85% restaurante + 15% plataforma

❌ **Nunca:**
- Armazene dados completos do cartão
- Envie dados do cartão sem tokenização
- Use estes cartões em produção

---

## 📊 Fluxo de Pagamento

```
1. Usuário preenche cartão
   ↓
2. App valida campos (formato, validade, CVV)
   ↓
3. Dados enviados para backend (API PedeJá)
   ↓
4. Backend tokeniza cartão (Mercado Pago API)
   ↓
5. Backend cria pagamento com token
   ↓
6. Mercado Pago processa e aplica split
   ↓
7. Webhook confirma pagamento
   ↓
8. Pedido atualizado para "preparing"
   ↓
9. Usuário vê confirmação e vai para "Meus Pedidos"
```

---

## 🚀 Próximos Passos

Após testar com cartões de teste:

1. ✅ Verificar se pagamento é aprovado
2. ✅ Verificar se pedido aparece em "Meus Pedidos"
3. ✅ Verificar se split de 85/15 está funcionando
4. ✅ Testar parcelas (1x a 12x)
5. ✅ Testar cartão recusado (erro de saldo)
6. ✅ Verificar webhook atualizando status

**Quando tudo estiver ok, ative o ambiente de produção no Mercado Pago!**
