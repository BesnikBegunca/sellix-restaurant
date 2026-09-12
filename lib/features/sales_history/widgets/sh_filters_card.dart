import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../models/sales_models.dart';
import 'sh_category_chart.dart';
import 'sh_top_products_card.dart';

class SHFiltersCard extends StatelessWidget {
  const SHFiltersCard({
    super.key,
    required this.analytics,
    required this.searchCtrl,
    required this.dateFilter,
    required this.onDateFilterChanged,
    required this.selectedWaiter,
    required this.allWaiters,
    required this.onWaiterChanged,
    required this.selectedTable,
    required this.allTables,
    required this.onTableChanged,
    required this.onClearFilters,
    required this.onSearch,
  });

  final SalesAnalytics? analytics;
  final TextEditingController searchCtrl;
  final SHDateFilter dateFilter;
  final void Function(SHDateFilter) onDateFilterChanged;
  final String? selectedWaiter;
  final List<String> allWaiters;
  final void Function(String?) onWaiterChanged;
  final int? selectedTable;
  final List<int> allTables;
  final void Function(int?) onTableChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onSearch;

  bool get _showClearButton =>
      selectedWaiter != null ||
      selectedTable != null ||
      searchCtrl.text.isNotEmpty ||
      dateFilter != SHDateFilter.allTime;

  Widget _periodTab(SHDateFilter f, String label) {
    final sel = dateFilter == f;
    return GestureDetector(
      onTap: () => onDateFilterChanged(f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? Colors.white : AppColors.darkGreenText,
          ),
        ),
      ),
    );
  }

  Widget _waiterDropdown() {
    return DropdownButtonFormField<String?>(
      value: selectedWaiter,
      decoration: _filterDeco('Të gjithë kamarierët'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Të gjithë kamarierët'),
        ),
        for (final w in allWaiters)
          DropdownMenuItem<String?>(value: w, child: Text(w)),
      ],
      onChanged: (v) => onWaiterChanged(v),
    );
  }

  Widget _tableDropdown() {
    return DropdownButtonFormField<int?>(
      value: selectedTable,
      decoration: _filterDeco('Të gjitha tavolinat'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Të gjitha tavolinat'),
        ),
        for (final t in allTables)
          DropdownMenuItem<int?>(value: t, child: Text('Tavolina $t')),
      ],
      onChanged: (v) => onTableChanged(v),
    );
  }

  static InputDecoration _filterDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppColors.lightGreenText,
        ),
        filled: true,
        fillColor: AppColors.beige,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.lightGreenBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.lightGreenBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreenBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrat & Kërkim',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Kërko porosi, artikuj ose kamarierë...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: AppColors.lightGreenText,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.lightGreenBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.lightGreenBorder,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    hintStyle: TextStyle(
                      color: AppColors.lightGreenText,
                      fontSize: 14,
                    ),
                  ),
                  onChanged: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGreenBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _periodTab(SHDateFilter.today, 'Sot'),
                    _periodTab(SHDateFilter.thisWeek, 'Javë'),
                    _periodTab(SHDateFilter.thisMonth, 'Muaj'),
                    _periodTab(SHDateFilter.allTime, 'Të gjitha'),
                  ],
                ),
              ),
            ],
          ),

          if (a != null &&
              (a.topProducts.isNotEmpty || a.topCategories.isNotEmpty)) ...[
            const SizedBox(height: 20),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (a.topProducts.isNotEmpty)
                    Expanded(
                      child: SHTopProductsCard(products: a.topProducts),
                    ),
                  if (a.topProducts.isNotEmpty && a.topCategories.isNotEmpty)
                    const SizedBox(width: 20),
                  if (a.topCategories.isNotEmpty)
                    Expanded(
                      child: SHCategoryChart(categories: a.topCategories),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(width: 200, child: _waiterDropdown()),
              const SizedBox(width: 12),
              SizedBox(width: 160, child: _tableDropdown()),
              const Spacer(),
              if (_showClearButton)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Pastro filtrat'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mediumGreenText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
