import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/services/operating_hours_service.dart';
import 'providers/catalog_provider.dart';
import 'state/cart_state.dart';
import 'state/user_state.dart';
import 'state/auth_state.dart';
import 'services/notification_service.dart';
import 'core/auth_wrapper.dart';
import 'pages/splash_video_page.dart';

// 🔥 Handler para notificações em background (deve ser top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('🚀 [MAIN] App iniciando...');
  
  // 🔥 Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint('🔥 [MAIN] Firebase inicializado com sucesso');
  
  // 🔍 DEBUG: Verificar se há usuário autenticado ANTES de qualquer outra coisa
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    debugPrint('✅ [MAIN] Usuário encontrado no Firebase Auth: ${currentUser.email}');
    debugPrint('✅ [MAIN] UID: ${currentUser.uid}');
    debugPrint('✅ [MAIN] Email verificado: ${currentUser.emailVerified}');
  } else {
    debugPrint('❌ [MAIN] Nenhum usuário autenticado encontrado no Firebase Auth');
  }

  // 🔔 Configurar handler de notificações em background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔔 Inicializar serviço de notificações
  await NotificationService.initialize();

  // 🕒 Atualizar horários de funcionamento ao iniciar o app
  debugPrint('🕒 Atualizando horários de funcionamento...');
  await OperatingHoursService.refreshOperatingHours();

  runApp(const MyApp());
}

// 🗺️ GlobalKey para navegação de qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔔 Configurar handler de cliques em notificações
    NotificationService.setNotificationClickHandler((orderId) {
      debugPrint('🔔 Navegando para pedido: $orderId');
      // Navegar para página de detalhes do pedido
      navigatorKey.currentState?.pushNamed('/order-details', arguments: orderId);
    });

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()), // 🔐 Autenticação
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => CartState()),
        ChangeNotifierProvider(create: (_) => UserState()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Pedejá',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF045146),
            primary: const Color(0xFF045146),
            secondary: const Color(0xFFE39110),
          ),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF045146),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE39110),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const SplashVideoPage(
          nextPage: AuthWrapper(),
        ), // ✅ Splash → Auto-login com Firebase
      ),
    );
  }
}
