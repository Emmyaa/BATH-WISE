import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// Source of "now", injectable so release-time logic is testable.
class Clock {
  const new();

  /// Current instant in UTC.
  DateTime now() => DateTime.now().toUtc();
}

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const Clock();
