import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';


void main() {
  runApp(const LiveLocalApp());
}

class LiveLocalApp extends StatelessWidget {
  const LiveLocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiveLocal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF2D6A4F),
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D6A4F),
          primary: const Color(0xFF2D6A4F),
          secondary: const Color(0xFF74C69D),
          background: Colors.white,
          surface: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2D6A4F),
            side: const BorderSide(color: Color(0xFF2D6A4F)),
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) =>
            Scaffold(
              appBar: AppBar(
                title: const Text('LiveLocal'),
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2D6A4F),
                elevation: 0,
              ),
              body: const Center(
                child: Text('Home screen coming soon!'),
              ),
            ),
      },
    );
  }
}