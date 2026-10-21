import 'package:bath_wise/core/error/failure.dart';
import 'package:bath_wise/core/error/result.dart';
import 'package:bath_wise/core/network/failure_mapper.dart';
import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

/// Runs a remote call and turns every exception into a typed [Failure],
/// so raw exceptions never leave the data layer.
Future<Result<T>> guardRequest<T>(Future<T> Function() request) async {
  try {
    return Ok(await request());
  } on DioException catch (e) {
    final error = e.error;
    return Err(error is Failure ? error : failureFromDioException(e));
  } on Failure catch (f) {
    return Err(f);
  } on CheckedFromJsonException catch (e) {
    return Err(ParsingFailure('${e.className}.${e.key}: ${e.message}'));
  } on FormatException catch (e) {
    return Err(ParsingFailure(e.message));
  }
}
