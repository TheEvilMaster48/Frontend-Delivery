import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  // Asegura que los bindings de Flutter estén listos antes de Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Inicialización de Firebase
    await Firebase.initializeApp();
    print("Conexión con Firebase establecida correctamente.");
  } catch (e) {
    print("Error crítico inicializando Firebase: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery App',
      debugShowCheckedModeBanner: false,
      
      // Configuración de Tema Global
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pink,
          primary: Colors.pink[600],
          secondary: Colors.pinkAccent,
        ),
        
        // Estilo global para botones elevados
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
        
        // Estilo global para campos de texto (Inputs)
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
      
      // Pantalla inicial
      home: const LoginScreen(),
    );
  }
}
