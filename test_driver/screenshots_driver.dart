// Saves screenshots taken by integration_test/screenshots_test.dart into
// docs/screenshots/. See that file for how to run it.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    File('docs/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
    return true;
  },
);
