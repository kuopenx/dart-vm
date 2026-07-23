import 'package:dart_vm/dart_vm.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeVmServiceUri', () {
    test('converts HTTP(S) URIs to WebSocket URIs', () {
      expect(
        normalizeVmServiceUri('http://127.0.0.1:8181/token/'),
        'ws://127.0.0.1:8181/token/',
      );
      expect(
        normalizeVmServiceUri('https://example.test/token/'),
        'wss://example.test/token/',
      );
    });

    test('keeps WebSocket URIs unchanged', () {
      expect(
        normalizeVmServiceUri('ws://127.0.0.1:8181/token/'),
        'ws://127.0.0.1:8181/token/',
      );
    });

    test('rejects unsupported schemes', () {
      expect(
        () => normalizeVmServiceUri('ftp://example.test'),
        throwsArgumentError,
      );
    });
  });
}
