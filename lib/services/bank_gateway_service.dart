import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BankEnvironment { sandbox, production }

class BankGatewayService {
  static BankEnvironment currentEnvironment = BankEnvironment.sandbox;
  static String kuraimiMerchantId = "KRM-MERCHANT-884920";
  static String kuraimiApiKey = "live_sk_kuraimi_8f7b2a9e01c4d5e";
  static String kuraimiApiBaseUrl = "https://api.kuraimibank.com/v1";

  /// 1. إرسال طلب سحب من حساب الكريمي وتوليد رمز OTP
  static Future<Map<String, dynamic>> initiateKuraimiDebit({
    required String userPhone,
    required String kuraimiAccountNumber,
    required double amount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final sessionId = "SES-KRM-${DateTime.now().millisecondsSinceEpoch}";
    final mockOtp = (100000 + Random().nextInt(900000)).toString();

    await FirebaseFirestore.instance.collection('bank_sessions').doc(sessionId).set({
      'user_phone': userPhone,
      'account_number': kuraimiAccountNumber,
      'amount': amount,
      'status': 'PENDING_OTP',
      'otp': mockOtp,
      'created_at': FieldValue.serverTimestamp(),
    });

    return {
      'success': true,
      'sessionId': sessionId,
      'demoOtp': mockOtp,
      'message': 'تم إرسال رمز الأمان OTP من بنك الكريمي بنجاح',
    };
  }

  /// 2. تأكيد رمز OTP وخصم المبلغ من الكريمي وإيداعه في المحفظة
  static Future<Map<String, dynamic>> confirmKuraimiDebit({
    required String sessionId,
    required String enteredOtp,
    required String userPhone,
  }) async {
    final sessionRef = FirebaseFirestore.instance.collection('bank_sessions').doc(sessionId);
    final sessionSnap = await sessionRef.get();

    if (!sessionSnap.exists) {
      throw Exception('انتهت صلاحية جلسة البنك، يرجى إعادة المحاولة');
    }

    final data = sessionSnap.data()!;
    final realOtp = data['otp'] as String;
    final amount = (data['amount'] as num).toDouble();
    final accountNumber = data['account_number'] as String;

    if (enteredOtp.trim() != realOtp.trim()) {
      throw Exception('رمز OTP غير صحيح، يرجى التأكد وإعادة الإدخال');
    }

    final bankRef = "KRM-TXN-${Random().nextInt(9000000) + 1000000}";
    final userRef = FirebaseFirestore.instance.collection('users').doc(userPhone);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw Exception('المستخدم غير مسجل');

      final currentBalance = (userSnap.data()?['balance'] ?? 0.0) as num;
      final newBalance = currentBalance.toDouble() + amount;

      tx.update(userRef, {
        'balance': newBalance,
        'last_topup': FieldValue.serverTimestamp(),
      });

      final txRef = FirebaseFirestore.instance.collection('transactions').doc();
      tx.set(txRef, {
        'type': 'BANK_DEPOSIT',
        'title': 'تغذية من حساب بنك الكريمي',
        'sender_phone': 'KURAIMI_BANK',
        'recipient_phone': userPhone,
        'amount': amount,
        'currency': 'YER',
        'reference_number': bankRef,
        'bank_account': accountNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'SUCCESS',
      });

      tx.update(sessionRef, {
        'status': 'COMPLETED',
        'bank_reference': bankRef,
        'completed_at': FieldValue.serverTimestamp(),
      });
    });

    return {
      'success': true,
      'bankReference': bankRef,
      'amount': amount,
      'message': 'تم خصم المبلغ من حسابك في الكريمي وإيداعه في محفظتك بنجاح',
    };
  }

  /// 3. إيداع كاش عبر الصراف أو الوكيل المعتمد (Cash-In)
  static Future<Map<String, dynamic>> agentCashDeposit({
    required String agentPhone,
    required String agentName,
    required String customerPhone,
    required double amount,
    required String notes,
  }) async {
    final customerRef = FirebaseFirestore.instance.collection('users').doc(customerPhone);
    final customerSnap = await customerRef.get();

    if (!customerSnap.exists) {
      throw Exception('رقم هاتف العميل غير مسجل في المحفظة');
    }

    final customerData = customerSnap.data()!;
    final customerName = customerData['full_name'] ?? 'عميل محفظتي';
    final receiptNum = "AGT-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(customerRef);
      final currentBalance = (snap.data()?['balance'] ?? 0.0) as num;

      tx.update(customerRef, {
        'balance': currentBalance.toDouble() + amount,
      });

      final logRef = FirebaseFirestore.instance.collection('transactions').doc();
      tx.set(logRef, {
        'type': 'AGENT_CASH_IN',
        'title': 'إيداع نقدي عبر الصراف / الوكيل',
        'agent_phone': agentPhone,
        'agent_name': agentName,
        'sender_phone': agentPhone,
        'recipient_phone': customerPhone,
        'recipient_name': customerName,
        'amount': amount,
        'currency': 'YER',
        'reference_number': receiptNum,
        'notes': notes,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'SUCCESS',
      });
    });

    return {
      'success': true,
      'receiptNumber': receiptNum,
      'customerName': customerName,
      'amount': amount,
    };
  }
}