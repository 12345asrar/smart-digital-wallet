import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../services/wallet_service.dart';
import '../services/bank_gateway_service.dart';
import 'transfer_screen.dart';
import 'agent_portal_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userPhone;
  final String? userName;

  const DashboardScreen({
    super.key,
    required this.userPhone,
    this.userName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _showKuraimiTopUpModal(BuildContext context, String? linkedAccount) {
    final amountCtrl = TextEditingController();
    final accCtrl = TextEditingController(text: linkedAccount ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance, color: AppColors.kuraimiYellow, size: 28),
                SizedBox(width: 8),
                Text('تغذية مباشرة من بنك الكريمي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accCtrl,
              decoration: const InputDecoration(
                labelText: 'رقم حساب الكريمي (المميز)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المراد سحبه إلى المحفظة (ر.ي)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kuraimiYellow,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                final acc = accCtrl.text.trim();
                if (amount <= 0 || acc.isEmpty) return;

                Navigator.pop(ctx);

                final initResult = await BankGatewayService.initiateKuraimiDebit(
                  userPhone: widget.userPhone,
                  kuraimiAccountNumber: acc,
                  amount: amount,
                );

                if (!mounted) return;
                _showOtpVerificationDialog(initResult['sessionId'], initResult['demoOtp'], amount);
              },
              child: const Text('طلب رمز التأكيد البنكي (OTP)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showOtpVerificationDialog(String sessionId, String demoOtp, double amount) {
    final otpCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد سحب بنك الكريمي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('تم إرسال كود التأكيد OTP من البنك لهاتفك المسجل.\n(الكود للتجربة: $demoOtp)', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
            const SizedBox(height: 14),
            TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: '------', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                final res = await BankGatewayService.confirmKuraimiDebit(
                  sessionId: sessionId,
                  enteredOtp: otpCtrl.text.trim(),
                  userPhone: widget.userPhone,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ ${res['message']} - رقم الحركة: ${res['bankReference']}'), backgroundColor: AppColors.success),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('تأكيد الخصم والإيداع', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('محفظتي الذكية - ${widget.userName ?? "المستخدم"}', style: const TextStyle(fontSize: 16)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentPortalScreen())),
            icon: const Icon(Icons.storefront, color: Colors.white, size: 20),
            label: const Text('شاشة الصراف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: WalletService.streamWallet(widget.userPhone),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data();
          final balance = (userData?['balance'] ?? 0.0) as num;
          final kuraimiAcc = userData?['kuraimi_account'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الرصيد المتاح حالياً', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(balance.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          const Text('ريال يمني', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('رقم الحساب: ${widget.userPhone}', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.kuraimiYellow.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.kuraimiYellow,
                        child: Icon(Icons.account_balance, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('بنك الكريمي للتمويل الأصغر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(kuraimiAcc != null && kuraimiAcc.isNotEmpty ? 'حساب: $kuraimiAcc' : 'الربط عبر رقم الحساب وبوابة المميز', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showKuraimiTopUpModal(context, kuraimiAcc),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.kuraimiYellow, foregroundColor: Colors.black),
                        child: const Text('تغذية الحساب'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _buildActionItem(Icons.send, 'تحويل فوري', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TransferScreen(senderPhone: widget.userPhone)));
                    }),
                    _buildActionItem(Icons.store, 'إيداع صراف', () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AgentPortalScreen()));
                    }),
                    _buildActionItem(Icons.receipt_long, 'سداد فواتير', () => _showBillDialog(context)),
                    _buildActionItem(Icons.money_off, 'سحب كاش', () => _showCashOutDialog(context)),
                    _buildActionItem(Icons.qr_code_scanner, 'دفع لتاجر', () => _showMerchantDialog(context)),
                    _buildActionItem(Icons.account_balance, 'حساب بنكي', () => _showKuraimiTopUpModal(context, kuraimiAcc)),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('سجل الحركات المالية المباشر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: WalletService.streamTransactions(widget.userPhone),
                  builder: (context, txSnap) {
                    if (!txSnap.hasData || txSnap.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('لا توجد عمليات سابقة بعد', style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: txSnap.data!.docs.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final tx = txSnap.data!.docs[index].data();
                        final amount = tx['amount'] ?? 0;
                        final title = tx['title'] ?? 'عملية مالية';
                        final ref = tx['reference_number'] ?? '';

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Icon(Icons.swap_horiz, color: Colors.white),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('مرجع: $ref'),
                          trailing: Text(
                            '+$amount ر.ي',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showBillDialog(BuildContext ctx) {
    final numCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('سداد فواتير وشحن رصيد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف أو المشترك (يمن موبايل / سبأفون / كهرباء)')),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (ر.ي)')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              Navigator.pop(c);
              await WalletService.payBill(phone: widget.userPhone, billType: 'يمن موبايل', targetNumber: numCtrl.text.trim(), amount: amt);
            },
            child: const Text('سداد فوري'),
          )
        ],
      ),
    );
  }

  void _showCashOutDialog(BuildContext ctx) {
    final amtCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('طلب سحب نقدي عبر الصراف'),
        content: TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المراد سحبه (ر.ي)')),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              Navigator.pop(c);
              final code = await WalletService.requestCashOut(phone: widget.userPhone, amount: amt);
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('رمز السحب النقدي جاهز'),
                  content: Text('أعطِ هذا الرمز للصراف لاستلام أموالك:\n\n$code', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary), textAlign: TextAlign.center),
                ),
              );
            },
            child: const Text('توليد رمز السحب'),
          )
        ],
      ),
    );
  }

  void _showMerchantDialog(BuildContext ctx) {
    final mrcCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('دفع لمحل تجاري / نقطة بيع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: mrcCtrl, decoration: const InputDecoration(labelText: 'رقم أو كود التاجر')),
            TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (ر.ي)')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              if (amt <= 0) return;
              Navigator.pop(c);
              await WalletService.payMerchant(phone: widget.userPhone, merchantId: mrcCtrl.text.trim(), amount: amt);
            },
            child: const Text('دفع فوري'),
          )
        ],
      ),
    );
  }
}