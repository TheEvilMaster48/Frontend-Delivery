import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/auth/login_screen.dart';
import 'services/notificacion_service.dart';

// HANDLER PARA NOTIFICACIONES EN SEGUNDO PLANO (BACKGROUND/TERMINADA)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('FCM BACKGROUND: ${message.messageId} DATA=${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("Conexión con Firebase establecida correctamente.");
  } catch (e) {
    print("Error crítico inicializando Firebase: $e");
  }

  // CONFIGURA EL HANDLER DE BACKGROUND UNA SOLA VEZ
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // INICIALIZA LISTENERS GLOBALES DE FCM (NO DEPENDE DE USUARIO LOGUEADO)
  NotificationService().setupGlobalListeners();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery App',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          primary: Colors.pink[600],
          secondary: Colors.pinkAccent,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink[600],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.pink[600]!, width: 2),
          ),
        ),
      ),

      home: const LoginScreen(),
    );
  }
}
