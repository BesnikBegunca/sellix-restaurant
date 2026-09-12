import 'package:flutter/material.dart';

import '../../../../manager/manager_data.dart';
import '../../../../theme/app_colors.dart';

class ExpensesDataTable extends StatelessWidget {
  const ExpensesDataTable({
    required this.rows,
    required this.fmtDate,
    required this.onDelete,
  });

  final List<ExpenseRow> rows;
  final String Function(DateTime) fmtDate;
  final void Function(ExpenseRow) onDelete;

  Color _categoryColor(String type) {
    switch (type) {
      case 'Rrogë':
        return const Color(0xFF2E7D32);
      case 'Bonus':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.lightGreenText,
      letterSpacing: 0.6,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(color: AppColors.lightGreenBg),
            child: Row(
              children: [
                SizedBox(width: 130, child: Text('DATA', style: headerStyle)),
                SizedBox(
                  width: 130,
                  child: Text('KATEGORIA', style: headerStyle),
                ),
                Expanded(child: Text('PËRSHKRIMI', style: headerStyle)),
                SizedBox(
                  width: 140,
                  child: Text('MËNYRA E PAGESËS', style: headerStyle),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    'SHUMA',
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
                SizedBox(width: 52),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: AppColors.lightGreenBorder,
            ),
            itemBuilder: (context, i) {
              final e = rows[i];
              final catColor = _categoryColor(e.type);
              return Material(
                color: AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          fmtDate(e.date),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: catColor.withValues(alpha: 0.30),
                              ),
                            ),
                            child: Text(
                              e.type,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: catColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            e.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.darkGreenText,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Text(
                          '—',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mediumGreenText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${e.amount.toStringAsFixed(2)}€',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.negativeText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: IconButton(
                          tooltip: 'Fshi rreshtin',
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.negativeText.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          onPressed: () => onDelete(e),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
