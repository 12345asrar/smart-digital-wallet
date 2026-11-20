import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // تسجيل مستخدم جديد
  static Future<void> registerNewUser({
    required String phone,
    required String fullName,
    String? nationalId,
    String? idNumber,
    required String pin,
  }) async {
    final userRef = _db.collection('users').doc(phone);
    final snap = await userRef.get();
    if (snap.exists) {
      throw Exception('رقم الهاتف مسجل مسبقاً، يرجى تسجيل الدخول');
    }

    await userRef.set({
      'phone': phone,
      'full_name': fullName,
      'national_id': nationalId ?? idNumber ?? '',
      'pin': pin,
      'balance': 0.0,
      'kuraimi_account': '',
      'is_verified': true,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // تسجيل الدخول
  static Future<Map<String, dynamic>> login({
    required String phone,
    required String pin,
  }) async {
    final userRef = _db.collection('users').doc(phone);
    final snap = await userRef.get();

    if (!snap.exists) {
      throw Exception('الحساب غير موجود، يرجى إنشاء حساب جديد');
    }

    final data = snap.data()!;
    if (data['pin'] != pin) {
      throw Exception('رمز PIN غير صحيح');
    }

    return data;
  }

  // البحث عن اسم المستلم برقم هاتفه
  static Future<String?> lookupRecipientName(String phone) async {
    final snap = await _db.collection('users').doc(phone.trim()).get();
    if (snap.exists) {
      return snap.data()?['full_name'] as String?;
    }
    return null;
  }

  // تحويل أموال P2P فوري
  static Future<String> transferMoney({
    required String senderPhone,
    required String recipientPhone,
    required double amount,
    required String senderPin,
    String? note,
  }) async {
    if (senderPhone == recipientPhone) {
      throw Exception('لا يمكنك التحويل لنفس رقم هاتفك');
    }

    final senderRef = _db.collection('users').doc(senderPhone);
    final recipientRef = _db.collection('users').doc(recipientPhone);

    final senderSnap = await senderRef.get();
    if (!senderSnap.exists) throw Exception('حساب المرسل غير موجود');
    final senderData = senderSnap.data()!;

    if (senderData['pin'] != senderPin) {
      throw Exception('رمز PIN الخاص بك غير صحيح');
    }

    final senderBalance = (senderData['balance'] as num).toDouble();
    if (senderBalance < amount) {
      throw Exception('عفواً، رصيدك الحالي ($senderBalance ر.ي) غير كافٍ');
    }

    final recipientSnap = await recipientRef.get();
    if (!recipientSnap.exists) {
      throw Exception('المستلم غير مسجل في المحفظة الذكية');
    }
    final recipientData = recipientSnap.data()!;
    final recipientName = recipientData['full_name'] ?? recipientPhone;

    final refCode = "TRX-${Random().nextInt(900000) + 100000}";

    await _db.runTransaction((tx) async {
      tx.update(senderRef, {'balance': senderBalance - amount});
      final currentRecipientBal = (recipientData['balance'] as num).toDouble();
      tx.update(recipientRef, {'balance': currentRecipientBal + amount});

      final txDoc = _db.collection('transactions').doc();
      tx.set(txDoc, {
        'type': 'P2P_TRANSFER',
        'title': 'تحويل إلى $recipientName',
        'sender_phone': senderPhone,
        'recipient_phone': recipientPhone,
        'recipient_name': recipientName,
        'amount': amount,
        'currency': 'YER',
        'reference_number': refCode,
        'note': note ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'SUCCESS',
      });
    });

    return refCode;
  }

  // ربط حساب الكريمي
  static Future<void> linkKuraimiAccount({
    required String phone,
    required String kuraimiAccount,
  }) async {
    await _db.collection('users').doc(phone).update({
      'kuraimi_account': kuraimiAccount,
    });
  }

  // إيداع بنكي
  static Future<String> bankDeposit({
    required String phone,
    required String bankName,
    required String accountNumber,
    required double amount,
  }) async {
    final ref = "BNK-${Random().nextInt(900000) + 100000}";
    final userRef = _db.collection('users').doc(phone);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final current = (snap.data()?['balance'] ?? 0.0) as num;
      tx.update(userRef, {'balance': current.toDouble() + amount});

      final log = _db.collection('transactions').doc();
      tx.set(log, {
        'type': 'BANK_DEPOSIT',
        'title': 'إيداع من $bankName',
        'sender_phone': bankName,
        'recipient_phone': phone,
        'amount': amount,
        'currency': 'YER',
        'reference_number': ref,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'SUCCESS',
      });
    });
    return ref;
  }

  // تحويل إلى بنك
  static Future<String> transferToBank({
    required String phone,
    required String bankName,
    required String accountNumber,
    required double amount,
  }) async {
    final ref = "WTH-${Random().nextInt(900000) + 100000}";
    final userRef = _db.collection('users').doc(phone);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final current = (snap.data()?['balance'] ?? 0.0) as num;
      if (current < amount) throw Exception('رصيدك غير كافٍ للتحويل للبنك');

      tx.update(userRef, {'balance': current.toDouble() - amount});

      final log = _db.collection('transactions').doc();
      tx.set(log, {
        'type': 'BANK_WITHDRAW',
        'title': 'تحويل إلى $bankName ($accountNumber)',
        'sender_phone': phone,
        'recipient_phone': bankName,
        'amount': amount,
        'currency': 'YER',
        'reference_number': ref,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'SUCCESS',
      });
    });
    return ref;
  }

  // طلب سحب كاش
  static Future<String> requestCashOut({
    required String phone,
    required double amount,
  }) async {
    final code = (100000 + Random().nextInt(900000)).toString();
    final userRef = _db.collection('users').doc(phone);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final current = (snap.data()?['balance'] ?? 0.0) as num;
      if (current < amount) throw Exception('رصيدك غير كافٍ لسحب هذا المبلغ');

      tx.update(userRef, {'balance': current.toDouble() - amount});

      final log = _db.collection('transactions').doc();
      tx.set(log, {
        'type': 'CASH_OUT',
        'title': 'رمز سحب كاش عبر الصراف',
        'sender_phone': phone,
        'recipient_phone': 'AGENT_CASH',
        'amount': amount,
        'currency': 'YER',
        'reference_number': code,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'PENDING_PICKUP',
      });
    });
    return code;
  }

  // سداد فواتير
  static Future<String> payBill({
    required String phone,
    required String billType,
    required String targetNumber,
    required double amount,
  }) async {
    final ref = "BIL-${Random().nextInt(900000) + 100000}";
    final userRef = _db.collection('users').doc(phone);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final current = (snap.data()?['balance'] ?? 0.0) as num;
      if (current < amount) throw Exception('رصيد المحفظة غير كافٍ للسداد');

      tx.update(userRef, {'balance': current.toDouble() - amount});

      final log = _db.collection('transactions').doc();
      tx.set(log, {
        'type': 'BILL_PAYMENT',
        'title': 'سداد فاتورة $billType ($targetNumber)',
        'sender_phone': phone,
        'recipient_phone': billType,
        'amount': amount,
        'currency': 'YER',
        'reference_number': ref,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'SUCCESS',
      });
    });
    return ref;
  }

  // دفع لتاجر
  static Future<String> payMerchant({
    required String phone,
    required String merchantId,
    required double amount,
  }) async {
    final ref = "MRC-${Random().nextInt(900000) + 100000}";
    final userRef = _db.collection('users').doc(phone);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final current = (snap.data()?['balance'] ?? 0.0) as num;
      if (current < amount) throw Exception('رصيدك غير كافٍ للدفع للتاجر');

      tx.update(userRef, {'balance': current.toDouble() - amount});

      final log = _db.collection('transactions').doc();
      tx.set(log, {
        'type': 'MERCHANT_PAY',
        'title': 'دفع مشتريات للتاجر ($merchantId)',
        'sender_phone': phone,
        'recipient_phone': merchantId,
        'amount': amount,
        'currency': 'YER',
        'reference_number': ref,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'SUCCESS',
      });
    });
    return ref;
  }

  // بث بيانات المستخدم لحظياً
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamWallet(String phone) {
    return _db.collection('users').doc(phone).snapshots();
  }

  // بث سجل العمليات لحظياً
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamTransactions(String phone) {
    return _db.collection('transactions')
        .where('recipient_phone', isEqualTo: phone)
        .snapshots();
  }
}