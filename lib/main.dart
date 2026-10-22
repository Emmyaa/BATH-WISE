import 'package:bath_wise/app.dart';
import 'package:bath_wise/features/settings/data/prefs_settings_store.dart';
import 'package:bath_wise/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loaded before the first frame so theme, language and the app lock
  // apply immediately (no flash of the wrong theme or unlocked content).
  final settings = await PrefsSettingsStore.open();
  runApp(
    ProviderScope(
      overrides: [settingsStoreProvider.overrideWithValue(settings)],
      child: const BathWiseApp(),
    ),
  );
}
