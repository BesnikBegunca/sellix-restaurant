import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/activation_service.dart';
import '../services/background_sync_service.dart';
import '../services/database_service.dart';
import '../services/sync_status_service.dart';
import '../theme/app_colors.dart';
import 'activation_screen.dart';

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
  List<Map<String, dynamic>> _recentFailed = [];
  bool _retrying = false;
  bool _clearing = false;
  bool _deactivating = false;

  @override
  void initState() {
    super.initState();
    _status.addListener(_onStatusChanged);
    unawaited(_loadFailed());
  }

  @override
  void dispose() {
    _status.removeListener(_onStatusChanged);
    super.dispose();
  }

  void _onStatusChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_loadFailed());
  }

  Future<void> _loadFailed() async {
    final rows =
        await DatabaseService.instance.getRecentFailedOutboxEvents(limit: 5);
    if (mounted) setState(() => _recentFailed = rows);
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await DatabaseService.instance.retryFailedOutboxEvents();
      await BackgroundSyncService.instance.triggerSyncNow();
      unawaited(BackgroundSyncService.instance.pullSyncNow());
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _deactivate() async {
    if (_deactivating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çaktivizo këtë pajisje?'),
        content: const Text(
          'Sinkronizimi me cloud do të ndalet. '
          'Të dhënat lokale të shitjeve dhe produkteve mbeten të paprekura. '
          'Do të keni nevojë të aktivizoni sërish pajisjen për të rifilluar sinkronizimin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Anulo'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.softRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Çaktivizo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deactivating = true);
    try {
      BackgroundSyncService.instance.stop();
      SyncStatusService.instance.stop();
      await ActivationService.instance.revokeActivation();
    } finally {
      if (mounted) setState(() => _deactivating = false);
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const ActivationScreen()),
      (_) => false,
    );
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 580,
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
                    _buildSection('Activation', [
                      _row('Status',     _status.isActivated ? 'Active' : 'Inactive',
                          valueColor: _status.isActivated
                              ? AppColors.successGreen
                              : AppColors.softRed),
                      _row('Business ID', _status.businessId ?? '—'),
                      _row('Branch ID',   _status.branchId   ?? '—'),
                      _row('Device ID',   _status.deviceId   ?? '—'),
                    ]),
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
                    if (_recentFailed.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSection('Recent Failed Events', [
                        ..._recentFailed.map(_buildFailedRow),
                      ]),
                    ],
                    const SizedBox(height: 24),
                    _buildActions(),
                    const SizedBox(height: 12),
                    _buildDeactivateSection(),
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
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.lightGreenBorder),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_outlined,
              size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          const Expanded(
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
          style: const TextStyle(
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
                          const Divider(
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
              style: const TextStyle(
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
                    child: const Icon(Icons.copy_outlined,
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

  Widget _buildFailedRow(Map<String, dynamic> row) {
    final entityType = row['entityType'] as String? ?? '?';
    final operation  = row['operation']  as String? ?? '?';
    final err        = row['lastError']  as String? ?? 'Unknown error';
    final updatedAt  = row['updatedAt']  as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              size: 14, color: AppColors.softRed),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$entityType · $operation',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreenText,
                  ),
                ),
                Text(
                  err,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.softRed,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeAgo(updatedAt),
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.lightGreenText,
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
          const Icon(Icons.warning_amber_outlined,
              size: 16, color: AppColors.softRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
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
            onPressed: syncing ? null : _retry,
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
            side: const BorderSide(color: AppColors.lightGreenBorder),
          ),
        ),
      ],
    );
  }

  Widget _buildDeactivateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppColors.lightGreenBorder, height: 1),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: (_deactivating || !_status.isActivated) ? null : _deactivate,
          icon: _deactivating
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.softRed),
                )
              : const Icon(Icons.link_off_outlined, size: 16),
          label: Text(_deactivating ? 'Duke çaktivizuar…' : 'Çaktivizo këtë pajisje'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.softRed,
            side: BorderSide(
              color: AppColors.softRed.withValues(alpha: 0.4),
            ),
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
}
