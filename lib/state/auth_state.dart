import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/order_status_listener_service.dart';
import '../services/order_status_pusher_service.dart';

/// 🔐 Estado de Autenticação com Provider
class AuthState extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _currentUser;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _restaurantData;
  bool _isLoading = false;
  String? _error;
  bool _registrationComplete = false;
  bool _isGuest = false; // ✅ NOVO: Estado de convidado

  // Getters
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;
  Map<String, dynamic>? get restaurantData => _restaurantData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  // ✅ Alterado para considerar token JWT também
  bool get isAuthenticated => _currentUser != null || _authService.jwtToken != null;
  bool get registrationComplete => _registrationComplete;
  bool get isPartner => _restaurantData != null;
  String? get jwtToken => _authService.jwtToken;
  bool get isGuest => _isGuest; // ✅ NOVO: Getter para modo convidado

  AuthState() {
    _initAuth();
  }

  /// 🔄 Inicializar autenticação
  Future<void> _initAuth() async {
    debugPrint('🔧 [AuthState] _initAuth() chamado - Iniciando auto-login manual');
    
    _isLoading = true;
    notifyListeners();

    try {
      // 1️⃣ Tentar carregar credenciais salvas manualmente
      final hasCredentials = await _authService.loadSavedCredentials();
      
      if (hasCredentials) {
        debugPrint('✅ [AuthState] Credenciais manuais encontradas');
        
        // Tentar obter usuário atual do Firebase (pode ser null se não persistiu)
        // Se for null, mas temos token, podemos tentar "re-autenticar" ou apenas usar o token para API
        // Por enquanto, vamos confiar no Firebase se ele estiver lá, ou usar o estado manual
        
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          _currentUser = currentUser;
          debugPrint('✅ [AuthState] Usuário Firebase também encontrado: ${currentUser.email}');
        } else {
          debugPrint('⚠️ [AuthState] Usuário Firebase é NULL, mas temos credenciais salvas');
          // Aqui poderíamos tentar um signInWithCustomToken se tivéssemos salvo, 
          // ou apenas confiar que o token JWT está válido para chamadas de API.
          // Para UI, precisamos de um objeto User ou simular um.
          // Como _currentUser é User?, não podemos instanciar User diretamente facilmente.
          // Vamos manter _currentUser como null mas isAuthenticated como true se mudarmos a lógica do getter.
          // Mas o getter isAuthenticated depende de _currentUser != null.
          
          // SOLUÇÃO: Se temos credenciais mas Firebase está deslogado, 
          // o ideal seria tentar re-autenticar silenciosamente ou forçar login.
          // Mas como o problema é persistência, vamos assumir que o usuário ESTÁ logado
          // e tentar carregar os dados dele via API usando o token salvo.
        }

        // Carregar dados do usuário da API
        await _loadUserData();
        
        // Se conseguimos carregar dados, consideramos logado
        if (_userData != null) {
             debugPrint('✅ [AuthState] Dados do usuário carregados via API/Cache');
             
             // Se _currentUser for null, isso é um problema para widgets que dependem dele.
             // Mas para a lógica de "estar logado", o que importa é ter acesso.
        }
      } else {
        debugPrint('❌ [AuthState] Nenhuma credencial manual encontrada');
      }
      
    } catch (e) {
      debugPrint('❌ [AuthState] Erro ao inicializar auth: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    // Manter listener do Firebase apenas para sincronizar se algo mudar externamente
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      debugPrint('🔔 [AuthState] authStateChanges: ${user?.email}');
      if (user != null) {
        _currentUser = user;
        // Salvar credenciais novamente para garantir
        if (user.email != null && _authService.jwtToken != null) {
             _authService.saveCredentials(user.email!, _authService.jwtToken!);
        }
        notifyListeners();
      }
    });
  }

  /// 💾 Salvar estado de login
  Future<void> _saveLoginState(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userEmail', email);
      debugPrint('💾 [AuthState] Estado de login salvo para: $email');
    } catch (e) {
      debugPrint('❌ [AuthState] Erro ao salvar estado: $e');
    }
  }

  /// 🗑️ Limpar estado de login
  Future<void> _clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('userEmail');
      debugPrint('🗑️ [AuthState] Estado de login limpo');
    } catch (e) {
      debugPrint('❌ [AuthState] Erro ao limpar estado: $e');
    }
  }

  /// 🚀 Login
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result['success']) {
        _currentUser = result['user'];
        _registrationComplete = result['registrationComplete'] ?? false;
        _userData = _authService.userData;
        _restaurantData = _authService.restaurantData;
        
        debugPrint('✅ [AuthState] Login bem-sucedido');
        debugPrint('📋 [AuthState] Cadastro completo: $_registrationComplete');
        debugPrint('👤 [AuthState] userData: $_userData');
        
        if (_restaurantData != null) {
          debugPrint('🏪 [AuthState] restaurantData: $_restaurantData');
        }
        
        // 🔔 Registrar token FCM após login bem-sucedido
        if (_authService.jwtToken != null) {
          final userId = _userData?['id'] ?? _userData?['uid'];
          await NotificationService.updateAuthToken(
            _authService.jwtToken!,
            userId: userId,
          );
          debugPrint('🔔 [AuthState] Token FCM atualizado após login (User ID: $userId)');
        }
        
        // 📦 Iniciar monitoramento de status de pedidos
        await OrderStatusListenerService.startListeningToUserOrders();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        debugPrint('❌ [AuthState] Login falhou: $_error');
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erro inesperado: $e';
      debugPrint('❌ [AuthState] Erro no login: $e');
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 📝 Cadastrar
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      if (result['success']) {
        _currentUser = result['user'];
        _registrationComplete = result['registrationComplete'] ?? false;
        _userData = _authService.userData;
        _restaurantData = _authService.restaurantData;
        
        debugPrint('✅ [AuthState] Cadastro bem-sucedido');
        
        if (_restaurantData != null) {
          debugPrint('🏪 [AuthState] Usuário é parceiro: $_restaurantData');
        }
        
        // 🔔 Registrar token FCM após cadastro bem-sucedido
        if (_authService.jwtToken != null) {
          final userId = _userData?['id'] ?? _userData?['uid'];
          await NotificationService.updateAuthToken(
            _authService.jwtToken!,
            userId: userId,
          );
          debugPrint('🔔 [AuthState] Token FCM atualizado após cadastro (User ID: $userId)');
        }
        
        // 📦 Iniciar monitoramento de status de pedidos
        await OrderStatusListenerService.startListeningToUserOrders();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        debugPrint('❌ [AuthState] Cadastro falhou: $_error');
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erro inesperado: $e';
      debugPrint('❌ [AuthState] Erro no cadastro: $e');
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 💾 Completar cadastro
  Future<bool> completeRegistration({
    required String displayName,
    required String phone,
    required Map<String, dynamic> address,
    String? cpf,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📤 [AuthState] Enviando dados para API:');
      debugPrint('   Nome: $displayName');
      debugPrint('   Telefone: $phone');
      debugPrint('   Endereço completo: $address');
      
      final result = await _authService.completeRegistration(
        displayName: displayName,
        phone: phone,
        address: address['formatted'] ?? '',
        cpf: cpf,
        addressDetails: address,
      );

      if (result['success']) {
        _registrationComplete = true;
        _userData = result['user'];
        
        debugPrint('✅ [AuthState] Cadastro completado');
        debugPrint('👤 [AuthState] User data atualizado: $_userData');
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        debugPrint('❌ [AuthState] Erro ao completar cadastro: $_error');
        
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erro inesperado: $e';
      debugPrint('❌ [AuthState] Erro ao completar cadastro: $e');
      
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 📡 Carregar dados do usuário
  Future<void> _loadUserData() async {
    try {
      // ✅ SEMPRE renovar o JWT ao carregar dados do usuário
      debugPrint('🔄 [AuthState] Renovando JWT token...');
      final tokenRenewed = await _authService.refreshJWT();
      
      if (!tokenRenewed) {
        debugPrint('❌ [AuthState] Falha ao renovar token JWT');
        
        // ✅ FIX: Se já temos um token (carregado manualmente), não devemos abortar.
        if (_authService.jwtToken != null) {
          debugPrint('⚠️ [AuthState] Usando token JWT salvo manualmente');
        } else {
          return;
        }
      } else {
        debugPrint('✅ [AuthState] JWT token renovado com sucesso');
      }
      
      // Agora verifica se o cadastro está completo
      final isComplete = await _authService.checkRegistrationComplete();
      _registrationComplete = isComplete;
      _userData = _authService.userData;
      _restaurantData = _authService.restaurantData;
      
      debugPrint('📋 [AuthState] Dados carregados - Complete: $isComplete');
      debugPrint('👤 [AuthState] userData: $_userData');
      
      // ✅ Inicializar Pusher para notificações em tempo real
      if (_userData != null && _authService.jwtToken != null) {
        final userId = _userData!['id'] ?? _userData!['uid'];
        if (userId != null) {
          debugPrint('📡 [AuthState] Inicializando Pusher para usuário: $userId');
          await OrderStatusPusherService.initialize(
            userId: userId,
            authToken: _authService.jwtToken,
          );
          
          // ✅ CRÍTICO: Registrar FCM token no backend após auto-login
          debugPrint('🔔 [AuthState] Registrando FCM token após auto-login');
          await NotificationService.updateAuthToken(
            _authService.jwtToken!,
            userId: userId,
          );
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AuthState] Erro ao carregar dados: $e');
    }
  }

  /// ✅ Verificar se cadastro está completo
  Future<bool> checkRegistrationComplete() async {
    try {
      final isComplete = await _authService.checkRegistrationComplete();
      _registrationComplete = isComplete;
      _userData = _authService.userData;
      _restaurantData = _authService.restaurantData;
      
      notifyListeners();
      return isComplete;
    } catch (e) {
      debugPrint('❌ [AuthState] Erro ao verificar cadastro: $e');
      return false;
    }
  }

  /// 👤 Entrar como convidado
  void enterGuestMode() {
    _isGuest = true;
    _isLoading = false;
    notifyListeners();
    debugPrint('👤 [AuthState] Modo convidado ativado');
  }

  /// 🚪 Logout
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 🔔 Limpar token FCM antes do logout
      await NotificationService.clearToken();
      
      // 🛑 Parar monitoramento de pedidos
      await OrderStatusListenerService.stopListeningToAllOrders();
      OrderStatusListenerService.clearCache();

      // 🛑 Desconectar Pusher
      await OrderStatusPusherService.disconnect();

      // 🚪 Logout do Firebase + Limpar credenciais
      await _authService.signOut();
      
      // 🗑️ Limpar TODOS os estados locais
      _currentUser = null;
      _userData = null;
      _restaurantData = null;
      _registrationComplete = false;
      _error = null;
      _isGuest = false;
      
      // 🍎 iOS: Aguardar para garantir limpeza
      if (Platform.isIOS) {
        await Future.delayed(Duration(milliseconds: 300));
        
        // Verificar se Firebase realmente deslogou
        final stillLoggedIn = FirebaseAuth.instance.currentUser;
        if (stillLoggedIn != null) {
          debugPrint('⚠️ [AuthState] iOS ainda tem usuário! UID: ${stillLoggedIn.uid}');
          
          // Forçar signOut novamente
          await FirebaseAuth.instance.signOut();
          await Future.delayed(Duration(milliseconds: 200));
        }
      }
      
      _isLoading = false;
      notifyListeners();
      
      debugPrint('👋 [AuthState] Logout completo');
    } catch (e) {
      debugPrint('❌ [AuthState] Erro no logout: $e');
      
      // Mesmo com erro, limpar tudo
      _currentUser = null;
      _userData = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 📧 Enviar email de recuperação
  Future<bool> sendPasswordResetEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.sendPasswordResetEmail(email);
      
      if (result['success']) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = result['error'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erro ao enviar email: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 🔄 Atualizar JWT
  Future<void> refreshJWT() async {
    await _authService.refreshJWT();
    notifyListeners();
  }

  /// 🧹 Limpar erro
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
