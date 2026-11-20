import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/wallet_service.dart';

class TransferScreen extends StatefulWidget {
  final String senderPhone;

  const TransferScreen({super.key, required this.senderPhone});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String? _recipientName;
  bool _isLoadingName = false;
  bool _isTransferring = false;

  void _onPhoneChanged(String phone) async {
    if (phone.trim().length < 9) {
      setState(() => _recipientName = null);
      return;
    }
    setState(() => _isLoadingName = true);
    final name = await WalletService.lookupRecipientName(phone.trim());
    setState(() {
      _isLoadingName = false;
      _recipientName = name ?? '❌ الرقم غير مسجل في المحفظة';
    });
  }

  void _confirmAndTransfer() {
    final recipientPhone = _phoneCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (recipientPhone.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء الحقول بمبلغ ورقم هاتف صحيح')));
      return;
    }

    if (_recipientName == null || _recipientName!.startsWith('❌')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المستلم غير مسجل في المحفظة')));
      return;
    }

    final pinCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تأكيد عملية التحويل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('تحويل $amount ر.ي إلى $_recipientName ($recipientPhone)', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'أدخل رمز PIN الخاص بك', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isTransferring = true);
                try {
                  final ref = await WalletService.transferMoney(
                    senderPhone: widget.senderPhone,
                    recipientPhone: recipientPhone,
                    amount: amount,
                    senderPin: pinCtrl.text.trim(),
                    note: _noteCtrl.text.trim(),
                  );
                  if (!mounted) return;
                  setState(() => _isTransferring = false);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('تم التحويل بنجاح ✅'),
                      content: Text('رقم المرجع: $ref\nالمبلغ: $amount ر.ي\nالمستلم: $_recipientName'),
                      actions: [
                        TextButton(onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        }, child: const Text('إغلاق'))
                      ],
                    ),
                  );
                } catch (e) {
                  setState(() => _isTransferring = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
                }
              },
              child: const Text('تأكيد التحويل الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل أموال فوري'), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              onChanged: _onPhoneChanged,
              decoration: InputDecoration(
                labelText: 'رقم هاتف المستلم',
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: _isLoadingName ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_recipientName != null) ...[
              const SizedBox(height: 8),
              Text('المستلم: $_recipientName', style: TextStyle(color: _recipientName!.startsWith('❌') ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ (ريال يمني)',
                prefixIcon: const Icon(Icons.money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isTransferring ? null : _confirmAndTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isTransferring ? const CircularProgressIndicator(color: Colors.white) : const Text('متابعة التحويل', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}