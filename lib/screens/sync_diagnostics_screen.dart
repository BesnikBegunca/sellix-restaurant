import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/activation_service.dart';
import '../services/api_client.dart';
import '../services/background_sync_service.dart';
import '../services/database_service.dart';
import '../services/local_tenant_data_service.dart';
import '../services/runtime_config_service.dart';
import '../services/secure_activation_token_store.dart';
import '../services/support_bundle_service.dart';
import '../services/sync_diagnostics_export_service.dart';
import '../services/sync_status_service.dart';
import '../theme/app_colors.dart';
/// Opens the Sync Diagnostics modal. Call from any [BuildContext].
Future<void> showSyncDiagnosticsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _SyncDiagnosticsDialog(),
  );
}

class _SyncDiagnosticsDialog extends StatefulWidget {
  const _SyncDiagnosticsDialog();

  @override
  State<_SyncDiagnosticsDialog> createState() => _SyncDiagnosticsDialogState();
}

class _SyncDiagnosticsDialogState extends State<_SyncDiagnosticsDialog> {
  final _status = SyncStatusService.instance;
  final _sync = BackgroundSyncService.instance;
  List<Map<String, dynamic>> _failedEvents = [];
  Timer? _backoffTicker;
  bool _retrying = false;
  bool _retryingAllFailed = false;
  String? _retryingEventUuid;
  bool _exporting = false;
  bool _exportingSupportBundle = false;
  bool _clearing = false;
  bool _cleaningUnsupported = false;
  bool _resetting = false;
  bool _tenantDataWarning = false;
  String? _businessName;
  String? _lastBusinessId;
  String? _tenantPolicyLabel;
  String? _tokenStorageLabel;
  bool _accessTokenPresent = false;
  bool _refreshTokenPresent = false;

  @override
  void initState() {
    super.initState();
    _status.addListener(_onStatusChanged);
    _backoffTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_loadFailed());
    unawaited(_loadTenantInfo());
    unawaited(_loadTokenDiagnostics());
  }

  Future<void> _loadTokenDiagnostics() async {
    final store = SecureActivationTokenStore.instance;
    final access = await store.readAccessToken();
    final refresh = await store.readRefreshToken();
    if (!mounted) return;
    setState(() {
      _tokenStorageLabel = store.diagnosticsStorageLabel;
      _accessTokenPresent = access != null && access.isNotEmpty;
      _refreshTokenPresent = refresh != null && refresh.isNotEmpty;
    });
  }

  Future<void> _loadTenantInfo() async {
    final name = await ActivationService.instance.activatedBusinessName();
    final warn =
        await LocalTenantDataService.instance.localDataMayBeFromPreviousTenant();
    final lastId =
        await LocalTenantDataService.instance.lastActivatedBusinessId();
    final policy =
        await LocalTenantDataService.instance.diagnosticsTenantPolicyLabel();
    if (!mounted) return;
    setState(() {
      _businessName = name;
      _tenantDataWarning = warn;
      _lastBusinessId = lastId;
      _tenantPolicyLabel = policy;
    });
  }

  @override
  void dispose() {
    _backoffTicker?.cancel();
    _status.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_loadFailed());
  }

  Future<void> _loadFailed() async {
    final rows = await DatabaseService.instance.getAllFailedOutboxEvents();
    if (mounted) setState(() => _failedEvents = rows);
  }

  Future<void> _retrySyncNow({bool retryFailedFirst = false}) async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      if (retryFailedFirst) {
        await DatabaseService.instance.retryFailedOutboxEvents();
        _sync.resetBackoff();
      }
      await _sync.triggerSyncNow(force: true);
      await _sync.pullSyncNow(force: true);
      await _loadFailed();
      await SyncStatusService.instance.refresh();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _retryAllFailed() async {
    if (_retryingAllFailed || _failedEvents.isEmpty) return;
    setState(() => _retryingAllFailed = true);
    try {
      await DatabaseService.instance.retryFailedOutboxEvents();
      _sync.resetBackoff();
      await _sync.triggerSyncNow(force: true);
      await _sync.pullSyncNow(force: true);
      await _loadFailed();
      await SyncStatusService.instance.refresh();
    } finally {
      if (mounted) setState(() => _retryingAllFailed = false);
    }
  }

  Future<void> _retrySingleFailed(String uuid) async {
    if (_retryingEventUuid != null) return;
    setState(() => _retryingEventUuid = uuid);
    try {
      final ok = await DatabaseService.instance.retryFailedOutboxEvent(uuid);
      if (!ok) return;
      _sync.resetBackoff();
      await _sync.triggerSyncNow(force: true);
      await _loadFailed();
      await SyncStatusService.instance.refresh();
    } finally {
      if (mounted) setState(() => _retryingEventUuid = null);
    }
  }

  Future<void> _exportSupportBundle() async {
    if (_exportingSupportBundle) return;
    setState(() => _exportingSupportBundle = true);
    try {
      final path =
          await SupportBundleService.instance.exportSupportBundleToFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Support bundle u ruajt: $path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eksporti i support bundle dështoi: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingSupportBundle = false);
    }
  }

  Future<void> _exportFailedJson() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final json =
          await SyncDiagnosticsExportService.instance.exportFailedOutboxJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'U kopjua JSON (${_failedEvents.length} ngjarje të dështuara) në clipboard.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _resetLocalActivation() async {
    if (_resetting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rivendos aktivizimin lokal?'),
        content: const Text(
          'Kjo e çaktivizon vetëm këtë instalim lokal. '
          'Të dhënat lokale të shitjeve mbeten të paprekura.\n\n'
          'Për ta bllokuar pajisjen në server, përdorni SuperAdmin '
          '(PATCH /devices/:id/revoke).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulo'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.softRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Rivendos'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _resetting = true);
    try {
      BackgroundSyncService.instance.stop();
      SyncStatusService.instance.stop();
      await ActivationService.instance.resetLocalActivation();
    } finally {
      if (mounted) setState(() => _resetting = false);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _clearErrors() async {
    if (_clearing) return;
    setState(() => _clearing = true);
    try {
      await DatabaseService.instance.clearResolvedSyncErrors();
      await SyncStatusService.instance.refresh();
      await _loadFailed();
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _cleanupUnsupportedOutbox() async {
    if (_cleaningUnsupported) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pastro outbox të pambështetur'),
        content: const Text(
          'Fshin nga outbox vetëm ngjarjet me entityType që pos_api '
          'nuk i proceson (waiters, porosi, kuzhinë, etj.). '
          'Shitjet dhe entitetet e sync-uara nuk preken.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pastro'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cleaningUnsupported = true);
    try {
      final result =
          await DatabaseService.instance.cleanupUnsupportedOutboxEvents();
      await SyncStatusService.instance.refresh();
      await _loadFailed();
      if (!mounted) return;
      final msg = result.totalRemoved == 0
          ? 'Nuk u gjetën rreshta outbox të pambështetur.'
          : 'U fshinë ${result.totalRemoved} rreshta outbox të pambështetur.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _cleaningUnsupported = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSection('API', [
                      _row('Base URL', ApiClient.instance.baseUrl, copyable: true),
                      _row(
                        'Config source',
                        RuntimeConfigService.instance.isUsingFallback
                            ? 'localhost fallback'
                            : 'file / env',
                        valueColor: RuntimeConfigService.instance.isUsingFallback
                            ? AppColors.mutedOrange
                            : AppColors.successGreen,
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Activation', [
                      _row('Status',     _status.isActivated ? 'Active' : 'Inactive',
                          valueColor: _status.isActivated
                              ? AppColors.successGreen
                              : AppColors.softRed),
                      _row(
                        'Token storage',
                        _tokenStorageLabel ??
                            SecureActivationTokenStore.storageLabel,
                      ),
                      _row(
                        'Access token present',
                        _accessTokenPresent ? 'yes' : 'no',
                        valueColor: _accessTokenPresent
                            ? AppColors.successGreen
                            : AppColors.softRed,
                      ),
                      _row(
                        'Refresh token present',
                        _refreshTokenPresent ? 'yes' : 'no',
                        valueColor: _refreshTokenPresent
                            ? AppColors.successGreen
                            : AppColors.softRed,
                      ),
                      _row('Business', _businessName ?? '—'),
                      _row('Business ID', _status.businessId ?? '—'),
                      _row('Branch ID',   _status.branchId   ?? '—'),
                      _row('Device ID',   _status.deviceId   ?? '—'),
                      _row('Last local business ID', _lastBusinessId ?? '—'),
                      _row('Tenant policy', _tenantPolicyLabel ?? '—',
                          valueColor: _tenantDataWarning
                              ? AppColors.mutedOrange
                              : null),
                    ]),
                    if (_tenantDataWarning) ...[
                      const SizedBox(height: 12),
                      _buildTenantWarningBanner(),
                    ],
                    const SizedBox(height: 16),
                    _buildSection('Connectivity', [
                      _row('Network', _status.isOnline ? 'Online' : 'Offline',
                          valueColor: _status.isOnline
                              ? AppColors.successGreen
                              : AppColors.softRed),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Outbox', [
                      _row('Pending events', '${_status.pendingOutboxCount}',
                          valueColor: _status.hasPending
                              ? AppColors.mutedOrange
                              : null),
                      _row('Failed events', '${_status.failedOutboxCount}',
                          valueColor: _status.hasFailed
                              ? AppColors.softRed
                              : null),
                      _row('Backoff failures', '${_sync.backoffFailureCount}'),
                      _row(
                        'Next auto retry',
                        _formatBackoffWait(),
                        valueColor: _sync.backoffIsReady
                            ? AppColors.successGreen
                            : AppColors.mutedOrange,
                      ),
                      if (_sync.backoffExhausted)
                        _row(
                          'Backoff',
                          'Max retries — përdorni Retry manual',
                          valueColor: AppColors.softRed,
                        ),
                      _row('Session conflict skips',
                          '${_status.sessionConflictSkips}'),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Timestamps', [
                      _row('Last push',    _timeAgo(_status.lastPushAt)),
                      _row('Last pull',    _timeAgo(_status.lastPullAt)),
                      _row('Last success', _timeAgo(_status.lastSuccessAt)),
                      _row('Pull cursor',  _formatCursor(_status.pullCursor),
                          copyable: true),
                    ]),
                    if (_status.lastSyncError != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(_status.lastSyncError!),
                    ],
                    if (_failedEvents.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildFailedEventsSection(),
                    ],
                    const SizedBox(height: 24),
                    _buildActions(),
                    const SizedBox(height: 12),
                    _buildUnsupportedOutboxCleanup(),
                    const SizedBox(height: 12),
                    _buildSupportBundleExport(),
                    const SizedBox(height: 12),
                    _buildResetSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.lightGreenBorder),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_outlined,
              size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sync Diagnostics',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGreenText,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.lightGreenText,
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.lightGreenText,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.beige,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.lightGreenBorder),
          ),
          child: Column(
            children: rows
                .asMap()
                .entries
                .map((e) => Column(
                      children: [
                        e.value,
                        if (e.key < rows.length - 1)
                          Divider(
                              height: 1, color: AppColors.lightGreenBorder),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    Color? valueColor,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.mediumGreenText,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.darkGreenText,
                      fontFamily: copyable ? 'monospace' : null,
                    ),
                  ),
                ),
                if (copyable && value != '—') ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: value)),
                    child: Icon(Icons.copy_outlined,
                        size: 13, color: AppColors.lightGreenText),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedEventsSection() {
    final busy = _retryingAllFailed || _exporting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'FAILED OUTBOX EVENTS (${_failedEvents.length})'.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightGreenText,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : _retryAllFailed,
                icon: _retryingAllFailed
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(
                  _retryingAllFailed ? 'Duke riprovuar…' : 'Riprovo të gjitha',
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _exportFailedJson,
              icon: _exporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 16),
              label: const Text('Eksporto JSON'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: BoxDecoration(
            color: AppColors.beige,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.lightGreenBorder),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _failedEvents.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: AppColors.lightGreenBorder,
            ),
            itemBuilder: (context, index) =>
                _buildFailedRow(_failedEvents[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildFailedRow(Map<String, dynamic> row) {
    final uuid = row['uuid'] as String? ?? '';
    final entityType = row['entityType'] as String? ?? '?';
    final operation = row['operation'] as String? ?? '?';
    final err = row['lastError'] as String? ?? 'Unknown error';
    final updatedAt = row['updatedAt'] as String?;
    final retryCount = row['retryCount'];
    final isRetrying = _retryingEventUuid == uuid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.softRed),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$entityType · $operation',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreenText,
                  ),
                ),
                if (uuid.isNotEmpty)
                  Text(
                    uuid,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppColors.lightGreenText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  err,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.softRed,
                  ),
                ),
                Text(
                  '${_timeAgo(updatedAt)} · retries: $retryCount',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.lightGreenText,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: isRetrying ? null : () => _retrySingleFailed(uuid),
            child: isRetrying
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Riprovo'),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mutedOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.mutedOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 16, color: AppColors.mutedOrange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Të dhënat operative lokale mund të jenë nga një biznes tjetër. '
              'Historiku audit (audit_logs) ruhet gjithmonë. '
              'Në versionin e publikuar, aktivizimi i një biznesi të ri kërkon '
              'pastrim lokal të detyrueshëm para vazhdimit.',
              style: TextStyle(fontSize: 12, color: AppColors.darkGreenText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.softRed.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 16, color: AppColors.softRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.softRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final syncing = _status.isSyncing || _retrying;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: syncing ? null : () => _retrySyncNow(),
            icon: syncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync, size: 16),
            label: Text(syncing ? 'Syncing…' : 'Retry Sync Now'),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _clearing ? null : _clearErrors,
          icon: _clearing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cleaning_services_outlined, size: 16),
          label: const Text('Clear Resolved'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mediumGreenText,
            side: BorderSide(color: AppColors.lightGreenBorder),
          ),
        ),
      ],
    );
  }

  Widget _buildUnsupportedOutboxCleanup() {
    final busy = _cleaningUnsupported || _clearing || _retrying;
    return OutlinedButton.icon(
      onPressed: busy ? null : _cleanupUnsupportedOutbox,
      icon: _cleaningUnsupported
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_sweep_outlined, size: 16),
      label: Text(
        _cleaningUnsupported
            ? 'Duke pastruar…'
            : 'Pastro outbox të pambështetur',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.mediumGreenText,
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: AppColors.lightGreenBorder),
      ),
    );
  }

  Widget _buildSupportBundleExport() {
    return OutlinedButton.icon(
      onPressed: (_exportingSupportBundle || _exporting)
          ? null
          : _exportSupportBundle,
      icon: _exportingSupportBundle
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.archive_outlined, size: 16),
      label: Text(
        _exportingSupportBundle
            ? 'Duke eksportuar…'
            : 'Eksporto support bundle',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        minimumSize: const Size(double.infinity, 44),
        side: BorderSide(color: AppColors.lightGreenBorder),
      ),
    );
  }

  Widget _buildResetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: AppColors.lightGreenBorder, height: 1),
        const SizedBox(height: 12),
        Text(
          'Rivendos vetëm aktivizimin lokal. Për çaktivizim server-side, '
          'përdorni SuperAdmin.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.lightGreenText,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: (_resetting || !_status.isActivated)
              ? null
              : _resetLocalActivation,
          icon: _resetting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.restart_alt_outlined, size: 16),
          label: Text(
            _resetting ? 'Duke rivendosur…' : 'Rivendos aktivizimin lokal',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.mediumGreenText,
            side: BorderSide(color: AppColors.lightGreenBorder),
          ),
        ),
      ],
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return 'Never';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5)  return 'Just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _formatCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return '—';
    // Trim to just the datetime portion for readability.
    return cursor.length > 19 ? cursor.substring(0, 19) : cursor;
  }

  String _formatBackoffWait() {
    if (_sync.backoffIsReady) return 'Ready now';
    final rem = _sync.retryBackoffRemaining;
    if (rem == null) return '—';
    if (rem <= Duration.zero) return 'Ready now';
    if (rem.inMinutes >= 1) {
      return '${rem.inMinutes}m ${rem.inSeconds % 60}s';
    }
    return '${rem.inSeconds}s';
  }
}
