/// Converts an HTTP(S) VM Service URI to the WebSocket URI required by
/// [vmServiceConnectUri]. WebSocket URIs are returned unchanged.
String normalizeVmServiceUri(String value) {
  final uri = Uri.parse(value);
  final scheme = switch (uri.scheme) {
    'http' => 'ws',
    'https' => 'wss',
    'ws' || 'wss' => uri.scheme,
    _ => throw ArgumentError.value(
      value,
      'uri',
      'Expected an http(s) or ws(s) VM Service URI.',
    ),
  };
  return uri.replace(scheme: scheme).toString();
}
