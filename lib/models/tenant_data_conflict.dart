/// Shown when activating links to a different business than local SQLite data.
class TenantDataConflict {
  const TenantDataConflict({
    required this.newBusinessId,
    this.previousBusinessId,
    this.previousBusinessName,
    required this.hasMeaningfulLocalData,
    required this.hasForeignScopedData,
  });

  final String newBusinessId;
  final String? previousBusinessId;
  final String? previousBusinessName;
  final bool hasMeaningfulLocalData;
  final bool hasForeignScopedData;

  bool get isDifferentBusiness =>
      previousBusinessId != null &&
      previousBusinessId!.isNotEmpty &&
      previousBusinessId != newBusinessId;
}
