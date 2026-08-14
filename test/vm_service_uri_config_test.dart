import 'dart:io';

import 'package:dart_vm/dart_vm.dart';
import 'package:test/test.dart';

void main() {
  test('stores, reads, and clears a VM Service URI', () async {
    final directory = await Directory.systemTemp.createTemp('dart-vm-config-');
    addTearDown(() => directory.delete(recursive: true));
    final store = VmServiceUriConfigStore(
      filePath: '${directory.path}${Platform.pathSeparator}config.json',
    );

    expect(await store.read(), isNull);
    await store.write('http://127.0.0.1:8181/token/');
    expect(await store.read(), 'http://127.0.0.1:8181/token/');
    expect(await store.clear(), isTrue);
    expect(await store.read(), isNull);
    expect(await store.clear(), isFalse);
  });

  test('rejects unsupported VM Service URI schemes', () async {
    final directory = await Directory.systemTemp.createTemp('dart-vm-config-');
    addTearDown(() => directory.delete(recursive: true));
    final store = VmServiceUriConfigStore(
      filePath: '${directory.path}${Platform.pathSeparator}config.json',
    );

    expect(
      () => store.write('ftp://127.0.0.1:8181/token/'),
      throwsArgumentError,
    );
  });
}
