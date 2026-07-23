import 'dart:io';

import 'package:test/test.dart';

void main() {
  Future<String> help(List<String> command) async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'help',
      ...command,
    ]);
    expect(result.exitCode, 0, reason: command.join(' '));
    return result.stdout as String;
  }

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

  test('lists the read-only UI commands', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/dart_vm.dart',
      'help',
      'ui',
    ]);
    expect(result.exitCode, 0);
    for (final command in [
      'status',
      'tree',
      'details',
      'layout',
      'screenshot',
    ]) {
      expect(result.stdout, contains(command));
    }
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

  test('documents every leaf command and its parameters', () async {
    final cases = <List<String>, List<String>>{
      ['network', 'status']: [],
      ['network', 'on']: [],
      ['network', 'off']: [],
      ['network', 'requests']: ['--path=<路径片段>'],
      ['network', 'request']: ['--id=<request-id>', '--body'],
      ['ui', 'status']: [],
      ['ui', 'tree']: [],
      ['ui', 'details']: ['--id=<widget-id>'],
      ['ui', 'layout']: ['--id=<widget-id>', '--depth=<层数>'],
      ['ui', 'screenshot']: [
        '--id=<widget-id>',
        '--width=<像素>',
        '--height=<像素>',
        '--out=<png路径>',
      ],
    };

    final rootHelp = await help([]);
    expect(
      rootHelp,
      allOf(contains('--uri=<VM_SERVICE_URI>'), contains('--version')),
    );
    for (final entry in cases.entries) {
      final output = await help(entry.key);
      for (final parameter in entry.value) {
        expect(output, contains(parameter), reason: entry.key.join(' '));
      }
    }
  });
}
