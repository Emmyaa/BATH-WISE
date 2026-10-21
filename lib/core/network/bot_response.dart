/// Unwraps BOT's `{result: {data: {data_detail: ...}}}` envelope.
///
/// The specs type `data_detail` as an object for daily/monthly/quarterly
/// and as an array for annual; real responses are always arrays. Accept
/// both. Throws [FormatException] if the envelope is missing.
List<Map<String, dynamic>> botDataDetail(Object? body) {
  final detail = switch (body) {
    {'result': {'data': {'data_detail': final Object? detail}}} => detail,
    _ => throw FormatException('Missing result.data.data_detail', body),
  };
  return switch (detail) {
    null => const [],
    final Map<String, dynamic> single => [single],
    final List<dynamic> list => [
      for (final item in list)
        if (item is Map<String, dynamic>)
          item
        else
          throw FormatException('data_detail item is not an object', item),
    ],
    _ => throw FormatException('Unexpected data_detail', detail),
  };
}
