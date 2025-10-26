# 🔧 Proxy CORS Temporário

## Problema
A API em `https://api-pedeja.vercel.app` está com erro 500 (provavelmente devido às mudanças de CORS).

## Solução Temporária
Use um proxy CORS local para desenvolver enquanto o backend é corrigido.

## Como Usar

### 1. Iniciar o Proxy
```bash
node cors-proxy.js
```

Você verá:
```
🚀 Proxy CORS rodando em http://localhost:8080
📡 Redirecionando para: https://api-pedeja.vercel.app
```

### 2. Configurar o App Flutter

Abra `lib/core/constants/api_constants.dart` e mude:

```dart
static const bool _useLocalProxy = true;  // ← Mude para true
```

### 3. Rodar o App
```bash
flutter run -d chrome
```

Agora todas as requisições passarão pelo proxy local que adiciona os headers CORS automaticamente! ✅

## Como Voltar para Produção

Quando o backend estiver corrigido:

1. Pare o proxy (Ctrl+C)
2. Mude `_useLocalProxy = false` em `api_constants.dart`
3. Faça hot reload no app

## Verificar Status da API

Teste se a API voltou a funcionar:

```powershell
Invoke-WebRequest -Uri "https://api-pedeja.vercel.app/api/promotions/active"
```

Se retornar 200 OK, pode desativar o proxy!
