import 'package:envied/envied.dart';

part 'env.g.dart';

/// Compile-time secrets read from `.env` by envied.
///
/// Values are XOR-obfuscated in the generated `env.g.dart` (gitignored).
/// This raises the bar against casual extraction, but anything shipped in
/// an app binary should still be treated as recoverable.
@Envied(path: '.env', obfuscate: true)
abstract final class Env {
  @EnviedField(varName: 'BOT_API_TOKEN')
  static final String botApiToken = _Env.botApiToken;
}
