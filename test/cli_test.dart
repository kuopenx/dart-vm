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

  test('documents the request ID positional argument', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'help',
      'network',
      'request',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('<request-id>'));
    expect(result.stdout, contains('network requests'));
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
