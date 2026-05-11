import 'database_service.dart';

/// Backward-compatible alias for codepaths that expect a `DatabaseHelper`.
///
/// The project uses [DatabaseService] as the concrete implementation.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseService instance = DatabaseService.instance;
}
