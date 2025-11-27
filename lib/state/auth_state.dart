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

  // Getters
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;
  Map<String, dynamic>? get restaurantData => _restaurantData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get registrationComplete => _registrationComplete;
  bool get isPartner => _restaurantData != null;
  String? get jwtToken => _authService.jwtToken;

  AuthState() {
    _initAuth();
  }

  /// 🔄 Inicializar autenticação
  Future<void> _initAuth() async {
    // ✅ Primeiro: verificar se há sessão do Firebase
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      debugPrint('🔄 [AuthState] Sessão Firebase encontrada: ${currentUser.email}');
      _currentUser = currentUser;
      await _loadUserData();
      await _saveLoginState(currentUser.email!);
      
      // 📦 Iniciar monitoramento de status de pedidos (Firestore)
      OrderStatusListenerService.startListeningToUserOrders();
      
      // 📡 Iniciar monitoramento via Pusher (Real-time)
      OrderStatusPusherService.initialize(
        userId: currentUser.uid,
        authToken: _authService.jwtToken,
      );
      
      notifyListeners();
    } else {
      debugPrint('🔄 [AuthState] Nenhuma sessão Firebase encontrada');
    }
    
    // ✅ Depois: escutar mudanças de autenticação
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
      
      if (user != null) {
        debugPrint('🔔 [AuthState] Usuário logado: ${user.email}');
        _loadUserData();
        _saveLoginState(user.email!);
        
        // 📦 Iniciar monitoramento de status de pedidos (Firestore)
        OrderStatusListenerService.startListeningToUserOrders();
        
        // 📡 Iniciar monitoramento via Pusher (Real-time)
        OrderStatusPusherService.initialize(
          userId: user.uid,
          authToken: _authService.jwtToken,
        );
      } else {
        debugPrint('🔔 [AuthState] Usuário deslogado');
        _userData = null;
        _registrationComplete = false;
        _clearLoginState();
        
        // 🛑 Parar monitoramento de pedidos
        OrderStatusListenerService.stopListeningToAllOrders();
        OrderStatusListenerService.clearCache();
        
        // 🛑 Desconectar Pusher
        OrderStatusPusherService.disconnect();
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
          await NotificationService.updateAuthToken(_authService.jwtToken!);
          debugPrint('🔔 [AuthState] Token FCM atualizado após login');
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
          await NotificationService.updateAuthToken(_authService.jwtToken!);
          debugPrint('🔔 [AuthState] Token FCM atualizado após cadastro');
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
        return;
      }
      
      debugPrint('✅ [AuthState] JWT token renovado com sucesso');
      
      // Agora verifica se o cadastro está completo
      final isComplete = await _authService.checkRegistrationComplete();
      _registrationComplete = isComplete;
      _userData = _authService.userData;
      _restaurantData = _authService.restaurantData;
      
      debugPrint('📋 [AuthState] Dados carregados - Complete: $isComplete');
      debugPrint('👤 [AuthState] userData: $_userData');
      
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

  /// 🚪 Logout
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    // 🔔 Limpar token FCM antes do logout
    await NotificationService.clearToken();
    
    // 🛑 Parar monitoramento de pedidos
    await OrderStatusListenerService.stopListeningToAllOrders();
    OrderStatusListenerService.clearCache();

    await _authService.signOut();
    
    _currentUser = null;
    _userData = null;
    _restaurantData = null;
    _registrationComplete = false;
    _error = null;
    _isLoading = false;
    
    notifyListeners();
    debugPrint('👋 [AuthState] Logout completo');
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
