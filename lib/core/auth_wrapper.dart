import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../pages/onboarding/onboarding_page.dart';
import '../pages/home/home_page.dart';

/// 🔐 Widget que gerencia a navegação baseada no estado de autenticação
/// 
/// Verifica autenticação do Firebase e redireciona:
/// - Se usuário logado → HomePage
/// - Se não logado → OnboardingPage
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔄 Carregando
        if (snapshot.connectionState == ConnectionState.waiting) {
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

        // ✅ Verificar se usuário está logado
        final user = snapshot.data;
        
        if (user != null) {
          debugPrint('🔐 [AuthWrapper] Usuário logado: ${user.email}');
          
          // Carregar dados do usuário se necessário
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final authState = Provider.of<AuthState>(context, listen: false);
            if (authState.userData == null) {
              debugPrint('🔄 [AuthWrapper] Carregando dados do usuário...');
            }
          });
          
          return const HomePage();
        }

        // ❌ Usuário não logado → Onboarding/Login
        debugPrint('🔐 [AuthWrapper] Usuário não autenticado');
        return const OnboardingPage();
      },
    );
  }
}
