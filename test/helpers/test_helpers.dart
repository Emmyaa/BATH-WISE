import 'dart:convert';
import 'dart:io';

import 'package:bath_wise/core/database/app_database.dart';
import 'package:bath_wise/core/time/bangkok_time.dart';
import 'package:bath_wise/core/time/clock.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Body of a real response captured by tool/fetch_api_samples.dart.
Object? loadApiSample(String name) {
  final file = File('docs/api-samples/$name.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return json['body'];
}

/// A hand-written, spec-shaped fixture from test/fixtures.
Object? loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());

AppDatabase inMemoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// The instant at [hour]:[minute] Bangkok time on y-m-d.
DateTime bkk(int y, int m, int d, [int hour = 0, int minute = 0]) =>
    Bangkok.instantAt(DateTime.utc(y, m, d), hour: hour, minute: minute);

class FakeClock extends Clock {
  new(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration by) => current = current.add(by);
}

/// Dio adapter that replays queued responses and records requests.
class FakeHttpAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _queue = <ResponseBody Function(RequestOptions)>[];

  void enqueueJson(
    int status,
    Object? body, {
    Map<String, List<String>> headers = const {},
  }) => _queue.add(
    (_) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    ),
  );

  void enqueueConnectionError() => _queue.add(
    (options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    ),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_queue.isEmpty) throw StateError('No response queued');
    return _queue.removeAt(0)(options);
  }

  @override
  void close({bool force = false}) {}
}
