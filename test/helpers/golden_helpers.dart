import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's real font and Material icons, so goldens show real
/// text and icons instead of the test font's boxes. Emoji flags still
/// render as boxes (no emoji font in tests).
Future<void> loadAppFonts() async {
  // From the Flutter SDK, which `flutter test` runs inside of.
  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk != null) {
    final icons = File(
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
  }

  final loader = FontLoader('IBMPlexSansThai');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/IBMPlexSansThai-$weight.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Accepts up to [tolerance] (fraction of pixels) of difference.
///
/// Goldens are generated on macOS; CI renders on Linux, where text
/// anti-aliasing differs by a fraction of a percent. Layout, color or
/// content changes are far above this.
class TolerantGoldenComparator extends LocalFileComparator {
  new(super.testFile, {this.tolerance = 0.01});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

/// Installs [TolerantGoldenComparator] for the calling test file.
void useTolerantGoldens() {
  final current = goldenFileComparator;
  if (current is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      Uri.parse('${current.basedir}/x_test.dart'),
    );
  }
}
