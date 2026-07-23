import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('exposes network as the top-level capability', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'help',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('network'));
    expect(result.stdout, isNot(contains('\n  status')));
  });

  test('lists HTTP profile commands under network', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'help',
      'network',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, allOf(contains('status'), contains('requests')));
  });

  test('documents the required request ID option', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'help',
      'network',
      'request',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('--id=<request-id>'));
    expect(result.stdout, contains('network requests'));
  });

  test('accepts a negative request ID as an option value', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'network',
      'request',
      '--id=-242378432789',
    ]);

    expect(result.exitCode, isNonZero);
    expect(result.stderr, contains('DART_VM_SERVICE_URI'));
    expect(result.stderr, isNot(contains('short name')));
  });

  test('documents the requests path option value', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'help',
      'network',
      'requests',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('--path=<路径片段>'));
  });
}
