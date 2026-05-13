import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../manager/manager_data.dart';
import '../services/audit_log_pdf.dart';
import '../services/audit_log_service.dart';
import '../theme/app_colors.dart';

// ── date filter enum ──────────────────────────────────────────────────────────

enum _DateFilter { today, thisWeek, thisMonth, allTime, custom }

// ── colour per action type ────────────────────────────────────────────────────

Color _actionColor(String action) {
  switch (action) {
    // green — positive / creation / login
    case AuditAction.saleCreated:
    case AuditAction.shiftOpened:
    case AuditAction.managerLogin:
    case AuditAction.waiterLogin:
    case AuditAction.backupExported:
    case AuditAction.waiterAdded:
    case AuditAction.productCreated:
    case AuditAction.categoryCreated:
    case AuditAction.expenseAdded:
    case AuditAction.cashDrawerOpened:
    case AuditAction.receiptReprinted:
      return AppColors.successGreen;
    // red — destructive / security failure
    case AuditAction.refundCreated:
    case AuditAction.voidCreated:
    case AuditAction.productDeleted:
    case AuditAction.categoryDeleted:
    case AuditAction.expenseDeleted:
    case AuditAction.waiterRemoved:
    case AuditAction.failedPin:
    case AuditAction.unauthorizedAction:
    case AuditAction.failedRestore:
      return AppColors.negativeText;
    // orange — significant operational
    case AuditAction.discountApplied:
    case AuditAction.manualDiscount:
    case AuditAction.priceOverride:
    case AuditAction.shiftClosed:
    case AuditAction.shiftReopened:
    case AuditAction.backupRestored:
    case AuditAction.restoreUndone:
    case AuditAction.paymentMethodOverride:
    case AuditAction.itemRemoved:
      return AppColors.accentOrange;
    // blue — informational / movement
    case AuditAction.splitPayment:
    case AuditAction.tableTransfer:
    case AuditAction.tableMerge:
    case AuditAction.tableSplit:
    case AuditAction.orderReopened:
      return AppColors.accentBlue;
    default:
      return AppColors.mediumGreenText;
  }
}

// ── icon per action type ──────────────────────────────────────────────────────

IconData _actionIcon(String action) {
  switch (action) {
    case AuditAction.saleCreated:         return Icons.receipt_outlined;
    case AuditAction.refundCreated:       return Icons.undo_outlined;
    case AuditAction.voidCreated:         return Icons.cancel_outlined;
    case AuditAction.discountApplied:     return Icons.local_offer_outlined;
    case AuditAction.manualDiscount:      return Icons.discount_outlined;
    case AuditAction.priceOverride:       return Icons.edit_note_outlined;
    case AuditAction.splitPayment:        return Icons.call_split_outlined;
    case AuditAction.paymentMethodOverride: return Icons.swap_horiz_outlined;
    case AuditAction.receiptReprinted:    return Icons.print_outlined;
    case AuditAction.shiftOpened:         return Icons.play_circle_outline;
    case AuditAction.shiftClosed:         return Icons.stop_circle_outlined;
    case AuditAction.shiftReopened:       return Icons.replay_outlined;
    case AuditAction.tableOpened:         return Icons.table_restaurant_outlined;
    case AuditAction.tableCleared:        return Icons.table_bar_outlined;
    case AuditAction.tableTransfer:       return Icons.move_down_outlined;
    case AuditAction.tableMerge:          return Icons.merge_outlined;
    case AuditAction.tableSplit:          return Icons.call_split;
    case AuditAction.orderReopened:       return Icons.lock_open_outlined;
    case AuditAction.itemRemoved:         return Icons.remove_circle_outline;
    case AuditAction.cashDrawerOpened:    return Icons.point_of_sale_outlined;
    case AuditAction.productCreated:      return Icons.add_circle_outline;
    case AuditAction.productEdited:       return Icons.edit_outlined;
    case AuditAction.productDeleted:      return Icons.delete_outline;
    case AuditAction.categoryCreated:     return Icons.create_new_folder_outlined;
    case AuditAction.categoryDeleted:     return Icons.folder_delete_outlined;
    case AuditAction.expenseAdded:        return Icons.attach_money;
    case AuditAction.expenseDeleted:      return Icons.money_off_outlined;
    case AuditAction.managerLogin:        return Icons.admin_panel_settings_outlined;
    case AuditAction.waiterLogin:         return Icons.badge_outlined;
    case AuditAction.failedPin:           return Icons.lock_outlined;
    case AuditAction.unauthorizedAction:  return Icons.gpp_bad_outlined;
    case AuditAction.backupExported:      return Icons.upload_outlined;
    case AuditAction.backupRestored:      return Icons.download_outlined;
    case AuditAction.restoreUndone:       return Icons.history_outlined;
    case AuditAction.failedRestore:       return Icons.error_outline;
    case AuditAction.printerChanged:      return Icons.print_outlined;
    case AuditAction.settingChanged:
    case AuditAction.companyNameChanged:  return Icons.settings_outlined;
    case AuditAction.waiterAdded:         return Icons.person_add_outlined;
    case AuditAction.waiterRemoved:       return Icons.person_remove_outlined;
    case AuditAction.salaryChanged:       return Icons.payments_outlined;
    default:                              return Icons.info_outline;
  }
}

// ── ordered list of all action types for the filter dropdown ─────────────────

const _kAllActionTypes = [
  AuditAction.saleCreated,
  AuditAction.refundCreated,
  AuditAction.voidCreated,
  AuditAction.discountApplied,
  AuditAction.manualDiscount,
  AuditAction.priceOverride,
  AuditAction.splitPayment,
  AuditAction.paymentMethodOverride,
  AuditAction.receiptReprinted,
  AuditAction.shiftOpened,
  AuditAction.shiftClosed,
  AuditAction.shiftReopened,
  AuditAction.tableOpened,
  AuditAction.tableCleared,
  AuditAction.tableTransfer,
  AuditAction.tableMerge,
  AuditAction.tableSplit,
  AuditAction.orderReopened,
  AuditAction.itemRemoved,
  AuditAction.cashDrawerOpened,
  AuditAction.productCreated,
  AuditAction.productEdited,
  AuditAction.productDeleted,
  AuditAction.categoryCreated,
  AuditAction.categoryDeleted,
  AuditAction.expenseAdded,
  AuditAction.expenseDeleted,
  AuditAction.managerLogin,
  AuditAction.waiterLogin,
  AuditAction.failedPin,
  AuditAction.unauthorizedAction,
  AuditAction.backupExported,
  AuditAction.backupRestored,
  AuditAction.restoreUndone,
  AuditAction.failedRestore,
  AuditAction.printerChanged,
  AuditAction.settingChanged,
  AuditAction.companyNameChanged,
  AuditAction.waiterAdded,
  AuditAction.waiterRemoved,
  AuditAction.salaryChanged,
];

// ── panel widget ──────────────────────────────────────────────────────────────

class AuditLogPanel extends StatefulWidget {
  const AuditLogPanel({super.key});

  @override
  State<AuditLogPanel> createState() => _AuditLogPanelState();
}

class _AuditLogPanelState extends State<AuditLogPanel> {
  // ── filters ────────────────────────────────────────────────────────────────
  _DateFilter _dateFilter = _DateFilter.today;
  DateTimeRange? _customRange;
  String? _selectedActor;
  String? _selectedActionType;
  final _searchCtrl = TextEditingController();

  // ── data ───────────────────────────────────────────────────────────────────
  List<AuditLogRow> _logs = [];
  bool _loading = true;
  String? _error;
  bool _hasMore = false;
  int _offset = 0;
  static const int _pageSize = 200;

  // ── UI ─────────────────────────────────────────────────────────────────────
  final Set<int> _expandedIds = {};
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadData(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── date helpers ───────────────────────────────────────────────────────────

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTimeRange? get _effectiveRange {
    final now = DateTime.now();
    return switch (_dateFilter) {
      _DateFilter.today => DateTimeRange(
          start: _startOfDay(now),
          end: _endOfDay(now),
        ),
      _DateFilter.thisWeek => DateTimeRange(
          start: _startOfDay(now.subtract(Duration(days: now.weekday - 1))),
          end: _endOfDay(now),
        ),
      _DateFilter.thisMonth => DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _endOfDay(now),
        ),
      _DateFilter.allTime => null,
      _DateFilter.custom  => _customRange,
    };
  }

  String get _dateRangeLabel => switch (_dateFilter) {
    _DateFilter.today     => 'Sot',
    _DateFilter.thisWeek  => 'Kjo javë',
    _DateFilter.thisMonth => 'Ky muaj',
    _DateFilter.allTime   => 'Të gjitha',
    _DateFilter.custom    => _customRange == null
        ? 'Personalizuar'
        : '${_customRange!.start.day}/${_customRange!.start.month}/${_customRange!.start.year}'
          ' – '
          '${_customRange!.end.day}/${_customRange!.end.month}/${_customRange!.end.year}',
  };

  // ── data loading ───────────────────────────────────────────────────────────

  Future<void> _loadData({bool reset = false}) async {
    if (!mounted) return;
    if (reset) _offset = 0;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final range = _effectiveRange;
      final searchText = _searchCtrl.text.trim();
      final saleId = searchText.isNotEmpty ? int.tryParse(searchText) : null;

      final rows = await AuditLogService.instance.fetchFiltered(
        from:        range?.start,
        to:          range?.end,
        actionType:  _selectedActionType,
        performedBy: _selectedActor,
        saleId:      saleId,
        limit:       _pageSize + 1,
        offset:      _offset,
      );

      final hasMore = rows.length > _pageSize;
      final page    = hasMore ? rows.sublist(0, _pageSize) : rows;

      if (mounted) {
        setState(() {
          _logs    = reset ? page : [..._logs, ...page];
          _hasMore = hasMore;
          _offset  = _logs.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _dateFilter       = _DateFilter.today;
      _customRange      = null;
      _selectedActor    = null;
      _selectedActionType = null;
      _searchCtrl.clear();
    });
    _loadData(reset: true);
  }

  List<String> get _actors {
    final names = _logs
        .map((l) => l.performedBy)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  // ── PDF export ─────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    if (_exportingPdf || _logs.isEmpty) return;
    setState(() => _exportingPdf = true);
    try {
      final exportId = 'AX-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
      final bytes = await buildAuditLogPdfBytes(
        logs:          _logs,
        dateRangeLabel: _dateRangeLabel,
        companyName:   ManagerData.instance.companyName ?? 'POS System',
        generatedBy:   'manager',
        exportId:      exportId,
      );
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export dështoi: $e'),
            backgroundColor: AppColors.negativeText,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildFiltersCard(),
        const SizedBox(height: 20),
        if (_loading && _logs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (_error != null)
          _buildError()
        else
          _buildLogList(),
      ],
    );
  }

  // ── header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Audit Logs',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _loading
                    ? 'Duke ngarkuar…'
                    : '${_logs.length} veprime · $_dateRangeLabel',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.lightGreenText,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: (_exportingPdf || _logs.isEmpty) ? null : _exportPdf,
          icon: _exportingPdf
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('Eksporto PDF'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ── filters card ───────────────────────────────────────────────────────────

  Widget _buildFiltersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [for (final f in _DateFilter.values) _dateChip(f)],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(width: 200, child: _actorDropdown()),
              SizedBox(width: 220, child: _actionTypeDropdown()),
              SizedBox(width: 180, child: _searchField()),
              OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Pastro filtrat'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mediumGreenText,
                  side: BorderSide(color: AppColors.borderVisible(0.2)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateChip(_DateFilter f) {
    final labels = {
      _DateFilter.today:     'Sot',
      _DateFilter.thisWeek:  'Kjo javë',
      _DateFilter.thisMonth: 'Ky muaj',
      _DateFilter.allTime:   'Të gjitha',
      _DateFilter.custom:    'Personalizuar',
    };
    final sel = _dateFilter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () async {
          if (f == _DateFilter.custom) {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: _customRange,
              builder: (ctx, child) => Theme(
                data: ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primaryGreen,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked == null) return;
            setState(() {
              _dateFilter  = _DateFilter.custom;
              _customRange = picked;
            });
          } else {
            setState(() => _dateFilter = f);
          }
          _loadData(reset: true);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryGreen : AppColors.beige,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel
                  ? AppColors.primaryGreen
                  : AppColors.borderVisible(0.15),
            ),
          ),
          child: Text(
            labels[f] ?? '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? Colors.white : AppColors.mediumGreenText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actorDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedActor,
      decoration: _filterDeco('Të gjithë aktorët'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Të gjithë aktorët'),
        ),
        for (final a in _actors)
          DropdownMenuItem<String?>(value: a, child: Text(a)),
      ],
      onChanged: (v) {
        setState(() => _selectedActor = v);
        _loadData(reset: true);
      },
    );
  }

  Widget _actionTypeDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedActionType,
      decoration: _filterDeco('Të gjitha veprimet'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Të gjitha veprimet'),
        ),
        for (final a in _kAllActionTypes)
          DropdownMenuItem<String?>(
            value: a,
            child: Text(AuditAction.label(a)),
          ),
      ],
      onChanged: (v) {
        setState(() => _selectedActionType = v);
        _loadData(reset: true);
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchCtrl,
      decoration: _filterDeco('Kërko me ID shitjeje'),
      keyboardType: TextInputType.number,
      onChanged: (_) => _loadData(reset: true),
    );
  }

  InputDecoration _filterDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.lightGreenText,
        ),
        filled: true,
        fillColor: AppColors.beige,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderVisible(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderVisible(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  // ── log list ───────────────────────────────────────────────────────────────

  Widget _buildLogList() {
    if (_logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 48,
              color: AppColors.lightGreenText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nuk ka veprime për filtrat e zgjedhur',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ndrysho filtrat ose kryej veprime të reja.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.lightGreenText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_logs.length} veprime',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGreenText,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_expandedIds.length == _logs.length) {
                      _expandedIds.clear();
                    } else {
                      _expandedIds.addAll(_logs.map((l) => l.id));
                    }
                  });
                },
                icon: Icon(
                  _expandedIds.length == _logs.length
                      ? Icons.unfold_less
                      : Icons.unfold_more,
                  size: 16,
                ),
                label: Text(
                  _expandedIds.length == _logs.length
                      ? 'Mbyll të gjitha'
                      : 'Hap të gjitha',
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        for (final log in _logs)
          _AuditLogCard(
            log:      log,
            expanded: _expandedIds.contains(log.id),
            onToggle: () => setState(() {
              if (_expandedIds.contains(log.id)) {
                _expandedIds.remove(log.id);
              } else {
                _expandedIds.add(log.id);
              }
            }),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    )
                  : OutlinedButton.icon(
                      onPressed: () => _loadData(reset: false),
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: const Text('Ngarko më shumë'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side:
                            const BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.negativeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.negativeText.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.negativeText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Gabim gjatë ngarkimit: $_error',
              style: const TextStyle(color: AppColors.negativeText),
            ),
          ),
          TextButton(
            onPressed: () => _loadData(reset: true),
            child: const Text('Riprovo'),
          ),
        ],
      ),
    );
  }
}

// ── log card ──────────────────────────────────────────────────────────────────

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({
    required this.log,
    required this.expanded,
    required this.onToggle,
  });

  final AuditLogRow log;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(log.actionType);
    final ts    = log.createdAt;
    final dateStr =
        '${ts.day.toString().padLeft(2, '0')}.${ts.month.toString().padLeft(2, '0')}.${ts.year}';
    final timeStr =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expanded
              ? color.withValues(alpha: 0.3)
              : AppColors.borderSubtle(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── summary row ─────────────────────────────────────────────────
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(expanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              child: Row(
                children: [
                  // action icon badge
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _actionIcon(log.actionType),
                      size: 17,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // action label + actor
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuditAction.label(log.actionType),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (log.performedBy != null)
                          Text(
                            '${log.performedBy}'
                            '${log.performedRole != null ? ' · ${log.performedRole}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.lightGreenText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // entity badge
                  if (log.entityType != null)
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.beige,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${log.entityType}'
                        '${log.entityId != null ? ' #${log.entityId}' : ''}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                    ),
                  // date + time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mediumGreenText,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.lightGreenText,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.mediumGreenText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── expanded detail ──────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildDetail(color),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(Color color) {
    final details = log.details;
    final entries = details?.entries.toList() ?? [];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle(0.1))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── context chips ──────────────────────────────────────────────
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (log.shiftId  != null) _chip('Shift',   '#${log.shiftId}'),
              if (log.saleId   != null) _chip('Sale',    '#${log.saleId}'),
              if (log.tableId  != null) _chip('Table',   '${log.tableId}'),
              _chip('Log ID', '#${log.id}'),
            ],
          ),

          // ── device forensics ───────────────────────────────────────────
          if (log.deviceId != null || log.terminalName != null || log.platform != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Terminal',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (log.terminalName != null)
                  _chip('Host', log.terminalName!),
                if (log.platform != null)
                  _chip('Platform', log.platform!),
                if (log.appVersion != null)
                  _chip('App', log.appVersion!),
                if (log.deviceId != null)
                  _chip('Device', '…${log.deviceId!.substring(log.deviceId!.length > 8 ? log.deviceId!.length - 8 : 0)}'),
                if (log.rowHash != null)
                  _chip('Hash', log.rowHash!.substring(0, 8)),
              ],
            ),
          ],

          // ── action details ─────────────────────────────────────────────
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Detajet',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGreenText,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              e.key,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mediumGreenText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _fmtValue(e.value),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.darkGreenText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // raw JSON fallback for logs with malformed details
          if (log.detailsJson != null && entries.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.detailsJson!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.lightGreenText,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.lightGreenText,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.mediumGreenText,
          ),
        ),
      ],
    );
  }

  String _fmtValue(dynamic v) {
    if (v is Map || v is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(v);
      } catch (_) {
        return v.toString();
      }
    }
    if (v is double) return v.toStringAsFixed(2);
    return v.toString();
  }
}
