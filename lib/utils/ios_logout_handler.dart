import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// 🍎 Handler Especializado para Logout no iOS
/// 
/// PROBLEMA: iOS Keychain mantém sessão Firebase ativa mesmo após signOut(),
/// causando auto-login indesejado ao reabrir o app.
/// 
/// SOLUÇÃO: Flag 'manual_logout' no SharedPreferences que previne auto-login
/// no _initAuth() + limpeza completa de dados locais ANTES do Firebase signOut.
/// 
/// BASEADO EM:
/// - Firebase iOS SDK Documentation
/// - Apple Keychain Services Guide
/// - Flutter Community Best Practices
class IOSLogoutHandler {
  static final IOSLogoutHandler _instance = IOSLogoutHandler._internal();
  factory IOSLogoutHandler() => _instance;
  IOSLogoutHandler._internal();

  bool _isLoggingOut = false;

  /// Executa logout completo no iOS de forma segura
  /// 
  /// ORDEM DE EXECUÇÃO (CRÍTICA):
  /// 1. Marca flag 'manual_logout' (ANTES de qualquer limpeza)
  /// 2. Limpa estados da aplicação (callbacks)
  /// 3. Limpa SharedPreferences (mantém apenas manual_logout)
  /// 4. Desconecta serviços externos (fire-and-forget)
  /// 5. Firebase signOut com timeout de segurança
  /// 6. Verificação final
  /// 
  /// IMPORTANTE: Android NÃO deve usar este handler!
  Future<bool> performLogout({
    required Future<void> Function() clearLocalState,
    required Future<void> Function() disconnectServices,
  }) async {
    if (!Platform.isIOS) {
      debugPrint('⚠️ [IOSLogoutHandler] Chamado em plataforma não-iOS');
      return false;
    }

    // Previne re-entrada (proteção contra múltiplos toques)
    if (_isLoggingOut) {
      debugPrint('⚠️ [IOSLogoutHandler] Logout já em andamento');
      return false;
    }

    _isLoggingOut = true;
    debugPrint('🍎 [IOSLogoutHandler] ===== INICIANDO LOGOUT iOS =====');

    try {
      // FASE 1: Marcar logout manual (CRÍTICO - ANTES de tudo)
      debugPrint('📝 [IOSLogoutHandler] FASE 1: Marcando logout manual');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('manual_logout', true);
      debugPrint('✅ Flag manual_logout definida');
      
      // FASE 2: Limpar estados da aplicação
      debugPrint('🗑️ [IOSLogoutHandler] FASE 2: Limpando estados locais');
      try {
        await clearLocalState();
        debugPrint('✅ Estados locais limpos');
      } catch (e) {
        debugPrint('⚠️ Erro ao limpar estados (continuando): $e');
      }
      
      // FASE 3: Limpar SharedPreferences (mantém manual_logout)
      debugPrint('🧹 [IOSLogoutHandler] FASE 3: Limpando SharedPreferences');
      final savedFlag = prefs.getBool('manual_logout') ?? false;
      await prefs.clear();
      if (savedFlag) {
        await prefs.setBool('manual_logout', true);
      }
      debugPrint('✅ SharedPreferences limpo (manual_logout preservado)');
      
      // FASE 4: Desconectar serviços (fire-and-forget - não bloqueia)
      debugPrint('📡 [IOSLogoutHandler] FASE 4: Desconectando serviços');
      disconnectServices().catchError((e) {
        debugPrint('⚠️ Erro ao desconectar serviços (ignorado): $e');
        return Future.value();
      });
      
      // Delay mínimo para serviços processarem
      await Future.delayed(const Duration(milliseconds: 150));
      debugPrint('✅ Serviços desconectados (async)');
      
      // FASE 5: Firebase SignOut com timeout de segurança
      debugPrint('🔥 [IOSLogoutHandler] FASE 5: Firebase SignOut');
      try {
        final auth = FirebaseAuth.instance;
        
        if (auth.currentUser != null) {
          debugPrint('👤 Usuário detectado: ${auth.currentUser?.email}');
          
          // SignOut com timeout de 2 segundos
          await Future.any([
            auth.signOut(),
            Future.delayed(const Duration(seconds: 2), () {
              debugPrint('⏱️ Timeout no signOut (continuando)');
            }),
          ]);
          
          // Aguardar propagação
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Verificar resultado
          if (auth.currentUser == null) {
            debugPrint('✅ Firebase signOut confirmado');
          } else {
            debugPrint('⚠️ Usuário ainda presente (Keychain mantém sessão)');
            debugPrint('💡 Flag manual_logout vai prevenir auto-login');
          }
        } else {
          debugPrint('ℹ️ Nenhum usuário Firebase para deslogar');
        }
      } catch (e) {
        debugPrint('❌ Erro no Firebase signOut (IGNORADO): $e');
        debugPrint('💡 Dados locais já foram limpos - logout efetivo');
      }
      
      // FASE 6: Validação final
      debugPrint('🔍 [IOSLogoutHandler] FASE 6: Validação final');
      await Future.delayed(const Duration(milliseconds: 200));
      
      final finalCheck = await SharedPreferences.getInstance();
      final hasManualLogout = finalCheck.getBool('manual_logout') ?? false;
      
      if (hasManualLogout) {
        debugPrint('✅ Flag manual_logout confirmada');
      } else {
        debugPrint('⚠️ Flag manual_logout perdida - redefinindo');
        await finalCheck.setBool('manual_logout', true);
      }
      
      debugPrint('🎉 [IOSLogoutHandler] ===== LOGOUT iOS CONCLUÍDO =====');
      debugPrint('💡 App vai para tela de login sem auto-login');
      
      return true;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [IOSLogoutHandler] ERRO CRÍTICO: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      
      // Garantir limpeza mínima mesmo com erro
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        await prefs.setBool('manual_logout', true);
        debugPrint('✅ Limpeza de emergência aplicada');
      } catch (_) {
        debugPrint('❌ Falha na limpeza de emergência');
      }
      
      return false;
      
    } finally {
      _isLoggingOut = false;
    }
  }
  
  /// Verifica se foi feito logout manual
  /// Usado no _initAuth() para prevenir auto-login após logout
  static Future<bool> wasManualLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flag = prefs.getBool('manual_logout') ?? false;
      
      if (flag) {
        debugPrint('🍎 [IOSLogoutHandler] Logout manual detectado');
      }
      
      return flag;
    } catch (e) {
      debugPrint('❌ [IOSLogoutHandler] Erro ao verificar manual_logout: $e');
      return false;
    }
  }
  
  /// Limpa a flag de logout manual
  /// Deve ser chamado APÓS login bem-sucedido
  static Future<void> clearManualLogoutFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('manual_logout');
      debugPrint('✅ [IOSLogoutHandler] Flag manual_logout removida');
    } catch (e) {
      debugPrint('❌ [IOSLogoutHandler] Erro ao limpar flag: $e');
    }
  }
}
