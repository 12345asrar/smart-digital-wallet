import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBrown,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 75,
                color: AppColors.surfaceWhite,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'محفظتي الذكية',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.surfaceWhite,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'أمان وسرعة في كل معاملة',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.lightBrown.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
