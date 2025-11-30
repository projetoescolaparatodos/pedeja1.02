# Guia: Screenshots para Google Play Store (Tablet 7")

## Especificações Play Store
- **Formato:** PNG ou JPEG
- **Tamanho máximo:** 8 MB cada
- **Proporção:** 16:9 ou 9:16
- **Dimensões:** cada lado entre 320px e 3.840px
- **Quantidade:** até 8 screenshots

## Resolução Recomendada para Tablet 7"
- **Paisagem (16:9):** 1280×720 px
- **Retrato (9:16):** 720×1280 px

---

## Passo a Passo (Chrome DevTools)

### 1. Abrir DevTools
Após o app carregar no Chrome:
- Pressione **F12** ou **Ctrl+Shift+I**
- Ou clique com botão direito → **Inspecionar**

### 2. Ativar Device Toolbar
- Clique no ícone de **dispositivo móvel/tablet** no canto superior esquerdo do DevTools
- Ou pressione **Ctrl+Shift+M**

### 3. Configurar Resolução de Tablet 7"

**Opção A - Preset (Recomendado):**
- No dropdown de dispositivos (topo), selecione **"Nest Hub"** (1024×600) ou similar
- Ou selecione **"Responsive"** e configure manualmente

**Opção B - Customizado:**
1. Selecione **"Responsive"** no dropdown
2. Digite as dimensões:
   - **Retrato (9:16):** `720` × `1280`
   - **Paisagem (16:9):** `1280` × `720`
3. Escolha zoom 100%

### 4. Capturar Screenshots

**Método 1 - DevTools (Melhor qualidade):**
1. Com DevTools aberto e device toolbar ativo
2. Pressione **Ctrl+Shift+P** (Command Palette)
3. Digite: `screenshot`
4. Selecione **"Capture screenshot"** (captura viewport atual)
5. Arquivo PNG será baixado automaticamente

**Método 2 - Print Screen:**
1. Garanta que apenas a viewport do app está visível (esconda DevTools sidebar se necessário)
2. Pressione **PrtScn** ou use **Ferramenta de Recorte do Windows** (`Win+Shift+S`)
3. Recorte apenas a área do app
4. Cole no Paint/GIMP e salve como PNG

### 5. Telas Importantes para Capturar

Capture screenshots das seguintes telas (sugestões):
1. **Tela de Login** (mostra brand e identidade visual)
2. **Tela de Cadastro** (com novo campo Data de Nascimento)
3. **Home / Lista de Restaurantes** (funcionalidade principal)
4. **Detalhes do Restaurante / Menu**
5. **Carrinho de Compras**
6. **Pedidos Ativos / Histórico**
7. **Chat com Restaurante** (diferencial)
8. **Perfil / Configurações**

---

## Dicas

### ✅ Boas Práticas
- Use dados realistas (não "teste" ou "lorem ipsum")
- Capturas em **modo claro** (melhor visibilidade)
- Mostre **funcionalidades principais** do app
- Evite informações sensíveis reais (use dados fictícios)
- Mínimo de 4 screenshots, ideal 6-8

### ⚠️ Evite
- Screenshots com tela de debug/erros
- Interfaces vazias ou com dados placeholder
- Textos ilegíveis (zoom muito pequeno)
- Capturas cortadas ou fora de proporção

### 🎨 Melhorias (Opcional)
- Adicione **molduras de dispositivo** (pode usar ferramentas como [Mockuphone](https://mockuphone.com/))
- Insira **descrições/textos** sobre funcionalidades
- Use ferramentas como **Figma/Canva** para criar composições

---

## Verificação Final

Antes de enviar ao Play Console:
```powershell
# Verificar dimensões e tamanho dos screenshots
Get-ChildItem screenshots/*.png | ForEach-Object {
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $size = [math]::Round($_.Length/1MB, 2)
    Write-Host "$($_.Name): $($img.Width)x$($img.Height) - $size MB"
    $img.Dispose()
}
```

---

## Atalhos Úteis

| Ação | Atalho |
|------|--------|
| Abrir DevTools | `F12` ou `Ctrl+Shift+I` |
| Toggle Device Toolbar | `Ctrl+Shift+M` |
| Command Palette | `Ctrl+Shift+P` |
| Ferramenta Recorte (Windows) | `Win+Shift+S` |
| Refresh página | `Ctrl+R` ou `F5` |

---

**App está rodando no Chrome agora!** 🚀  
Siga os passos acima para capturar os screenshots.
