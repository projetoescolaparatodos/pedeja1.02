import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../pages/onboarding/onboarding_page.dart';
import '../pages/home/home_page.dart';

/// 🔐 Widget que gerencia a navegação baseada no estado de autenticação
/// 
/// Verifica estado do AuthState e redireciona:
/// - Se loading → Splash/Loading
/// - Se usuário logado → HomePage
/// - Se não logado → OnboardingPage
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔐 [AuthWrapper] build() chamado');
    
    return Consumer<AuthState>(
      builder: (context, authState, child) {
        debugPrint('🔀 [AuthWrapper] Consumer update: isLoading=${authState.isLoading}, isAuthenticated=${authState.isAuthenticated}');
        
        // 1️⃣ Carregando (fazendo auto-login)
        if (authState.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF022E28),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFE39110),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // 2️⃣ Está logado OU é convidado
        if (authState.isAuthenticated || authState.isGuest) {
          debugPrint('✅ [AuthWrapper] Usuário autenticado ou convidado, indo para HomePage');
          return const HomePage();
        }
        
        // 3️⃣ Não está logado
        debugPrint('❌ [AuthWrapper] Usuário não autenticado, indo para OnboardingPage');
        return const OnboardingPage();
      },
    );
  }
}
