/// Shown when activating links to a different business than local SQLite data.
class TenantDataConflict {
  const TenantDataConflict({
    required this.newBusinessId,
    this.previousBusinessId,
    this.previousBusinessName,
    required this.hasMeaningfulLocalData,
    required this.hasForeignScopedData,
    this.wipeRequired = false,
  });

  final String newBusinessId;
  final String? previousBusinessId;
  final String? previousBusinessName;
  final bool hasMeaningfulLocalData;
  final bool hasForeignScopedData;

  /// When true, release builds must not activate without wiping first.
  final bool wipeRequired;

  bool get isDifferentBusiness =>
      previousBusinessId != null &&
      previousBusinessId!.isNotEmpty &&
      previousBusinessId != newBusinessId;
}
