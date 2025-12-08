# Guia de Configuração Codemagic para iOS

Este guia detalha todos os passos necessários para configurar o Codemagic e publicar o app PedeJá na App Store.

## 📋 Pré-requisitos

Antes de começar, você precisa ter:

1. ✅ **Conta Apple Developer** (USD $99/ano)
   - Acesse: https://developer.apple.com/programs/
   - Necessária para publicar apps na App Store

2. ✅ **Conta Codemagic**
   - Acesse: https://codemagic.io/
   - Pode usar conta gratuita para começar
   - Faça login com sua conta GitHub

3. ✅ **Repositório GitHub**
   - Seu código já está no GitHub (projetoescolaparatodos/pedeja1.02)

---

## 🍎 Parte 1: Configuração na Apple Developer

### 1.1 Criar App Identifier (Bundle ID)

1. Acesse: https://developer.apple.com/account/resources/identifiers/list
2. Clique no botão **"+"** para adicionar novo identifier
3. Selecione **"App IDs"** e clique **"Continue"**
4. Selecione **"App"** e clique **"Continue"**
5. Preencha:
   - **Description**: PedeJá - App de Delivery
   - **Bundle ID**: `com.pedeja.app` (mesmo do Android)
   - **Explicit** (não wildcard)
6. Em **Capabilities**, marque:
   - ✅ Push Notifications
   - ✅ Associated Domains (se usar deep links)
   - ✅ Sign in with Apple (se implementar)
7. Clique **"Continue"** e depois **"Register"**

### 1.2 Gerar Chave Privada (SEM Mac! 🎉)

**O Codemagic cria os certificados automaticamente! Você só precisa de uma chave RSA.**

No Windows, abra PowerShell e rode:

```powershell
# Instalar OpenSSH (se não tiver)
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Gerar chave privada RSA 2048-bit
ssh-keygen -t rsa -b 2048 -m PEM -f ios_distribution_private_key -N '""'
```

Ou use o Git Bash (se tiver Git instalado):

```bash
ssh-keygen -t rsa -b 2048 -m PEM -f ios_distribution_private_key -q -N ""
```

Isso vai criar o arquivo `ios_distribution_private_key` (sem extensão).

**IMPORTANTE**: Guarde esse arquivo com segurança! Você vai precisar dele no Codemagic.

**O que o Codemagic faz automaticamente:**
- ✅ Cria o certificado de distribuição na Apple Developer
- ✅ Cria o provisioning profile
- ✅ Renova certificados expirados
- ✅ Tudo sem Mac!

### 1.3 Criar App na App Store Connect

1. Acesse: https://appstoreconnect.apple.com/
2. Clique em **"My Apps"**
3. Clique no **"+"** e selecione **"New App"**
4. Preencha:
   - **Platforms**: iOS
   - **Name**: PedeJá
   - **Primary Language**: Portuguese (Brazil)
   - **Bundle ID**: selecione `com.pedeja.app`
   - **SKU**: `pedeja-app-001` (identificador único interno)
   - **User Access**: Full Access
5. Clique **"Create"**

### 1.4 Criar App Store Connect API Key (para Codemagic)

**IMPORTANTE**: Você precisa de uma conta **Apple Developer ativa** (USD $99/ano paga) para este passo!

1. Acesse: https://appstoreconnect.apple.com/access/api
2. Vá em **"Keys"** → **"App Store Connect API"**
3. Clique no **"+"** para gerar nova chave
4. Preencha:
   - **Name**: `Codemagic CI/CD`
   - **Access**: **App Manager** (permite upload de builds)
5. Clique **"Generate"**
6. **IMPORTANTE**: Baixe o arquivo `.p8` imediatamente (só pode baixar uma vez!)
7. **Copie e anote** (você vai precisar no Codemagic):
   - **Issuer ID**: Fica acima da tabela de chaves (ex: `69a6de12-1234-5678-9abc-def123456789`)
   - **Key ID**: Fica na coluna da tabela (ex: `AB12CD34EF`)
   - **Arquivo .p8**: Guarde em local seguro (ex: `AuthKey_AB12CD34EF.p8`)

**Esses são os 3 valores que o Codemagic pede na imagem:**
- 📝 **Nome da API Connect da APP Store**: Nome que você quer dar (ex: "Codemagic CI/CD")
- 🔑 **ID do Emissor**: O Issuer ID de 36 caracteres
- 🆔 **ID da Chave**: O Key ID de 10 caracteres
- 📄 **Chave API**: O arquivo .p8 que você baixou

---

## 🚀 Parte 2: Configuração no Codemagic

### 2.1 Conectar Repositório

1. Acesse: https://codemagic.io/apps
2. Clique **"Add application"**
3. Selecione **GitHub** como source
4. Autorize acesso ao repositório **pedeja1.02**
5. Selecione o repositório da lista
6. Clique **"Finish: Add application"**

### 2.2 Configurar Code Signing Automático (SEM certificados manuais! 🚀)

#### Adicionar App Store Connect API Key:

**Este é o passo da imagem que você enviou!**

1. No Codemagic, vá para **Teams > Personal Account > Integrations**
2. Clique em **"Connect"** no **Developer Portal**
3. Você verá o formulário **"Integração com o Portal de Desenvolvedores da Apple"**
4. Preencha **exatamente** com os valores da Apple:
   - **Nome da API Connect da APP Store**: `Codemagic CI/CD` (ou qualquer nome descritivo)
   - **ID do Emissor**: Cole o **Issuer ID** que você anotou (36 caracteres com hífens)
   - **ID da Chave**: Cole o **Key ID** que você anotou (10 caracteres)
   - **Chave API**: Clique em **"Escolha um arquivo .p8"** e selecione o arquivo que você baixou (ex: `AuthKey_AB12CD34EF.p8`)
5. Clique **"Salvar"**

**Observação**: Se a conta Apple Developer ainda não estiver ativa (pagamento pendente), você não conseguirá criar a API Key no passo 1.4. Aguarde a ativação da conta primeiro!

#### Adicionar a Chave Privada RSA:

1. Vá para **App settings** do seu projeto
2. Navegue até **Environment variables**
3. Clique **"Add variable"**
4. Preencha:
   - **Variable name**: `CERTIFICATE_PRIVATE_KEY`
   - **Variable value**: Abra o arquivo `ios_distribution_private_key` no Notepad e cole TODO o conteúdo (incluindo `-----BEGIN RSA PRIVATE KEY-----` e `-----END RSA PRIVATE KEY-----`)
   - **Group**: `code_signing` (crie o grupo)
   - **Secure**: ✅ Marque como seguro
5. Clique **"Add"**

**Pronto! O Codemagic vai:**
- ✅ Buscar ou criar certificado automaticamente
- ✅ Gerar provisioning profile automaticamente
- ✅ Renovar quando expirar
- ✅ Tudo durante o build!

### 2.3 Configurar Workflow com Code Signing Automático

**ATENÇÃO**: Esta é a parte mais importante! Siga EXATAMENTE estes passos.

#### Opção 1: Usar o Workflow Editor (Interface Visual - RECOMENDADO)

1. No Codemagic, abra seu app **pedeja1.02**
2. Clique em **"Start your first build"** OU se já existe workflow, clique nos **3 pontinhos** ao lado do workflow → **"Edit workflow"**
3. Você vai ver uma interface com várias abas/seções

**Configurar CADA SEÇÃO na ordem:**

**A) BUILD MACHINE:**
- Selecione **Mac mini M1** ou **Mac mini M2**

**B) FLUTTER VERSION:**
- Selecione **Stable channel** (ou a versão que você usa)

**C) BUILD TRIGGERS:**
- Marque **"Trigger on tag creation"**
- Pattern: `v*.*.*`
- Desmarque outras opções se não quiser build automático em push

**D) ENVIRONMENT VARIABLES:**
- Clique em **"Add variable group"**
- Selecione o grupo **code_signing** (que você criou com a variável CERTIFICATE_PRIVATE_KEY)
- Adicione variável individual:
  - Variable name: `BUNDLE_ID`
  - Value: `com.pedeja.app`
  - Não marcar como secure
- Adicione outra variável:
  - Variable name: `APP_STORE_APPLE_ID`
  - Value: (deixe vazio por enquanto - você vai pegar isso depois no App Store Connect)
  - Não marcar como secure

**E) INTEGRATIONS:**
- Na seção **App Store Connect**, selecione a integração que você criou: **Codemagic CI/CD**

**F) SCRIPTS (A PARTE MAIS IMPORTANTE!):**

Clique em **"Add script before build"** e adicione OS SCRIPTS NESTA ORDEM:

**Script 1 - Set up keychain:**
```bash
keychain initialize
```

**Script 2 - Fetch signing files (ESTE É O CRÍTICO!):**
```bash
app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create
```
⚠️ **IMPORTANTE**: Escreva **IOS_APP_STORE** (não IOS_APP_DEVELOPMENT!)

**Script 3 - Add certificates:**
```bash
keychain add-certificates
```

**Script 4 - Set up code signing:**
```bash
xcode-project use-profiles
```

**Script 5 - Get Flutter packages:**
```bash
flutter packages pub get
```

**Script 6 - Clean CocoaPods cache (IMPORTANTE!):**
```bash
cd ios
rm -rf Pods Podfile.lock .symlinks
pod repo update
cd ..
```

**Script 7 - Install CocoaPods:**
```bash
find . -name "Podfile" -execdir pod install \;
```

**G) BUILD:**
- **Build mode**: Release
- **Build arguments** (deixe vazio ou adicione se precisar)

**H) TEST:**
- Pode deixar desabilitado por enquanto

**I) PUBLISHING:**
- Marque **App Store Connect**
- Marque **Submit to TestFlight**
- Adicione seu email em **Email notifications**

**J) SAVE:**
- Clique em **"Save"** no canto superior direito

---

#### Opção 2: Usar YAML (Para Usuários Avançados)

Se preferir usar `codemagic.yaml`, crie um arquivo na raiz do projeto:

**Build Configuration com Code Signing Automático:

```yaml
# Configuração do workflow Codemagic - CODE SIGNING AUTOMÁTICO
workflows:
  ios-production:
    name: iOS Production
    max_build_duration: 120
    instance_type: mac_mini_m1
    
    integrations:
      app_store_connect: Codemagic CI/CD  # Nome da integração que você criou
    
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      
      groups:
        - code_signing  # Grupo com CERTIFICATE_PRIVATE_KEY
      
      vars:
        BUNDLE_ID: "com.pedeja.app"
        APP_STORE_APPLE_ID: 1234567890  # Preencha com o Apple ID do app (10 dígitos)
        
    triggering:
      events:
        - tag
      tag_patterns:
        - pattern: 'v*.*.*'
          include: true
      cancel_previous_builds: true
      
    scripts:
      - name: Set up keychain
        script: keychain initialize
        
      - name: Fetch signing files (AUTOMÁTICO!)
        script: |
          app-store-connect fetch-signing-files "$BUNDLE_ID" \
            --type IOS_APP_STORE \
            --create
      
      - name: Add certificates to keychain
        script: keychain add-certificates
        
      - name: Set up code signing settings on Xcode project
        script: xcode-project use-profiles
          
      - name: Get Flutter packages
        script: flutter packages pub get
      
      - name: Clean CocoaPods cache
        script: |
          cd ios
          rm -rf Pods Podfile.lock .symlinks
          pod repo update
          cd ..
          
      - name: Install pods
        script: find . -name "Podfile" -execdir pod install \;
          
      - name: Flutter build ipa
        script: |
          flutter build ipa --release \
            --build-name=1.0.0 \
            --build-number=$(($(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID") + 1))
            
    artifacts:
      - build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
      
    publishing:
      email:
        recipients:
          - seu-email@example.com  # Coloque seu email
        notify:
          success: true
          failure: true
          
      app_store_connect:
        submit_to_testflight: true
        # submit_to_app_store: true  # Descomente quando quiser submeter para review
```

**O que mudou:**
- ✅ Usa `integrations.app_store_connect` para autenticação automática
- ✅ Script `fetch-signing-files` busca/cria certificados e profiles automaticamente
- ✅ `--create` flag permite criar novos certificados se não existirem
- ✅ Nada de .p12 ou .mobileprovision manuais!

---

### 2.4 CHECKLIST ANTES DE RODAR O BUILD:

Verifique se TUDO está configurado:

- [ ] ✅ **Integração Developer Portal** conectada (Teams > Integrations)
- [ ] ✅ **Variável CERTIFICATE_PRIVATE_KEY** criada no grupo **code_signing**
- [ ] ✅ **Workflow criado** com os 6 scripts na ordem correta
- [ ] ✅ **Script 2 usa --type IOS_APP_STORE** (NÃO IOS_APP_DEVELOPMENT!)
- [ ] ✅ **Integração App Store Connect** selecionada no workflow
- [ ] ✅ **Grupo code_signing** adicionado em Environment Variables do workflow

**Se tudo estiver ✅, pode rodar o build!**

---

### 2.5 Configurar Bundle ID no Xcode (Opcional)

O Codemagic vai configurar automaticamente, mas se quiser verificar/editar manualmente (precisa de Mac com Xcode):

1. Abra `ios/Runner.xcworkspace` no Xcode (não o .xcodeproj!)
2. Selecione o target **Runner**
3. Na aba **Signing & Capabilities**:
   - **Bundle Identifier**: `com.pedeja.app`
4. Salve (o Codemagic vai ignorar as configurações de signing e usar as dele)

**SEM Mac?** Não tem problema! O Codemagic faz tudo automaticamente durante o build.

---

## 🎯 Parte 3: Executar Build

### 3.1 Primeira Build Manual

1. No Codemagic, vá para a página do app
2. Selecione o workflow **iOS Production**
3. Clique **"Start new build"**
4. Selecione a branch **main**
5. Clique **"Start new build"**

O processo vai:
- ✅ Baixar dependências Flutter
- ✅ Instalar CocoaPods
- ✅ Configurar code signing
- ✅ Compilar o app
- ✅ Gerar arquivo `.ipa`
- ✅ Enviar para TestFlight automaticamente

### 3.2 Builds Automáticas com Tags

Para builds automáticas no futuro:

```bash
# Criar uma nova versão
git tag v1.0.1
git push origin v1.0.1

# Codemagic vai detectar a tag e iniciar build automaticamente
```

---

## 📱 Parte 4: TestFlight e App Store

### 4.1 Testar no TestFlight

1. Após build bem-sucedida, acesse App Store Connect
2. Vá em **TestFlight**
3. A build vai aparecer em **"Processing"** (5-10 minutos)
4. Quando estiver **"Ready to Test"**:
   - Adicione testadores internos (sua equipe)
   - Ou adicione testadores externos (até 10.000 pessoas)
5. Instale o app TestFlight no iPhone: https://apps.apple.com/app/testflight/id899247664
6. Aceite o convite e teste o app

### 4.2 Submeter para App Store

1. Em App Store Connect, vá para **App Store** (não TestFlight)
2. Clique em **"+ Version"** ou selecione a versão **1.0**
3. Preencha **todas** as informações obrigatórias:

#### Informações do App:
- **Nome**: PedeJá
- **Subtitle**: App de delivery rápido e prático
- **Categoria Primária**: Food & Drink
- **Categoria Secundária**: Shopping

#### Descrição:
```
PedeJá é o app de delivery que conecta você aos melhores restaurantes da sua região!

🍕 PEÇA COM FACILIDADE
• Interface limpa e intuitiva
• Busca rápida de restaurantes
• Modo convidado para pedidos sem cadastro

⚡ ACOMPANHE SEU PEDIDO
• Rastreamento em tempo real
• Notificações de status
• Chat direto com o restaurante

💳 PAGAMENTO SEGURO
• Múltiplas formas de pagamento
• Transações protegidas
• Checkout rápido

🎯 PRINCIPAIS RECURSOS
• Localização automática por GPS
• Filtros por tipo de comida
• Histórico de pedidos
• Avaliações e comentários

Baixe agora e faça seu primeiro pedido!
```

#### Screenshots:
- **Obrigatório**: 6.5" iPhone (1284 x 2778 pixels)
- **Recomendado**: 5.5" iPhone (1242 x 2208 pixels)
- Pelo menos 3 screenshots, máximo 10
- Use a ferramenta: https://www.screenshotone.com/ ou tire do simulador

Dica para screenshots no simulador:
```bash
# iPhone 15 Pro Max (6.5")
xcrun simctl boot "iPhone 15 Pro Max"
open -a Simulator
flutter run
# Cmd+S para screenshot (salva na área de trabalho)
```

#### Ícone:
- 1024 x 1024 pixels
- Sem cantos arredondados (iOS adiciona automaticamente)
- Formato PNG sem transparência

#### Classificação Etária:
- Marque **"None"** para todas as categorias (app de delivery não tem conteúdo sensível)

#### Informações de Contato:
- Nome, email e telefone (não visíveis ao público)
- Usado pela Apple para contato se necessário

#### Privacidade:
- **Privacy Policy URL**: Link para política de privacidade
- **Data Collection**: Informe quais dados você coleta
  - ✅ Location (para delivery)
  - ✅ Contact Info (email, telefone)
  - ✅ Purchase History

4. Em **Build**, clique **"Select a build before you submit your app"**
5. Selecione a build do TestFlight que você quer enviar
6. Clique **"Add"**

7. Em **App Review Information**:
   - Adicione notas para o revisor se necessário
   - Forneça login de teste (usuário/senha) se o app precisar de autenticação

8. Em **Version Release**:
   - Selecione **"Automatically release this version"** ou
   - **"Manually release this version"** (você controla quando publicar)

9. Clique **"Save"** no canto superior direito
10. Clique **"Submit for Review"**

### 4.3 Processo de Review

- ⏱️ Review leva em média **24-48 horas**
- 📧 Você receberá emails sobre o status
- Possíveis resultados:
  - ✅ **Approved**: App aprovado, publicado (ou aguardando release manual)
  - ⚠️ **Metadata Rejected**: Apenas informações rejeitadas (ícone, screenshots, descrição)
  - ❌ **Rejected**: App rejeitado por violar guidelines
  
Se rejeitado:
1. Leia atentamente o motivo no Resolution Center
2. Corrija o problema
3. Submeta novamente

---

## 🔧 Troubleshooting

### ❌ Erro: "Cannot create profile: the request does not include any iOS testing devices"

**CAUSA**: O script está usando `IOS_APP_DEVELOPMENT` em vez de `IOS_APP_STORE`!

**SOLUÇÃO PASSO A PASSO:**

1. Vá para o Codemagic, abra seu app
2. Clique no workflow que deu erro
3. Clique em **"Edit workflow"** (ou os 3 pontinhos)
4. Vá até a seção **SCRIPTS**
5. Encontre o script **"Fetch signing files"**
6. **VERIFIQUE** se está escrito exatamente assim:
   ```bash
   app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create
   ```
7. Se estiver escrito `IOS_APP_DEVELOPMENT`, **DELETE** e escreva `IOS_APP_STORE`
8. Clique em **"Save"** no topo da página
9. Rode o build novamente

**Por que isso acontece?**
- `IOS_APP_DEVELOPMENT` = perfil de teste (precisa de dispositivos registrados)
- `IOS_APP_STORE` = perfil de produção (não precisa de dispositivos, vai para TestFlight/App Store)

---

### Erro: "No provisioning profiles found"
**Solução**: Verifique se:
1. O Bundle ID (`com.pedeja.app`) está registrado na Apple Developer
2. A integração App Store Connect está configurada corretamente
3. A variável `CERTIFICATE_PRIVATE_KEY` está no grupo `code_signing`
4. O script `fetch-signing-files` tem a flag `--create`

### Erro: "Code signing is required"
**Solução**: Certifique-se que:
1. A chave privada RSA está completa (com BEGIN e END)
2. A integração Developer Portal está ativa
3. O workflow tem `integrations.app_store_connect` configurado

### Erro: "Invalid private key"
**Solução**: Regere a chave usando o comando correto:
```powershell
ssh-keygen -t rsa -b 2048 -m PEM -f ios_distribution_private_key -N '""'
```

### Build fica "Processing" muito tempo no TestFlight
**Solução**: Normal. Pode levar até 30 minutos. Se passar de 1 hora, verifique se recebeu email de rejeição.

### App Store Connect API Key inválida
**Solução**: Verifique se copiou o conteúdo completo do arquivo `.p8`, incluindo as linhas `-----BEGIN PRIVATE KEY-----` e `-----END PRIVATE KEY-----`.

---

## 📊 Checklist Final

Antes de submeter para a App Store, verifique:

- [x] ✅ Permissões adicionadas no Info.plist
- [ ] ✅ Bundle ID registrado na Apple Developer (`com.pedeja.app`)
- [ ] ✅ Chave privada RSA gerada (sem Mac!)
- [ ] ✅ App criado na App Store Connect
- [ ] ✅ API Key criada e arquivo .p8 baixado
- [ ] ✅ Integração Developer Portal configurada no Codemagic
- [ ] ✅ Variável CERTIFICATE_PRIVATE_KEY adicionada
- [ ] ✅ Workflow configurado com code signing automático
- [ ] ✅ Primeira build executada com sucesso
- [ ] ✅ App testado no TestFlight
- [ ] ✅ Screenshots preparados (6.5" e 5.5")
- [ ] ✅ Ícone 1024x1024 preparado
- [ ] ✅ Descrição e metadados preenchidos
- [ ] ✅ Política de privacidade publicada
- [ ] ✅ App submetido para review

---

## 📞 Recursos Adicionais

- **Documentação Codemagic iOS**: https://docs.codemagic.io/flutter-publishing/publishing-to-app-store/
- **App Store Review Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **Human Interface Guidelines**: https://developer.apple.com/design/human-interface-guidelines/
- **TestFlight Beta Testing**: https://developer.apple.com/testflight/

---

## 💰 Custos

- **Apple Developer Program**: USD $99/ano (obrigatório para App Store)
  - Sem isso, você não consegue:
    - ✗ Criar Bundle ID
    - ✗ Criar API Keys
    - ✗ Acessar App Store Connect
    - ✗ Publicar apps
  - **Ative a conta primeiro** antes de seguir este guia!
- **Codemagic Free Tier**: 500 minutos/mês (suficiente para começar)
- **Codemagic Pro**: A partir de USD $28/mês (builds ilimitadas, mais rápidas)

---

## ⏱️ Timeline Estimado

**ANTES DE COMEÇAR**: Ativar conta Apple Developer (1-2 dias úteis após pagamento)

1. **Configuração Apple Developer**: 1-2 horas (primeira vez)
2. **Configuração Codemagic**: 30-60 minutos
3. **Primeira build**: 15-20 minutos
4. **Testes no TestFlight**: 1-2 dias
5. **Preparação de screenshots/metadados**: 2-4 horas
6. **Review da Apple**: 24-48 horas
7. **Total**: ~1 semana do início ao lançamento (após conta ativada)

---

**Última atualização**: Dezembro 2025
**Versão do app**: 1.0.0+1
**Status Android**: ✅ App Bundle pronto para Play Store
**Status iOS**: 🟡 Configuração em andamento
**Code Signing**: ✅ AUTOMÁTICO (sem necessidade de Mac!)

Boa sorte com o lançamento! 🚀
