import 'package:flutter/material.dart';

import '../models/sales_models.dart';
import '../../../manager/manager_data.dart';
import '../../../theme/app_colors.dart';
import '../../../l10n/tr.dart';

Future<void> showSHRefundDialog(
  BuildContext context,
  SaleWithLines swl, {
  required VoidCallback onSuccess,
}) async {
  final formKey = GlobalKey<FormState>();
  String adjustmentType = 'refund';
  final amountCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDlg) => AlertDialog(
        title: const Text('Regjistro rimbursim / anulim'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shitja #${swl.sale.dbId}  ·  Totali: ${swl.sale.total.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mediumGreenText,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'refund', label: Text('Rimbursim')),
                    ButtonSegment(value: 'void', label: Text('Anulim')),
                    ButtonSegment(value: 'discount', label: Text('Zbritje')),
                  ],
                  selected: {adjustmentType},
                  onSelectionChanged: (s) =>
                      setDlg(() => adjustmentType = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: tr.shuma,
                    border: OutlineInputBorder(),
                    suffixText: '€',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return tr.shumaDuhetJete0;
                    if (n > swl.sale.total) return 'Kalon totalin e shitjes';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: InputDecoration(
                    labelText: tr.arsyejaOpsionale,
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr.anulo),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negativeText,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Konfirmo'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final amount = double.parse(amountCtrl.text);
  final reason =
      reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim();

  try {
    await ManagerData.instance.recordAdjustment(
      saleId: swl.sale.dbId!,
      adjustmentType: adjustmentType,
      amount: amount,
      reason: reason,
    );
    onSuccess();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rimbursimi dështoi: $e'),
          backgroundColor: AppColors.negativeText,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
