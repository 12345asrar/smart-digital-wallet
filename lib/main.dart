import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants/app_colors.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تفعيل الاتصال بالسحابة بمفاتيحك الخاصة
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAnr5yTpO2V_G1SFfmsv445wGCFVTyPvJc",
      authDomain: "smart-wallet-8e573.firebaseapp.com",
      projectId: "smart-wallet-8e573",
      storageBucket: "smart-wallet-8e573.firebasestorage.app",
      messagingSenderId: "871953818307",
      appId: "1:871953818307:web:846fc71f002c796a93f876",
      measurementId: "G-G36R8GL6B5",
    ),
  );

  runApp(const SmartWalletApp());
}

class SmartWalletApp extends StatelessWidget {
  const SmartWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'محفظتي الذكية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primaryBrown,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBrown,
          primary: AppColors.primaryBrown,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}