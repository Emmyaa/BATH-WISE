import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_mode_controller.g.dart';

/// Selected Light / Dark / System mode. In-memory for now; persisted with
/// the rest of the settings in Phase 8.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ThemeMode.system;

  // A method, not a setter: Notifier convention, and it becomes async once
  // the choice is persisted.
  // ignore: use_setters_to_change_properties
  void select(ThemeMode mode) => state = mode;
}
