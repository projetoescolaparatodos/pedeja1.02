import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

      // Pegar Firebase ID Token
      final firebaseToken = await user.getIdToken();
      debugPrint('🎫 [AuthService] Firebase Token obtido');

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
      await _auth.signOut();
      _jwtToken = null;
      _userData = null;
      debugPrint('👋 [AuthService] Logout realizado');
    } catch (e) {
      debugPrint('❌ [AuthService] Erro ao fazer logout: $e');
    }
  }

  /// 🔄 7. Recarregar JWT (se expirou)
  Future<bool> refreshJWT() async {
    return await _exchangeFirebaseTokenForJWT();
  }

  /// 📧 8. Enviar email de recuperação de senha
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      
      return {
        'success': true,
        'message': 'Email de recuperação enviado',
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Email não encontrado';
          break;
        case 'invalid-email':
          message = 'Email inválido';
          break;
        default:
          message = 'Erro ao enviar email: ${e.message}';
      }

      return {
        'success': false,
        'error': message,
      };
    }
  }
}
