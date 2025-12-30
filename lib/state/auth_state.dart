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
    debugPrint('🔧 [AuthState] _initAuth() chamado - verificando sessão Firebase');
    
    _isLoading = true;
    notifyListeners();

    try {
      // Verificar se há usuário no Firebase (persistência nativa do Firebase)
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        debugPrint('✅ [AuthState] Usuário Firebase encontrado: ${currentUser.email}');
        
        _currentUser = currentUser;
        
        // Carregar JWT e dados do backend
        final hasCredentials = await _authService.loadSavedCredentials();
        if (hasCredentials) {
          // ✅ SEMPRE renovar JWT mesmo com credenciais salvas
          // Isso garante que o token está válido e atualizado
          debugPrint('🔄 [AuthState] Credenciais encontradas - renovando JWT obrigatoriamente');
          
          final tokenRenewed = await _authService.refreshJWT();
          
          if (tokenRenewed && _authService.jwtToken != null) {
            // JWT renovado com sucesso
            await _authService.saveCredentials(
              currentUser.email ?? '', 
              _authService.jwtToken!
            );
            await _loadUserData(skipJwtRefresh: true);
            debugPrint('✅ [AuthState] JWT renovado e dados carregados');
          } else {
            // Se falhar renovação, forçar logout
            debugPrint('❌ [AuthState] Falha ao renovar JWT - forçando logout');
            await signOut();
          }
        } else {
          // Firebase tem sessão mas não temos JWT salvo
          // Vamos obter JWT do backend via Firebase token
          debugPrint('⚠️ [AuthState] Firebase OK mas sem JWT - renovando via backend');
          
          // ✅ CRÍTICO: refreshJWT() faz o exchange Firebase -> Backend JWT
          final tokenRenewed = await _authService.refreshJWT();
          
          if (tokenRenewed && _authService.jwtToken != null) {
            // Salvar JWT obtido do backend
            await _authService.saveCredentials(
              currentUser.email ?? '', 
              _authService.jwtToken!
            );
            
            // Carregar resto dos dados (userData, restaurantData, Pusher)
            // skipJwtRefresh=true porque já renovamos acima
            await _loadUserData(skipJwtRefresh: true);
            debugPrint('✅ [AuthState] JWT renovado e dados carregados');
          } else {
            debugPrint('❌ [AuthState] Falha ao renovar JWT - forçando logout');
            await signOut();
          }
        }
      } else {
        debugPrint('❌ [AuthState] Nenhum usuário no Firebase - usuário deslogado');
        // Garantir que não há credenciais salvas
        await _authService.clearCredentials();
      }
      
    } catch (e) {
      debugPrint('❌ [AuthState] Erro ao inicializar auth: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    // Listener do Firebase para mudanças de autenticação
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      debugPrint('🔔 [AuthState] authStateChanges: ${user?.email}');
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      } else {
        // Se Firebase deslogou, limpar tudo
        _currentUser = null;
        _userData = null;
        _restaurantData = null;
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
        
        // ✅ Inicializar Pusher para notificações em tempo real
        if (_userData != null && _authService.jwtToken != null) {
          final userId = _userData!['id'] ?? _userData!['uid'];
          if (userId != null) {
            debugPrint('📡 [AuthState] Inicializando Pusher após login');
            await OrderStatusPusherService.initialize(
              userId: userId,
              authToken: _authService.jwtToken,
            );
          }
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
  Future<void> _loadUserData({bool skipJwtRefresh = false}) async {
    try {
      // ✅ Renovar o JWT ao carregar dados (se necessário)
      if (!skipJwtRefresh) {
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
      } else {
        debugPrint('⏭️ [AuthState] Pulando renovação JWT - já foi renovado');
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
      debugPrint('🚪 [AuthState] Iniciando logout completo...');
      debugPrint('📱 [AuthState] Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      
      // 🍎 iOS CRÍTICO: Desabilitar persistência do Firebase ANTES do signOut
      // Isso evita que o Keychain mantenha a sessão ativa
      if (Platform.isIOS) {
        debugPrint('🍎 [AuthState] iOS: Configurando persistência para NONE...');
        try {
          // Isso força o Firebase a não salvar no Keychain
          await FirebaseAuth.instance.setPersistence(Persistence.NONE);
          debugPrint('✅ [AuthState] Persistência Firebase desabilitada');
        } catch (e) {
          debugPrint('⚠️ [AuthState] Erro ao desabilitar persistência: $e');
        }
      }
      
      // 🚨 CRÍTICO: Limpar SharedPreferences PRIMEIRO (antes de qualquer delay)
      final prefs = await SharedPreferences.getInstance();
      final keysBeforeClear = prefs.getKeys().length;
      await prefs.clear(); // Limpa TUDO
      debugPrint('✅ [AuthState] SharedPreferences limpo: $keysBeforeClear chaves removidas');
      
      // 🔔 Limpar token FCM antes do logout
      await NotificationService.clearToken();
      
      // 🛑 Parar monitoramento de pedidos
      await OrderStatusListenerService.stopListeningToAllOrders();
      OrderStatusListenerService.clearCache();

      // 🛑 Desconectar Pusher
      await OrderStatusPusherService.disconnect();
      
      // 🚪 Logout do Firebase + Limpar credenciais (AuthService faz limpeza pesada)
      await _authService.signOut();
      
      // 🗑️ Limpar TODOS os estados locais
      _currentUser = null;
      _userData = null;
      _restaurantData = null;
      _registrationComplete = false;
      _error = null;
      _isGuest = false;
      
      // 🍎 iOS: Verificação final e limpeza extra
      if (Platform.isIOS) {
        debugPrint('🍎 [AuthState] iOS - verificação final de logout...');
        await Future.delayed(Duration(milliseconds: 500));
        
        // Verificar se Firebase realmente deslogou
        final stillLoggedIn = FirebaseAuth.instance.currentUser;
        if (stillLoggedIn != null) {
          debugPrint('❌ [AuthState] CRÍTICO: iOS ainda tem usuário! UID: ${stillLoggedIn.uid}');
          debugPrint('❌ [AuthState] Email: ${stillLoggedIn.email}, Providers: ${stillLoggedIn.providerData.length}');
          
          // Forçar persistência NONE novamente
          try {
            await FirebaseAuth.instance.setPersistence(Persistence.NONE);
            debugPrint('🍎 [AuthState] Persistência reforçada: NONE');
          } catch (e) {
            debugPrint('⚠️ [AuthState] Erro ao reforçar persistência: $e');
          }
          
          // Forçar signOut múltiplas vezes
          for (int i = 0; i < 3; i++) {
            await FirebaseAuth.instance.signOut();
            await Future.delayed(Duration(milliseconds: 200));
            
            final checkUser = FirebaseAuth.instance.currentUser;
            if (checkUser == null) {
              debugPrint('✅ [AuthState] iOS logout bem-sucedido na tentativa ${i + 1}');
              break;
            } else {
              debugPrint('⚠️ [AuthState] Tentativa ${i + 1}/3 - Usuário ainda presente: ${checkUser.uid}');
            }
          }
          
          // Se ainda estiver logado, forçar limpeza final
          final finalCheck = FirebaseAuth.instance.currentUser;
          if (finalCheck != null) {
            debugPrint('❌ [AuthState] FALHA CRÍTICA após 3 tentativas!');
            debugPrint('❌ [AuthState] Usuário teimoso: ${finalCheck.uid}');
            
            final prefs2 = await SharedPreferences.getInstance();
            await prefs2.clear(); // Segunda limpeza (garantia)
            
            // Garantir que AuthService não tem token
            await _authService.clearCredentials();
            
            debugPrint('⚠️ [AuthState] Limpeza forçada aplicada - pode requerer reinício do app');
          }
        } else {
          debugPrint('✅ [AuthState] iOS logout confirmado - Firebase limpo');
        }
        
        // IMPORTANTE: Verificar se não tem credenciais salvas que causariam auto-login
        final prefsCheck = await SharedPreferences.getInstance();
        final allKeys = prefsCheck.getKeys();
        final hasLoginData = prefsCheck.containsKey('isLoggedIn') || 
                             prefsCheck.containsKey('jwtToken') ||
                             prefsCheck.containsKey('userEmail');
        
        debugPrint('🔍 [AuthState] Verificação final - Total de chaves: ${allKeys.length}');
        if (hasLoginData) {
          debugPrint('⚠️ [AuthState] CRÍTICO: Ainda há dados de login!');
          debugPrint('⚠️ [AuthState] Chaves encontradas: ${allKeys.where((k) => k.contains('login') || k.contains('token') || k.contains('email'))}');
          await prefsCheck.clear();
          debugPrint('🗑️ [AuthState] Limpeza adicional executada');
        } else {
          debugPrint('✅ [AuthState] Verificado: Nenhum dado de login restante');
        }
        
        // 🔐 CRÍTICO: Restaurar persistência LOCAL para próximo login
        // Sem isso, chat/pusher/notificações não funcionarão após novo login
        debugPrint('🔐 [AuthState] Restaurando persistência LOCAL...');
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint('✅ [AuthState] Persistência LOCAL restaurada - próximo login funcionará normalmente');
        } catch (e) {
          debugPrint('⚠️ [AuthState] Erro ao restaurar persistência: $e');
        }
      }
      
      _isLoading = false;
      notifyListeners();
      
      debugPrint('✅ [AuthState] Logout completo e verificado');
    } catch (e) {
      debugPrint('❌ [AuthState] Erro no logout: $e');
      
      // Mesmo com erro, limpar tudo
      _currentUser = null;
      _userData = null;
      _restaurantData = null;
      _registrationComplete = false;
      _error = null;
      _isGuest = false;
      _isLoading = false;
      
      // Tentar limpar SharedPreferences mesmo com erro
      try {
        await _clearLoginState();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
      
      // 🔐 IMPORTANTE: Restaurar persistência mesmo com erro
      if (Platform.isIOS) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint('✅ [AuthState] Persistência LOCAL restaurada após erro');
        } catch (_) {
          debugPrint('⚠️ [AuthState] Não foi possível restaurar persistência');
        }
      }
      
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
