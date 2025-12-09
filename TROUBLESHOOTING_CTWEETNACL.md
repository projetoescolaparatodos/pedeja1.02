# 🔧 Troubleshooting CTweetNacl - Guia de Resolução

Este documento registra o processo completo de debug do erro CTweetNacl para referência futura.

---

## 📊 Timeline de Erros

### Build 1-8: "Unable to find module dependency"
```
Swift Compiler Error (Xcode): Unable to find module dependency: 'CTweetNacl'
(in target 'PusherSwift' from project 'Pods')
```

**Tentativas que NÃO funcionaram:**
- ❌ Fixar versão TweetNacl 1.0.2
- ❌ Adicionar `pod 'TweetNacl', :modular_headers => true`
- ❌ Criar script para gerar module.modulemap
- ❌ Limpar cache do CocoaPods
- ❌ Adicionar vários build settings

**O que FUNCIONOU:**
- ✅ Desabilitar `SWIFT_ENABLE_EXPLICIT_MODULES` para PusherSwift e TweetNacl

---

### Build 9: "Build input file cannot be found"
```
Build input file cannot be found: 
'/Users/builder/clone/ios/Pods/TweetNacl/Sources/module.modulemap'
Did you forget to declare this file as an output of a script phase?
```

**Diagnóstico:**
- Arquivo fonte no repo: `Sources/module.map`
- Tentamos usar: `module.modulemap`
- CocoaPods converte .map → .modulemap durante build

**Tentativa que NÃO funcionou:**
- ❌ Setar `MODULEMAP_FILE = 'TweetNacl/Sources/module.map'`

**Problema:** Ainda causava conflito (próximo erro)

---

### Build 10: "Redefinition of module 'CTweetNacl'"
```
Swift Compiler Error (Xcode): Redefinition of module 'CTweetNacl'
.../TweetNacl.framework/Modules/module.modulemap:0:7

Swift Compiler Error (Xcode): No module named 'TweetNacl' found, 
parent module must be defined before the submodule
```

**Diagnóstico:**
- CocoaPods gera `TweetNacl.framework/Modules/module.modulemap` automaticamente
- Tentar setar `MODULEMAP_FILE` manualmente causa dois module maps
- Dois module maps = Redefinição de CTweetNacl

**Solução FINAL:**
- ✅ **NÃO setar MODULEMAP_FILE**
- ✅ Deixar CocoaPods gerenciar module maps automaticamente
- ✅ Apenas adicionar HEADER_SEARCH_PATHS e SWIFT_INCLUDE_PATHS

---

## ✅ Solução Final Completa

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    target.build_configurations.each do |config|
      # Configurações globais
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      config.build_settings['DEFINES_MODULE'] = 'YES'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'i386'
      config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      
      # FIX CRÍTICO: Xcode 16+ CTweetNacl
      if ['PusherSwift', 'TweetNacl'].include?(target.name)
        config.build_settings['SWIFT_ENABLE_EXPLICIT_MODULES'] = 'NO'
        config.build_settings['SWIFT_ENABLE_INCREMENTAL_COMPILATION'] = 'NO'
        config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      end
      
      # Search paths para TweetNacl (NÃO override MODULEMAP_FILE!)
      if target.name == 'TweetNacl'
        config.build_settings['HEADER_SEARCH_PATHS'] = '$(inherited) $(PODS_ROOT)/TweetNacl/Sources $(PODS_ROOT)/TweetNacl/Sources/CTweetNacl/include'
        config.build_settings['SWIFT_INCLUDE_PATHS'] = '$(inherited) $(PODS_ROOT)/TweetNacl/Sources'
      end
    end
  end
end
```

---

## 🚨 O QUE NÃO FAZER

### ❌ NÃO setar MODULEMAP_FILE manualmente
```ruby
# ERRADO - Causa redefinição de módulo
config.build_settings['MODULEMAP_FILE'] = '$(PODS_ROOT)/TweetNacl/Sources/module.map'
```

**Por que não:** CocoaPods já gera module.modulemap automaticamente durante o build.

### ❌ NÃO criar module.modulemap manualmente
```bash
# ERRADO - Script desnecessário no codemagic.yaml
cat > "$TWEETNACL_PATH/module.modulemap" <<EOF
module CTweetNacl {
  header "TweetNacl.h"
  export *
}
EOF
```

**Por que não:** CocoaPods faz isso automaticamente baseado no arquivo `module.map` do repositório.

### ❌ NÃO fixar versão do TweetNacl
```ruby
# DESNECESSÁRIO - Problema não é a versão
pod 'TweetNacl', '1.0.2', :modular_headers => true
```

**Por que não:** O problema é do Xcode 16+, não da versão do TweetNacl.

---

## 🎯 Checklist de Verificação

Se o build ainda falhar, verifique:

- [ ] `SWIFT_ENABLE_EXPLICIT_MODULES = 'NO'` para PusherSwift e TweetNacl?
- [ ] `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = 'YES'`?
- [ ] **NÃO** há `MODULEMAP_FILE` configurado para TweetNacl?
- [ ] HEADER_SEARCH_PATHS inclui `$(PODS_ROOT)/TweetNacl/Sources`?
- [ ] SWIFT_INCLUDE_PATHS inclui `$(PODS_ROOT)/TweetNacl/Sources`?
- [ ] `pod install` foi executado após mudanças no Podfile?
- [ ] Cache do CocoaPods foi limpo (`pod cache clean --all`)?

---

## 🔍 Como Diagnosticar Problemas

### 1. Verificar se module.map existe
```bash
cd ios
pod install
ls -la Pods/TweetNacl/Sources/module.map
# Deve existir
```

### 2. Verificar se module.modulemap foi gerado
```bash
# Após build
ls -la ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Intermediates.noindex/ArchiveIntermediates/Runner/BuildProductsPath/Release-iphoneos/TweetNacl/TweetNacl.framework/Modules/module.modulemap
# Deve existir - CocoaPods gera isso
```

### 3. Ver configurações do target TweetNacl
```bash
# Abrir Xcode
open ios/Runner.xcworkspace

# Build Settings → TweetNacl target
# Verificar:
# - MODULEMAP_FILE deve estar vazio ou $(PODS_ROOT)/TweetNacl/module.modulemap (gerado pelo CocoaPods)
# - SWIFT_ENABLE_EXPLICIT_MODULES = NO
# - HEADER_SEARCH_PATHS deve incluir caminhos do TweetNacl
```

### 4. Build verboso
```bash
flutter build ios --release --verbose
# Procurar por:
# - "Compiling module 'CTweetNacl'"
# - "Importing module 'TweetNacl'"
# - Erros relacionados a module.map ou module.modulemap
```

---

## 📚 Referências Técnicas

### Estrutura do TweetNacl
```
Pods/TweetNacl/
├── Sources/
│   ├── module.map              ← Arquivo fonte (no repo)
│   ├── TweetNacl.swift
│   └── CTweetNacl/
│       └── include/
│           ├── ctweetnacl.h
│           └── ...
└── (após build)
    └── Build/.../TweetNacl.framework/
        └── Modules/
            └── module.modulemap ← Gerado pelo CocoaPods
```

### O que cada arquivo faz

**`module.map`** (fonte):
- Arquivo no repositório TweetNacl
- Define estrutura dos módulos Swift e C
- CocoaPods lê este arquivo durante `pod install`

**`module.modulemap`** (gerado):
- Criado por CocoaPods/Xcode durante build
- Baseado no `module.map` original
- Localizado no .framework após compilação
- **Não deve ser criado manualmente**

### Build Settings Importantes

| Setting | Valor | Por quê |
|---------|-------|---------|
| `SWIFT_ENABLE_EXPLICIT_MODULES` | `NO` | Xcode 16+ bug - quebra resolução de módulos C |
| `SWIFT_ENABLE_INCREMENTAL_COMPILATION` | `NO` | Evita cache incorreto de módulos |
| `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES` | `YES` | Permite includes C não modulares |
| `MODULEMAP_FILE` | *(não setar)* | Deixar CocoaPods gerenciar |
| `HEADER_SEARCH_PATHS` | `$(PODS_ROOT)/TweetNacl/Sources` | Para encontrar headers C |
| `SWIFT_INCLUDE_PATHS` | `$(PODS_ROOT)/TweetNacl/Sources` | Para import Swift |

---

## 🆘 Se Tudo Mais Falhar

### Opção 1: Usar fork do Pusher (última opção)
```ruby
# Em pubspec.yaml, substituir:
pusher_channels_flutter: ^2.5.0

# Por versão sem criptografia (sem TweetNacl):
# ATENÇÃO: Perde funcionalidade de canais privados criptografados
```

### Opção 2: Downgrade do Xcode no Codemagic
```yaml
# Em codemagic.yaml
environment:
  xcode: 15.4  # Em vez de 'latest'
```

**Nota:** Não recomendado - Xcode 16+ será obrigatório em breve.

### Opção 3: Relatar bug ao Pusher
- Issue template: https://github.com/pusher/pusher-channels-flutter/issues/new
- Mencionar: Xcode 16+, CTweetNacl, module resolution
- Referência: https://github.com/bitmark-inc/tweetnacl-swiftwrap/issues/18

---

**Última atualização:** 08/12/2024  
**Testado com:** Xcode 16.x, Flutter stable, pusher_channels_flutter ^2.5.0
