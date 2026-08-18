import 'package:dart_vm/dart_vm.dart';
import 'package:test/test.dart';

void main() {
  test('discovers reachable services and parses Flutter app names', () async {
    final discovery = VmServiceDiscovery(
      processSnapshotLoader: () async => '''
100 unrelated --vm-service-uri=http://127.0.0.1:1/a/
200 dart development-service --vm-service-uri=http://127.0.0.1:2/b/ --bind-port=0 --app-name=Kind: Flutter - Device: Pixel 9 - Package: second_app
300 dart development-service --vm-service-uri=http://127.0.0.1:3/c/ --bind-port=0 --app-name=Kind: Flutter - Device: iPhone 17 Pro - Package: example_app
400 dart development-service --vm-service-uri=http://127.0.0.1:4/stale/ --app-name=Kind: Flutter - Device: Stale - Package: stale_app
''',
      probe: (uri) async => !uri.contains('stale'),
    );

    final services = await discovery.discover();

    expect(services.map((service) => service.deviceName), [
      'Pixel 9',
      'iPhone 17 Pro',
    ]);
    expect(services.first.toJson(), <String, Object?>{
      'pid': 200,
      'kind': 'Flutter',
      'deviceName': 'Pixel 9',
      'packageName': 'second_app',
      'uri': 'http://127.0.0.1:2/b/',
      'reachable': true,
    });
  });

  test('deduplicates candidates by VM Service URI', () async {
    final probed = <String>[];
    final discovery = VmServiceDiscovery(
      processSnapshotLoader: () async => '''
100 dart development-service --vm-service-uri=http://127.0.0.1:2/token/ --app-name=Kind: Flutter - Device: Device A - Package: app
200 dart development-service --vm-service-uri=http://127.0.0.1:2/token/ --app-name=Kind: Flutter - Device: Device A - Package: app
''',
      probe: (uri) async {
        probed.add(uri);
        return true;
      },
    );

    final services = await discovery.discover();

    expect(services, hasLength(1));
    expect(services.single.pid, 100);
    expect(probed, ['http://127.0.0.1:2/token/']);
  });

  test('returns an empty list when no reachable service exists', () async {
    final discovery = VmServiceDiscovery(
      processSnapshotLoader: () async =>
          '100 dart development-service --vm-service-uri=http://127.0.0.1:2/stale/',
      probe: (_) async => false,
    );

    expect(await discovery.discover(), isEmpty);
  });
}
