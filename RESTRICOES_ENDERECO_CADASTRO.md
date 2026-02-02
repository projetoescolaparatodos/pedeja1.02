# 🚫 Restrições de Endereço no Cadastro

## 📋 Objetivo

Implementar duas restrições no cadastro de endereço para garantir que o app opere apenas na área de cobertura:

1. **Bairro São Francisco**: Bloquear entregas neste bairro
2. **Cidade Vitória do Xingu**: Forçar cidade fixa (único município atendido)

---

## 🎯 Implementação Realizada

### 📍 **Arquivo**: `lib/pages/profile/complete_profile_page.dart`

---

## 1️⃣ Restrição: Bairro São Francisco

### **Comportamento**:
- ❌ Se usuário digitar "São Francisco" (ou variações), o botão **"Salvar e Continuar" fica desabilitado**
- ⚠️ Aviso laranja aparece: "Ainda não entregamos no bairro São Francisco"
- ✅ Validação aceita **todas as variações**:
  - "São Francisco" / "são francisco" / "SÃO FRANCISCO"
  - "sao francisco" / "Sao Francisco" (sem til)
  - "S. Francisco" / "s. francisco" (abreviado com ponto)
  - "S.Francisco" / "s.francisco" (abreviado sem espaço)
  - **"S Francisco" / "s francisco"** (abreviado sem ponto) ✨ NOVO
  - **"S Francisto" / "s francisto"** (erro de digitação comum) ✨ NOVO

### **Código Implementado**:

#### **A. Flag de controle** (linha ~63)
```dart
bool _bairroRestrito = false; // ✅ Controla se bairro é São Francisco
```

#### **B. Função de validação** (linha ~65)
```dart
/// Verifica se bairro é São Francisco (variações)
bool _isBairroSaoFrancisco(String bairro) {
  if (bairro.trim().isEmpty) return false;
  
  // Normaliza: remove acentos e lowercase
  final normalizado = bairro
      .toLowerCase()
      .replaceAll('ã', 'a')
      .replaceAll('á', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ú', 'u')
      .trim();
  
  // Aceita todas as variações:
  // - "sao francisco", "são francisco" (completo)
  // - "s. francisco", "s.francisco" (abreviado com ponto)
  // - "s francisco" (abreviado sem ponto) ✨ NOVO
  // - "s francisto" (erro de digitação comum) ✨ NOVO
  return normalizado.contains('sao francisco') || 
         normalizado.contains('s. francisco') ||
         normalizado.contains('s.francisco') ||
         normalizado.contains('s francisco') ||
         normalizado.contains('s francisto');
}
```

#### **C. Listener em tempo real** (linha ~109)
```dart
@override
void initState() {
  super.initState();
  
  // ✅ Pré-preencher cidade com "Vitória do Xingu" (IMUTÁVEL)
  _cityController.text = 'Vitória do Xingu';
  
  // ... código existente
  
  // ✅ Listener no campo de bairro para validar São Francisco
  _neighborhoodController.addListener(() {
    final isSaoFrancisco = _isBairroSaoFrancisco(_neighborhoodController.text);
    if (isSaoFrancisco != _bairroRestrito) {
      setState(() {
        _bairroRestrito = isSaoFrancisco;
      });
    }
  });
}
```

#### **D. Validação no campo bairro** (linha ~527)
```dart
// Bairro (com validação de São Francisco)
_buildTextField(
  controller: _neighborhoodController,
  label: 'Bairro *',
  icon: Icons.location_city,
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bairro é obrigatório';
    }
    if (_isBairroSaoFrancisco(value)) {
      return 'Ainda não entregamos neste bairro';
    }
    return null;
  },
),
```

#### **E. Aviso visual** (linha ~541)
```dart
// ⚠️ Aviso se bairro for São Francisco
if (_bairroRestrito)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ainda não entregamos no bairro São Francisco',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
```

#### **F. Botão desabilitado** (linha ~638)
```dart
// 💾 BOTÃO SALVAR
SizedBox(
  width: double.infinity,
  height: 54,
  child: ElevatedButton(
    onPressed: (_loading || _bairroRestrito) ? null : _saveProfile,
    //          ^^^^^^^^^^^^^^^^^^^^ ✅ Desabilita se bairro restrito
```

---

## 2️⃣ Restrição: Cidade "Vitória do Xingu"

### **Comportamento**:
- ✅ Campo cidade PRÉ-PREENCHIDO com "Vitória do Xingu"
- 🔒 Campo IMUTÁVEL (readonly/disabled)
- 🛡️ **Mesmo que GPS traga outra cidade, NÃO muda**
- 💡 Usuário não consegue editar

### **Código Implementado**:

#### **A. Pré-preenchimento no initState** (linha ~105)
```dart
@override
void initState() {
  super.initState();
  
  // ✅ Pré-preencher cidade com "Vitória do Xingu" (IMUTÁVEL)
  _cityController.text = 'Vitória do Xingu';
  
  // ... resto do código
}
```

#### **B. GPS NÃO sobrescreve cidade** (linha ~229)
```dart
Future<void> _useGPSLocation() async {
  // ... código de obter GPS
  
  setState(() {
    _streetController.text = address['street'] ?? '';
    _numberController.text = address['number'] ?? '';
    _neighborhoodController.text = address['neighborhood'] ?? '';
    // ✅ NÃO sobrescrever cidade - manter "Vitória do Xingu"
    // _cityController.text = address['city'] ?? ''; // ← DESABILITADO
    _stateController.text = _normalizarEstado(address['state'] ?? '');
    _zipCodeController.text = address['zipCode'] ?? '';
    
    // ✅ Validar se bairro do GPS é São Francisco
    _bairroRestrito = _isBairroSaoFrancisco(address['neighborhood'] ?? '');
  });
}
```

#### **C. Campo readonly** (linha ~580)
```dart
// Cidade e Estado
Row(
  children: [
    Expanded(
      flex: 2,
      child: _buildTextField(
        controller: _cityController,
        label: 'Cidade *',
        icon: Icons.business,
        enabled: false, // ✅ Campo IMUTÁVEL
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Cidade é obrigatória';
          }
          return null;
        },
      ),
    ),
```

#### **D. TextField com suporte a enabled** (linha ~675)
```dart
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  bool enabled = true, // ✅ Novo parâmetro
  // ... outros parâmetros
}) {
  return TextFormField(
    controller: controller,
    enabled: enabled, // ✅ Aplicar enabled
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: const Color(0xFFE39110)),
      filled: true,
      fillColor: enabled 
          ? const Color(0xFF022E28) 
          : const Color(0xFF022E28).withValues(alpha: 0.5), // ✅ Fundo escuro se disabled
      // ... resto da decoração
    ),
    style: TextStyle(
      color: enabled ? Colors.white : Colors.white54, // ✅ Cor diferente se disabled
    ),
    // ... resto dos parâmetros
  );
}
```

---

## 🔄 Fluxo Completo

### **Cenário 1: Usuário digita bairro normal**
```
1. Usuário acessa tela de cadastro
2. Clica em "GPS" → Preenche endereço automaticamente
   - Rua: ✅ Preenchida
   - Número: ✅ Preenchido
   - Bairro: ✅ Preenchido (ex: "Jardim Dall'Acqua")
   - Cidade: ✅ Mantém "Vitória do Xingu" (GPS NÃO sobrescreve)
   - Estado: ✅ Preenchido
3. Campo bairro não é "São Francisco"
4. Botão "Salvar e Continuar" HABILITADO
5. ✅ Usuário consegue salvar
```

### **Cenário 2: Usuário digita "São Francisco"**
```
1. Usuário acessa tela de cadastro
2. Digita manualmente ou GPS retorna "São Francisco"
3. Listener detecta em tempo real
4. ⚠️ Aviso laranja aparece abaixo do campo bairro:
   "Ainda não entregamos no bairro São Francisco"
5. ❌ Botão "Salvar e Continuar" DESABILITADO (cinza)
6. Campo mostra validação vermelha: "Ainda não entregamos neste bairro"
7. ❌ Usuário NÃO consegue salvar
```

### **Cenário 3: GPS traz cidade diferente**
```
1. Usuário está em outra cidade (ex: Altamira)
2. Clica em "GPS"
3. GPS retorna:
   - Rua: "Rua XYZ"
   - Bairro: "Centro"
   - Cidade: "Altamira" ← GPS tenta sobrescrever
   - Estado: "PA"
4. ✅ Código IGNORA cidade do GPS
5. Campo cidade MANTÉM "Vitória do Xingu"
6. Campo cidade permanece IMUTÁVEL (cinza claro)
7. ✅ Usuário salva com cidade correta
```

---

## 🎨 UI/UX

### **Estado Normal** (bairro permitido):
- Campo bairro: branco, editável
- Botão salvar: laranja (#E39110), habilitado
- Sem avisos

### **Estado Restrito** (São Francisco):
- Campo bairro: borda vermelha, texto de erro
- **Aviso laranja** abaixo:
  - 🔶 Ícone de warning
  - Fundo: `Colors.orange.shade100`
  - Borda: `Colors.orange`
  - Texto: "Ainda não entregamos no bairro São Francisco"
- Botão salvar: **CINZA, DESABILITADO**

### **Campo Cidade** (sempre):
- Texto: "Vitória do Xingu" (pré-preenchido)
- Cor do texto: `Colors.white54` (mais claro)
- Fundo: `Color(0xFF022E28).withValues(alpha: 0.5)` (mais escuro)
- **Não editável** (usuário não consegue clicar ou digitar)

---

## 🧪 Casos de Teste

### **Backend** (a ser implementado)
```javascript
describe('POST /api/auth/complete-registration', () => {
  it('deve ACEITAR bairro diferente de São Francisco', async () => {
    const response = await request(app)
      .post('/api/auth/complete-registration')
      .send({
        displayName: 'Teste',
        phone: '(94) 99999-9999',
        addressDetails: {
          neighborhood: 'Jardim Dall\'Acqua',
          city: 'Vitória do Xingu',
          // ...
        }
      });
    
    expect(response.status).toBe(200);
  });
  
  it('deve REJEITAR bairro São Francisco', async () => {
    const response = await request(app)
      .post('/api/auth/complete-registration')
      .send({
        addressDetails: {
          neighborhood: 'São Francisco', // ❌
          city: 'Vitória do Xingu',
          // ...
        }
      });
    
    expect(response.status).toBe(400);
    expect(response.body.error).toContain('São Francisco');
  });
  
  it('deve REJEITAR cidade diferente de Vitória do Xingu', async () => {
    const response = await request(app)
      .post('/api/auth/complete-registration')
      .send({
        addressDetails: {
          neighborhood: 'Centro',
          city: 'Altamira', // ❌
          // ...
        }
      });
    
    expect(response.status).toBe(400);
    expect(response.body.error).toContain('Vitória do Xingu');
  });
});
```

### **Frontend (Flutter)**
- [x] Campo cidade pré-preenchido ao abrir tela
- [x] Campo cidade readonly (não editável)
- [x] GPS não sobrescreve cidade
- [x] Digitar "São Francisco" desabilita botão
- [x] Digitar "sao francisco" desabilita botão
- [x] Digitar "S. Francisco" desabilita botão
- [x] Aviso laranja aparece quando bairro restrito
- [x] Botão fica cinza quando desabilitado
- [x] Validação vermelha no campo bairro
- [x] Digitar bairro permitido habilita botão
- [x] Limpar campo bairro habilita botão

---

## ✅ Checklist de Implementação

### **Frontend (Flutter)** ✅ CONCLUÍDO
- [x] Adicionar flag `_bairroRestrito`
- [x] Implementar função `_isBairroSaoFrancisco()`
- [x] Adicionar listener no campo bairro
- [x] Validação no campo bairro
- [x] Aviso visual laranja
- [x] Desabilitar botão se `_bairroRestrito == true`
- [x] Pré-preencher cidade no `initState()`
- [x] Campo cidade `enabled: false`
- [x] GPS não sobrescreve cidade
- [x] Adicionar parâmetro `enabled` ao `_buildTextField()`
- [x] Ajustar cores para campo disabled

**Implementado em:** 31/01/2026  
**Arquivo modificado:** `lib/pages/profile/complete_profile_page.dart`

### **Backend (Node.js/Express)** ⏳ PENDENTE
- [ ] Validar bairro no backend
- [ ] Validar cidade no backend
- [ ] Retornar erro específico se bairro São Francisco
- [ ] Retornar erro específico se cidade diferente de Vitória do Xingu
- [ ] Adicionar logs de segurança

### **Testes** ⏳ PENDENTE
- [ ] Testar cadastro com bairro permitido (ACEITAR)
- [ ] Testar cadastro com "São Francisco" (REJEITAR)
- [ ] Testar cadastro com "sao francisco" (REJEITAR)
- [ ] Testar cadastro com cidade diferente (REJEITAR backend)
- [ ] Testar GPS sobrescrevendo campos (cidade deve manter)
- [ ] Testar UI: aviso laranja aparece
- [ ] Testar UI: botão desabilitado

---

## 🎯 Próximos Passos

1. ✅ ~~**Implementar no Frontend Flutter**~~ - **CONCLUÍDO**
2. **Implementar validação no Backend** - PRÓXIMO
3. **Testar end-to-end**
4. **Deploy**

---

## 📝 Notas Importantes

- ✅ **Validação duplicada**: Frontend (UX) + Backend (Segurança)
- ⚠️ **Backend é obrigatório**: Nunca confiar apenas no app (pode ser burlado)
- 🔒 **Segurança**: Backend deve validar SEMPRE antes de salvar
- 📱 **UX**: Feedback imediato no app evita frustração do usuário
- 🎯 **Área de cobertura**: Apenas Vitória do Xingu, exceto bairro São Francisco
- 🔄 **Normalização**: Remove acentos para aceitar variações de digitação

---

**Documento criado em:** 31/01/2026  
**Última atualização:** 31/01/2026  
**Versão:** 1.0  
**Status:** 🚧 Implementação Parcial
- ✅ Frontend Flutter: **CONCLUÍDO**
- ⏳ Backend: **PENDENTE**
- ⏳ Testes: **PENDENTE**
