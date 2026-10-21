import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';

/// Wraps a repository operation so local database errors (SqliteException,
/// DriftWrappedException, …) surface as [CacheFailure] instead of escaping.
Future<Result<T>> guardCache<T>(Future<Result<T>> Function() body) async {
  try {
    return await body();
  } on Failure catch (f) {
    return Err(f);
  } on Exception catch (e) {
    return Err(CacheFailure(e.toString()));
  }
}
