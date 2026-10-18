import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/user_session.dart';
import '../../services/firebase_service.dart';

class CustomerWalletTab extends StatefulWidget {
  const CustomerWalletTab({super.key});

  @override
  State<CustomerWalletTab> createState() => _CustomerWalletTabState();
}

class _CustomerWalletTabState extends State<CustomerWalletTab> {
  // ── Add money dialog ──────────────────────────────────────
  void _showAddMoneyDialog() {
    final ctrl = TextEditingController();

    // Quick-add preset amounts
    const presets = [200, 500, 1000, 2000];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Add Money',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) {
                  return GestureDetector(
                    onTap: () => setDs(() => ctrl.text = p.toString()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.35)),
                      ),
                      child: Text('PKR $p',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Custom amount
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Custom Amount (PKR)',
                  prefixIcon:
                      Icon(Icons.attach_money_rounded, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textHint)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(ctrl.text.trim()) ?? 0;
                if (amount > 0) {
                  UserSession.instance.addMoney(amount);
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  // Persist to Firestore
                  final uid = UserSession.instance.uid;
                  if (uid.isNotEmpty) {
                    await FirebaseService.instance.updateWalletBalance(
                        uid, UserSession.instance.walletBalance);
                    await FirebaseService.instance.addWalletTransaction(
                        uid: uid,
                        title: 'Added via JazzCash',
                        amount: amount,
                        type: 'credit');
                  }
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        'PKR ${amount.toStringAsFixed(0)} added to wallet ✓'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ));
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Withdraw dialog ───────────────────────────────────────
  void _showWithdrawDialog() {
    final ctrl = TextEditingController();
    const presets = [200, 500, 1000];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          backgroundColor: AppTheme.bgCard,
          title: const Text('Withdraw to JazzCash',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) {
                  return GestureDetector(
                    onTap: () => setDs(() => ctrl.text = p.toString()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.35)),
                      ),
                      child: Text('PKR $p',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Amount (PKR)',
                  prefixIcon: Icon(Icons.output_rounded, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textHint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary),
              onPressed: () async {
                final amount = double.tryParse(ctrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final ok = UserSession.instance.withdrawMoney(amount);
                // Persist to Firestore
                if (ok) {
                  final uid = UserSession.instance.uid;
                  if (uid.isNotEmpty) {
                    await FirebaseService.instance.updateWalletBalance(
                        uid, UserSession.instance.walletBalance);
                    await FirebaseService.instance.addWalletTransaction(
                        uid: uid,
                        title: 'Withdrawal to JazzCash',
                        amount: amount,
                        type: 'debit');
                  }
                }
                messenger.showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'PKR ${amount.toStringAsFixed(0)} withdrawn to JazzCash ✓'
                      : 'Insufficient wallet balance'),
                  backgroundColor: ok ? AppTheme.success : AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              },
              child: const Text('Withdraw'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSession.instance,
      builder: (context, _) {
        final session = UserSession.instance;
        final txns = session.walletTransactions;

        // Compute credit/debit totals for the mini-summary
        double totalIn  = 0;
        double totalOut = 0;
        for (final t in txns) {
          final raw = (t['amount'] as String).replaceAll(RegExp(r'[^0-9.]'), '');
          final v   = double.tryParse(raw) ?? 0;
          if (t['type'] == 'credit') { totalIn  += v; }
          else                       { totalOut += v; }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('My Wallet')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Balance card ──────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppGradients.tripleGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text('Available Balance',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text(
                        'PKR ${session.walletBalance.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 16),

                      // In / Out summary row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BalancePill(
                            icon: Icons.arrow_downward_rounded,
                            label: 'Received',
                            value: 'PKR ${totalIn.toStringAsFixed(0)}',
                            color: Colors.greenAccent,
                          ),
                          const SizedBox(width: 16),
                          _BalancePill(
                            icon: Icons.arrow_upward_rounded,
                            label: 'Spent',
                            value: 'PKR ${totalOut.toStringAsFixed(0)}',
                            color: Colors.pinkAccent,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primary,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              onPressed: _showAddMoneyDialog,
                              label: const Text('Add Money',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white, width: 1.5),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.output_rounded),
                              onPressed: _showWithdrawDialog,
                              label: const Text('Withdraw',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.95, 0.95)),

                const SizedBox(height: 32),

                // ── Transaction history ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent Transactions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${txns.length} total',
                          style: const TextStyle(
                              color: AppTheme.textHint, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (txns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded,
                              size: 56,
                              color: AppTheme.textHint.withValues(alpha: 0.25)),
                          const SizedBox(height: 12),
                          const Text('No transactions yet',
                              style: TextStyle(
                                  color: AppTheme.textHint, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Add money to get started',
                              style: TextStyle(
                                  color: AppTheme.textHint, fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: txns.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: Colors.white.withValues(alpha: 0.05)),
                    itemBuilder: (ctx, i) {
                      final txn = txns[i];
                      final isCredit = txn['type'] == 'credit';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isCredit
                                  ? AppTheme.success.withValues(alpha: 0.12)
                                  : AppTheme.error.withValues(alpha: 0.12),
                              child: Icon(
                                isCredit
                                    ? Icons.add_rounded
                                    : Icons.remove_rounded,
                                color: isCredit
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(txn['title'] as String,
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  const SizedBox(height: 3),
                                  Text(txn['date'] as String,
                                      style: const TextStyle(
                                          color: AppTheme.textHint,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(
                              txn['amount'] as String,
                              style: TextStyle(
                                color: isCredit
                                    ? AppTheme.success
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Mini pill widget used inside balance card ─────────────────
class _BalancePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _BalancePill(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(color: color, fontSize: 10)),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
