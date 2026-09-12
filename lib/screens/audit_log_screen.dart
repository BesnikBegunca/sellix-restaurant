import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../features/audit_log/widgets/audit_category_tabs.dart';
import '../features/audit_log/widgets/audit_empty_state.dart';
import '../features/audit_log/widgets/audit_error_card.dart';
import '../features/audit_log/widgets/audit_kpi_card.dart';
import '../features/audit_log/widgets/audit_kpi_row.dart';
import '../features/audit_log/widgets/audit_log_card.dart';
import '../manager/manager_data.dart';
import '../services/audit_log_pdf.dart';
import '../services/audit_log_service.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

// ── date filter enum ──────────────────────────────────────────────────────────

enum _DateFilter { today, thisWeek, thisMonth, allTime, custom }

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
  AuditCategoryFilter _categoryFilter = AuditCategoryFilter.all;
  final _searchCtrl = TextEditingController();

  List<AuditLogRow> get _filteredLogs {
    if (_categoryFilter == AuditCategoryFilter.all) return _logs;
    return _logs
        .where((l) => auditActionCategory(l.actionType) == _categoryFilter)
        .toList();
  }

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
    _DateFilter.thisWeek  => tr.kjoJave,
    _DateFilter.thisMonth => 'Ky muaj',
    _DateFilter.allTime   => tr.gjitha,
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
        companyName:   ManagerData.instance.companyName ?? tr.posSystem,
        generatedBy:   'manager',
        exportId:      exportId,
      );
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf.pdfExportFailed(e)),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        AuditKpiRow(logs: _logs),
        const SizedBox(height: 20),
        if (_loading && _logs.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (_error != null)
          AuditErrorCard(error: _error, onRetry: () => _loadData(reset: true))
        else
          _buildMainCard(),
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
              Text(
                'Regjistri i Auditit',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkGreenText,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                tr.gjurmoGjithaAktivitetetSistemit,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.lightGreenText,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: (_exportingPdf || _logs.isEmpty) ? null : _exportPdf,
          icon: _exportingPdf
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                )
              : const Icon(Icons.download_outlined, size: 16),
          label: const Text('Eksporto PDF'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.darkGreenText,
            side: BorderSide(color: AppColors.lightGreenBorder),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── main card (filter + log list) ──────────────────────────────────────────

  Widget _buildMainCard() {
    final filtered = _filteredLogs;
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
            tr.filtroSipasKategorise,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGreenText,
            ),
          ),
          const SizedBox(height: 16),
          AuditCategoryTabs(
            selected: _categoryFilter,
            onChanged: (f) => setState(() => _categoryFilter = f),
          ),
          const SizedBox(height: 16),
          _buildSecondaryFilters(),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            AuditEmptyState()
          else ...[
            for (final log in filtered)
              AuditLogCard(
                log: log,
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
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: _loading
                      ? CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _loadData(reset: false),
                          icon: const Icon(Icons.expand_more, size: 18),
                          label: Text(tr.ngarkoShume),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                            side: BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecondaryFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 160,
          child: _buildDatePeriodDropdown(),
        ),
        SizedBox(width: 180, child: _actorDropdown()),
        SizedBox(width: 210, child: _actionTypeDropdown()),
        SizedBox(width: 160, child: _searchField()),
        TextButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.clear, size: 14),
          label: const Text('Pastro filtrat'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.mediumGreenText,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePeriodDropdown() {
    final labels = {
      _DateFilter.today:     'Sot',
      _DateFilter.thisWeek:  tr.kjoJave,
      _DateFilter.thisMonth: 'Ky muaj',
      _DateFilter.allTime:   tr.gjitha,
      _DateFilter.custom:    'Personalizuar',
    };
    return DropdownButtonFormField<_DateFilter>(
      value: _dateFilter,
      decoration: _filterDeco('Periudha'),
      isExpanded: true,
      items: _DateFilter.values
          .map(
            (f) => DropdownMenuItem(
              value: f,
              child: Text(labels[f] ?? ''),
            ),
          )
          .toList(),
      onChanged: (v) async {
        if (v == null) return;
        if (v == _DateFilter.custom) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            initialDateRange: _customRange,
            builder: (ctx, child) => Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppColors.primaryGreen,
                ),
              ),
              child: child!,
            ),
          );
          if (picked == null) return;
          setState(() {
            _dateFilter = _DateFilter.custom;
            _customRange = picked;
          });
        } else {
          setState(() => _dateFilter = v);
        }
        _loadData(reset: true);
      },
    );
  }

  Widget _actorDropdown() {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedActor,
      decoration: _filterDeco(tr.gjitheAktoret),
      isExpanded: true,
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(tr.gjitheAktoret),
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
      decoration: _filterDeco(tr.gjithaVeprimet),
      isExpanded: true,
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(tr.gjithaVeprimet),
        ),
        for (final a in kAllAuditActionTypes)
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
      decoration: _filterDeco(tr.kerkoIdShitjeje),
      keyboardType: TextInputType.number,
      onChanged: (_) => _loadData(reset: true),
    );
  }

  InputDecoration _filterDeco(String hint) => InputDecoration(
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

}

