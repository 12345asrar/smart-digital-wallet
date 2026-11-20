import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../services/bank_gateway_service.dart';

class AgentPortalScreen extends StatefulWidget {
  const AgentPortalScreen({super.key});

  @override
  State<AgentPortalScreen> createState() => _AgentPortalScreenState();
}

class _AgentPortalScreenState extends State<AgentPortalScreen> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _detectedCustomerName;
  bool _isLoadingName = false;
  bool _isSubmitting = false;

  void _lookupCustomer(String phone) async {
    if (phone.trim().length < 9) {
      setState(() => _detectedCustomerName = null);
      return;
    }
    setState(() => _isLoadingName = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(phone.trim()).get();
      if (doc.exists) {
        setState(() => _detectedCustomerName = doc.data()?['full_name'] ?? 'مستخدم بدون اسم');
      } else {
        setState(() => _detectedCustomerName = '❌ الرقم غير مسجل');
      }
    } catch (_) {
      setState(() => _detectedCustomerName = null);
    } finally {
      setState(() => _isLoadingName = false);
    }
  }

  void _processCashDeposit() async {
    final phone = _phoneCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (phone.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة رقم الهاتف ومبلغ صحيح')),
      );
      return;
    }

    if (_detectedCustomerName == null || _detectedCustomerName!.startsWith('❌')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرقم المدخل غير مسجل في النظام')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await BankGatewayService.agentCashDeposit(
        agentPhone: "777000111",
        agentName: "مركز الكريمي / الصراف المعتمد",
        customerPhone: phone,
        amount: amount,
        notes: _notesCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 8),
              Text('سند إيداع نقدي رسمي'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم السند: ${result['receiptNumber']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              Text('اسم العميل: ${result['customerName']}'),
              Text('رقم الهاتف: $phone'),
              Text('المبلغ المودع: ${result['amount']} ر.ي', style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('تم استلام النقد وتغذية المحفظة بنجاح ✅', style: TextStyle(color: AppColors.success, fontSize: 13)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _phoneCtrl.clear();
                _amountCtrl.clear();
                _notesCtrl.clear();
                setState(() => _detectedCustomerName = null);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('تم وطباعة السند', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بوابة الوكيل والصراف المعتمد'),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryDark.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.storefront, color: AppColors.primaryDark, size: 36),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('نقطة إيداع نقدي (Cash-In)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('استلام الكاش وتغذية المحفظة فورياً بالاسم ورقم الهاتف', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: _lookupCustomer,
              decoration: InputDecoration(
                labelText: 'رقم هاتف العميل المراد تغذيته',
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: _isLoadingName
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_detectedCustomerName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _detectedCustomerName!.startsWith('❌') ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'اسم المستلم: $_detectedCustomerName',
                  style: TextStyle(
                    color: _detectedCustomerName!.startsWith('❌') ? Colors.red : Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ المستلم كاش (ر.ي)',
                prefixIcon: const Icon(Icons.money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                labelText: 'ملاحظات العملية (اختياري)',
                prefixIcon: const Icon(Icons.edit_note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _processCashDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تأكيد استلام الكاش وتغذية الحساب فوراً', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}