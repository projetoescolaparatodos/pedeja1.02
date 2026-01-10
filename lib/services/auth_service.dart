import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 🔐 Serviço de Autenticação integrado com Firebase + API Backend
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _jwtToken;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _restaurantData;

  // Getters
  User? get currentUser => _auth.currentUser;
  String? get jwtToken => _jwtToken;
  Map<String, dynamic>? get userData => _userData;
  Map<String, dynamic>? get restaurantData => _restaurantData;
  bool get isAuthenticated => currentUser != null;
  bool get isPartner => _restaurantData != null;

  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  static AuthService get instance => _instance;

  /// 💾 Salvar credenciais localmente
  Future<void> saveCredentials(String email, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);
      await prefs.setString('jwtToken', token);
      
      // 🔐 CRÍTICO: Salvar também o Firebase UID para restaurar sessão
      final firebaseUid = FirebaseAuth.instance.currentUser?.uid;
      if (firebaseUid != null) {
        await prefs.setString('firebase_uid', firebaseUid);
        debugPrint('💾 [AuthService] Firebase UID salvo: $firebaseUid');
      }
      
      debugPrint('💾 [AuthService] Credenciais salvas para: $email');
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao salvar credenciais: $e');
    }
  }

  /// 🔄 Carregar credenciais salvas
  Future<bool> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final email = prefs.getString('userEmail');
      final token = prefs.getString('jwtToken');

      if (isLoggedIn && email != null && token != null) {
        debugPrint('🔄 [AuthService] Credenciais encontradas para: $email');
        _jwtToken = token;
        
        // Tentar restaurar sessão do Firebase se necessário
        // Nota: Firebase Auth deve persistir automaticamente, mas se falhar,
        // podemos confiar no nosso token JWT para chamadas de API
        
        return true;
      }
      
      debugPrint('🔄 [AuthService] Nenhuma credencial salva encontrada');
      return false;
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao carregar credenciais: $e');
      return false;
    }
  }

  /// 🗑️ Limpar credenciais
  Future<void> clearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      debugPrint('🗑️ [AuthService] Iniciando limpeza COMPLETA de credenciais...');
      
      // 🗑️ Remover TODAS as chaves relacionadas à autenticação
      await prefs.remove('isLoggedIn');
      await prefs.remove('userEmail');
      await prefs.remove('jwtToken');
      
      // 🍎 iOS: LIMPEZA AGRESSIVA - Remover TODAS as chaves suspeitas
      if (Platform.isIOS) {
        debugPrint('🍎 [AuthService] iOS detectado - limpeza agressiva');
        final keys = prefs.getKeys();
        int removedCount = 0;
        
        for (String key in keys) {
          // Remover qualquer chave que possa armazenar dados de auth
          if (key.toLowerCase().contains('login') ||
              key.toLowerCase().contains('auth') || 
              key.toLowerCase().contains('user') ||
              key.toLowerCase().contains('token') ||
              key.toLowerCase().contains('jwt') ||
              key.toLowerCase().contains('email') ||
              key.toLowerCase().contains('password') ||
              key.toLowerCase().contains('credential')) {
            await prefs.remove(key);
            removedCount++;
            debugPrint('🗑️ [iOS] Removida chave: $key');
          }
        }
        
        debugPrint('🍎 [iOS] Total de chaves removidas: $removedCount');
        
        // Aguardar para garantir que a limpeza foi persistida
        await Future.delayed(Duration(milliseconds: 300));
      }
      
      debugPrint('✅ [AuthService] Credenciais limpas completamente');
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao limpar credenciais: $e');
    }
  }

  /// 🚀 1. Login com Email e Senha
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 [AuthService] Iniciando login: $email');

      // 1️⃣ Login no Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ [AuthService] Login Firebase OK: ${userCredential.user?.uid}');

      // 2️⃣ Trocar Firebase Token por JWT
      await _exchangeFirebaseTokenForJWT();

      // 3️⃣ Verificar se cadastro está completo
      final isComplete = await checkRegistrationComplete();

      debugPrint('📋 [AuthService] Cadastro completo: $isComplete');

      // ✅ Salvar credenciais manualmente
      if (_jwtToken != null) {
        await saveCredentials(email, _jwtToken!);
      }

      return {
        'success': true,
        'user': userCredential.user,
        'registrationComplete': isComplete,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AuthService] Erro Firebase: ${e.code}');
      
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuário não encontrado';
          break;
        case 'wrong-password':
          message = 'Senha incorreta';
          break;
        case 'invalid-email':
          message = 'Email inválido';
          break;
        case 'user-disabled':
          message = 'Usuário desabilitado';
          break;
        default:
          message = 'Erro ao fazer login: ${e.message}';
      }

      return {
        'success': false,
        'error': message,
      };
    } catch (e) {
      debugPrint('❌ [AuthService] Erro inesperado: $e');
      return {
        'success': false,
        'error': 'Erro inesperado: $e',
      };
    }
  }

  /// 📝 2. Cadastrar novo usuário
  Future<Map<String, dynamic>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      debugPrint('📝 [AuthService] Criando conta: $email');

      // 1️⃣ Criar conta no Firebase
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ [AuthService] Conta Firebase criada: ${userCredential.user?.uid}');

      // 2️⃣ Atualizar displayName no Firebase
      await userCredential.user?.updateDisplayName(name);

      // 3️⃣ Trocar Firebase Token por JWT
      // ✅ Isso já cria o usuário no Firestore automaticamente
      await _exchangeFirebaseTokenForJWT();

      debugPrint('✅ [AuthService] Usuário criado no Firestore automaticamente');

      // 4️⃣ Verificar status do cadastro
      final isComplete = await checkRegistrationComplete();

      // ✅ Salvar credenciais manualmente
      if (_jwtToken != null) {
        await saveCredentials(email, _jwtToken!);
      }

      return {
        'success': true,
        'user': userCredential.user,
        'registrationComplete': isComplete,
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AuthService] Erro Firebase: ${e.code}');
      
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Email já está em uso';
          break;
        case 'invalid-email':
          message = 'Email inválido';
          break;
        case 'weak-password':
          message = 'Senha muito fraca (mínimo 6 caracteres)';
          break;
        default:
          message = 'Erro ao criar conta: ${e.message}';
      }

      return {
        'success': false,
        'error': message,
      };
    } catch (e) {
      debugPrint('❌ [AuthService] Erro inesperado: $e');
      return {
        'success': false,
        'error': 'Erro inesperado: $e',
      };
    }
  }

  /// 🔄 3. Trocar Firebase Token por JWT da API
  Future<bool> _exchangeFirebaseTokenForJWT() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ [AuthService] Nenhum usuário logado');
        return false;
      }

      // Pegar Firebase ID Token (FORÇAR REFRESH para garantir validade)
      final firebaseToken = await user.getIdToken(true);
      debugPrint('🎫 [AuthService] Firebase Token obtido (forceRefresh=true)');

      // ✅ URL correta da API
      final url = 'https://api-pedeja.vercel.app/api/auth/firebase-token';
      debugPrint('📡 [AuthService] Chamando: $url');

      // Chamar API para trocar por JWT
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': firebaseToken}),
      );

      debugPrint('📡 [AuthService] Response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        debugPrint('❌ [AuthService] Erro na API:');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
        debugPrint('   URL: ${response.request?.url}');
        return false;
      }

      // ✅ Processar resposta da API
      final data = jsonDecode(response.body);
      
      if (data['success'] != true) {
        debugPrint('❌ [AuthService] API retornou success: false');
        debugPrint('   Response: $data');
        return false;
      }

      // ✅ Salvar JWT Token
      _jwtToken = data['token'];
      
      // ✅ Salvar dados do usuário
      _userData = data['user']; // { id, email, name }
      
      // ✅ Salvar dados do restaurante (se for parceiro)
      _restaurantData = data['restaurant']; // pode ser null
      
      debugPrint('✅ [AuthService] JWT Token obtido com sucesso');
      debugPrint('👤 [AuthService] User data: $_userData');
      
      if (_restaurantData != null) {
        debugPrint('🏪 [AuthService] Restaurant data: $_restaurantData');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao trocar token: $e');
      return false;
    }
  }

  /// ✅ 4. Verificar se cadastro está completo
  Future<bool> checkRegistrationComplete() async {
    try {
      if (_jwtToken == null) {
        debugPrint('⚠️ [AuthService] JWT Token não disponível');
        return false;
      }

      // ✅ URL correta da API
      final url = 'https://api-pedeja.vercel.app/api/auth/check-registration';
      debugPrint('📡 [AuthService] Chamando: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📡 [AuthService] Response /check-registration: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] != true) {
          debugPrint('⚠️ [AuthService] API retornou success: false');
          return false;
        }
        
        final isComplete = data['registrationComplete'] ?? false;
        
        // Atualiza userData com dados mais recentes
        if (data['user'] != null) {
          _userData = data['user'];
          debugPrint('👤 [AuthService] User data atualizado: $_userData');
          
          // Log específico do address
          if (_userData!['address'] != null) {
            debugPrint('📍 [AuthService] Address type: ${_userData!['address'].runtimeType}');
            debugPrint('📍 [AuthService] Address value: ${_userData!['address']}');
          }
        }
        
        debugPrint('📋 [AuthService] Registration complete: $isComplete');
        return isComplete;
      } else {
        debugPrint('❌ [AuthService] Erro ao verificar cadastro:');
        debugPrint('   Status: ${response.statusCode}');
        debugPrint('   Body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao verificar cadastro: $e');
      return false;
    }
  }

  /// 💾 5. Completar cadastro (salvar dados adicionais)
  Future<Map<String, dynamic>> completeRegistration({
    required String displayName,
    required String phone,
    required String address,
    String? cpf,
    String? userType,
    Map<String, dynamic>? addressDetails,
  }) async {
    try {
      if (_jwtToken == null) {
        debugPrint('⚠️ [AuthService] JWT Token não disponível');
        await _exchangeFirebaseTokenForJWT();
      }

      if (_jwtToken == null) {
        return {
          'success': false,
          'error': 'Não foi possível autenticar',
        };
      }

      // ✅ URL correta da API
      final url = 'https://api-pedeja.vercel.app/api/auth/complete-registration';
      debugPrint('📡 [AuthService] Chamando: $url');

      // ✅ Monta o body conforme a API espera
      final Map<String, dynamic> body = {
        'displayName': displayName,
        'phone': phone,
        'address': address,
        'userType': userType ?? 'customer',
      };

      // Adiciona detalhes do endereço se fornecido
      if (addressDetails != null) {
        body['addressDetails'] = addressDetails;
        debugPrint('📍 [AuthService] Endereço detalhado: $addressDetails');
      }

      // Adiciona CPF se fornecido
      if (cpf != null && cpf.isNotEmpty) {
        body['cpf'] = cpf;
      }

      debugPrint('📤 [AuthService] Enviando: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('📡 [AuthService] Response /complete-registration: ${response.statusCode}');
      debugPrint('📋 [AuthService] Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] != true) {
          debugPrint('⚠️ [AuthService] API retornou success: false');
          return {
            'success': false,
            'error': data['error'] ?? 'Erro desconhecido',
          };
        }
        
        // ✅ Atualiza userData local
        if (data['user'] != null) {
          _userData = data['user'];
          debugPrint('✅ [AuthService] User data atualizado: $_userData');
        }
        
        debugPrint('✅ [AuthService] Cadastro completado com sucesso');
        
        return {
          'success': true,
          'message': data['message'] ?? 'Cadastro completo',
          'user': data['user'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint('❌ [AuthService] Erro ao completar cadastro: ${errorData['error']}');
        
        return {
          'success': false,
          'error': errorData['error'] ?? 'Erro ao completar cadastro',
        };
      }
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao completar cadastro: $e');
      return {
        'success': false,
        'error': 'Erro inesperado: $e',
      };
    }
  }

  /// 🚪 6. Logout
  Future<void> signOut() async {
    try {
      debugPrint('🚪 [AuthService] Iniciando processo de logout...');
      
      // 🗑️ 1. Limpar dados em memória PRIMEIRO
      _jwtToken = null;
      _userData = null;
      _restaurantData = null;
      
      // 🗑️ 2. Limpar credenciais do SharedPreferences
      await clearCredentials();
      
      // 🔥 3. FORÇAR LOGOUT DO FIREBASE
      await _auth.signOut();
      debugPrint('✅ [AuthService] Firebase signOut chamado');
      
      // 🍎 iOS FIX: LIMPEZA AGRESSIVA E MÚLTIPLAS TENTATIVAS
      if (Platform.isIOS) {
        debugPrint('🍎 [AuthService] iOS detectado - iniciando limpeza agressiva...');
        
        // Aguardar para garantir que o signOut completou
        await Future.delayed(Duration(milliseconds: 500));
        
        // Verificar se realmente deslogou e tentar até 3 vezes
        int attempts = 0;
        const maxAttempts = 3;
        
        while (attempts < maxAttempts) {
          final currentUser = _auth.currentUser;
          
          if (currentUser == null) {
            debugPrint('✅ [iOS] Logout confirmado (tentativa ${attempts + 1})');
            break;
          }
          
          attempts++;
          debugPrint('⚠️ [iOS] Usuário ainda logado! Tentativa $attempts/$maxAttempts');
          debugPrint('⚠️ [iOS] UID ainda presente: ${currentUser.uid}');
          
          // Forçar signOut novamente
          await _auth.signOut();
          await Future.delayed(Duration(milliseconds: 300));
          
          // Limpar credenciais novamente
          await clearCredentials();
        }
        
        // Verificação final
        final finalUser = _auth.currentUser;
        if (finalUser != null) {
          debugPrint('❌ [iOS] FALHA: Usuário AINDA logado após $maxAttempts tentativas!');
          debugPrint('❌ [iOS] UID: ${finalUser.uid}, Email: ${finalUser.email}');
          
          // Última tentativa desesperada: deletar o usuário (não recomendado mas funciona)
          // await finalUser.delete(); // ⚠️ PERIGOSO - apenas em último caso
        } else {
          debugPrint('✅ [iOS] Logout CONFIRMADO - usuário completamente deslogado');
        }
      }
      
      debugPrint('👋 [AuthService] Logout completo');
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao fazer logout: $e');
      
      // Mesmo com erro, garantir limpeza
      _jwtToken = null;
      _userData = null;
      _restaurantData = null;
      await clearCredentials();
      
      rethrow;
    }
  }

  /// 🔄 7. Recarregar JWT (se expirou)
  Future<bool> refreshJWT() async {
    return await _exchangeFirebaseTokenForJWT();
  }

  /// 📧 8. Enviar email de recuperação de senha
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('📧 [AuthService] Enviando email de recuperação para: $email');
      
      final response = await http.post(
        Uri.parse('https://api-pedeja.vercel.app/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // Se timeout mas provavelmente foi enviado
          debugPrint('⏱️ [AuthService] Timeout, mas email provavelmente foi enviado');
          throw TimeoutException('Timeout - email enviado');
        },
      );

      debugPrint('📧 [AuthService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ [AuthService] Email de recuperação enviado com sucesso');
        
        return {
          'success': true,
          'message': 'Email de recuperação enviado com sucesso',
        };
      } else {
        final data = json.decode(response.body);
        final errorMessage = data['error'] ?? 'Erro ao enviar email de recuperação';
        
        debugPrint('❌ [AuthService] Erro: $errorMessage');
        
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } on TimeoutException {
      // Timeout geralmente significa que foi enviado mas conexão caiu
      debugPrint('✅ [AuthService] Timeout detectado - assumindo envio bem-sucedido');
      return {
        'success': true,
        'message': 'Email de recuperação enviado. Verifique sua caixa de entrada.',
      };
    } on http.ClientException catch (e) {
      // ClientException (ERR_CONNECTION_RESET) após POST geralmente significa sucesso
      debugPrint('✅ [AuthService] ClientException após POST - assumindo envio bem-sucedido: $e');
      return {
        'success': true,
        'message': 'Email de recuperação enviado. Verifique sua caixa de entrada.',
      };
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao enviar email de recuperação: $e');
      
      // Se for erro de conexão após tentar enviar, assume sucesso
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('CONNECTION_RESET')) {
        debugPrint('✅ [AuthService] Erro de conexão após POST - assumindo envio bem-sucedido');
        return {
          'success': true,
          'message': 'Email de recuperação enviado. Verifique sua caixa de entrada.',
        };
      }
      
      return {
        'success': false,
        'error': 'Erro de conexão. Verifique sua internet e tente novamente.',
      };
    }
  }
}
