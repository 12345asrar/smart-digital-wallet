import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/wallet_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    final phone = _phoneCtrl.text.trim();
    final pin = _pinCtrl.text.trim();

    if (phone.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String displayName = 'المستخدم';

      if (isLoginMode) {
        final userData = await WalletService.login(phone: phone, pin: pin);
        displayName = userData['full_name'] ?? 'المستخدم';
      } else {
        final fullName = _nameCtrl.text.trim();
        final idNum = _idCtrl.text.trim();
        if (fullName.isEmpty || idNum.isEmpty) {
          throw Exception('يرجى كتابة الاسم ورقم الهوية');
        }
        await WalletService.registerNewUser(
          phone: phone,
          fullName: fullName,
          nationalId: idNum,
          pin: pin,
        );
        displayName = fullName;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(userPhone: phone, userName: displayName),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_balance_wallet, size: 64, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  isLoginMode ? 'تسجيل الدخول للمحفظة' : 'إنشاء حساب محفظة ذكية',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 24),
                if (!isLoginMode) ...[
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'الاسم الرباعي الكامل',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'الرقم الوطني / الهوية الشخصية',
                      prefixIcon: const Icon(Icons.badge),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف (مثال: 777123456)',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'رمز الدخول السري (PIN من 4 أرقام)',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isLoginMode ? 'دخول المحفظة' : 'تسجيل وبدء الاستخدام',
                          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => isLoginMode = !isLoginMode),
                  child: Text(
                    isLoginMode ? 'ليس لديك حساب؟ إنشاء حساب جديد' : 'لديك حساب بالفعل؟ تسجيل الدخول',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}