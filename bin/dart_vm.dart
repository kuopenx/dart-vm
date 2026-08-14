import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_vm/dart_vm.dart';

const version = '0.1.0';

void _writeJson(Object? value) {
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(value));
}

Future<void> main(List<String> arguments) async {
  final runner =
      CommandRunner<void>(
          'dart-vm',
          'Inspect Dart VM Service network and Flutter Inspector data.',
        )
        ..argParser.addOption(
          'uri',
          abbr: 'u',
          valueHelp: 'VM_SERVICE_URI',
          help:
              'HTTP(S) or WebSocket VM Service URI. Defaults to DART_VM_SERVICE_URI.',
          defaultsTo: Platform.environment['DART_VM_SERVICE_URI'],
        )
        ..argParser.addFlag(
          'version',
          negatable: false,
          help: 'Print the version.',
        )
        ..addCommand(NetworkCommand())
        ..addCommand(ExtensionCommand())
        ..addCommand(ConfigCommand())
        ..addCommand(UiCommand());

  try {
    if (arguments.length == 1 && arguments.single == '--version') {
      stdout.writeln(version);
      return;
    }
    await runner.run(arguments);
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } catch (error) {
    stderr.writeln('dart-vm: $error');
    exitCode = 1;
  }
}

abstract class VmCommand extends Command<void> {
  Future<String> resolveUri() async {
    final value = globalResults?['uri'] as String?;
    if (value != null && value.isNotEmpty) {
      return value;
    }
    final saved = await VmServiceUriConfigStore().read();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    throw UsageException(
      'No VM Service URI configured. Pass --uri <VM_SERVICE_URI>, set DART_VM_SERVICE_URI, or run "dart-vm config uri set <VM_SERVICE_URI>".',
      usage,
    );
  }

  StateError staleUriError() {
    return StateError(
      'Could not connect to the configured VM Service. The App may have restarted; run "dart-vm config uri set <VM_SERVICE_URI>" with the new URI.',
    );
  }

  Future<T> withClient<T>(
    Future<T> Function(NetworkProfileClient client) action,
  ) async {
    final targetUri = await resolveUri();
    try {
      final client = await NetworkProfileClient.connect(targetUri);
      try {
        return await action(client);
      } finally {
        await client.dispose();
      }
    } on SocketException catch (_) {
      throw staleUriError();
    } on WebSocketException catch (_) {
      throw staleUriError();
    }
  }

  Future<T> withInspector<T>(
    Future<T> Function(InspectorClient client) action,
  ) async {
    final targetUri = await resolveUri();
    try {
      final client = await InspectorClient.connect(targetUri);
      try {
        return await action(client);
      } finally {
        await client.dispose();
      }
    } on SocketException catch (_) {
      throw staleUriError();
    } on WebSocketException catch (_) {
      throw staleUriError();
    }
  }

  Future<T> withExtension<T>(
    String extension,
    String? isolate,
    Future<T> Function(ServiceExtensionClient client) action,
  ) async {
    final targetUri = await resolveUri();
    try {
      final client = await ServiceExtensionClient.connect(
        targetUri,
        extension: extension,
        isolate: isolate,
      );
      try {
        return await action(client);
      } finally {
        await client.dispose();
      }
    } on SocketException catch (_) {
      throw staleUriError();
    } on WebSocketException catch (_) {
      throw staleUriError();
    }
  }

  void printJson(Object? value) {
    _writeJson(value);
  }
}

abstract class UiVmCommand extends VmCommand {}

class ExtensionCommand extends Command<void> {
  ExtensionCommand() {
    addSubcommand(ExtensionCallCommand());
  }

  @override
  final name = 'extension';

  @override
  final description = 'Call a Dart VM Service isolate extension.';

  @override
  Future<void> run() =>
      throw UsageException('Choose an extension subcommand.', usage);
}

class ExtensionCallCommand extends VmCommand {
  ExtensionCallCommand() {
    argParser
      ..addOption(
        'name',
        valueHelp: 'name',
        help: 'VM Service extension name, for example ext.example.status.',
        mandatory: true,
      )
      ..addOption(
        'isolate',
        valueHelp: 'isolate',
        help: 'Isolate name or ID. Defaults to the main isolate.',
      )
      ..addMultiOption(
        'param',
        help: 'Extension parameter in key=value form. May be repeated.',
        valueHelp: 'key=value',
      );
  }

  @override
  final name = 'call';

  @override
  final description = 'Call an extension and print its JSON result.';

  @override
  String get usageFooter =>
      'Example: dart-vm extension call --name ext.example.status --param limit=20';

  @override
  Future<void> run() async {
    final extension = argResults!['name'] as String;
    if (extension.isEmpty) {
      throw UsageException('--name must not be empty.', usage);
    }
    final isolate = argResults!['isolate'] as String?;
    final parameters = <String, String>{};
    for (final raw in argResults!['param'] as List<String>) {
      final separator = raw.indexOf('=');
      if (separator <= 0) {
        throw UsageException(
          'Invalid --param "$raw". Expected key=value.',
          usage,
        );
      }
      final key = raw.substring(0, separator);
      if (parameters.containsKey(key)) {
        throw UsageException('Duplicate --param key "$key".', usage);
      }
      parameters[key] = raw.substring(separator + 1);
    }

    await withExtension(extension, isolate, (client) async {
      printJson({
        'isolateId': client.isolateId,
        'result': await client.call(extension, parameters),
      });
    });
  }
}

class ConfigCommand extends Command<void> {
  ConfigCommand() {
    addSubcommand(ConfigUriCommand());
  }

  @override
  final name = 'config';

  @override
  final description = 'Manage local dart-vm configuration.';

  @override
  Future<void> run() =>
      throw UsageException('Choose a config subcommand.', usage);
}

class ConfigUriCommand extends Command<void> {
  ConfigUriCommand() {
    addSubcommand(ConfigUriSetCommand());
    addSubcommand(ConfigUriShowCommand());
    addSubcommand(ConfigUriClearCommand());
  }

  @override
  final name = 'uri';

  @override
  final description = 'Set, inspect, or clear the saved VM Service URI.';

  @override
  Future<void> run() =>
      throw UsageException('Choose a config uri subcommand.', usage);
}

class ConfigUriSetCommand extends Command<void> {
  @override
  final name = 'set';

  @override
  final description = 'Save a VM Service URI for subsequent commands.';

  @override
  String get invocation => '${super.invocation} <VM_SERVICE_URI>';

  @override
  String get usageFooter =>
      'Example: dart-vm config uri set http://127.0.0.1:8181/token/';

  @override
  Future<void> run() async {
    final values = argResults!.rest;
    if (values.length != 1) {
      throw UsageException('Expected exactly one VM Service URI.', usage);
    }
    final store = VmServiceUriConfigStore();
    await store.write(values.single);
    _writeJson({'configured': true, 'path': store.filePath});
  }
}

class ConfigUriShowCommand extends Command<void> {
  @override
  final name = 'show';

  @override
  final description = 'Show the saved VM Service URI.';

  @override
  String get usageFooter => 'Example: dart-vm config uri show';

  @override
  Future<void> run() async {
    final store = VmServiceUriConfigStore();
    _writeJson({'uri': await store.read(), 'path': store.filePath});
  }
}

class ConfigUriClearCommand extends Command<void> {
  @override
  final name = 'clear';

  @override
  final description = 'Remove the saved VM Service URI.';

  @override
  String get usageFooter => 'Example: dart-vm config uri clear';

  @override
  Future<void> run() async {
    final store = VmServiceUriConfigStore();
    _writeJson({'cleared': await store.clear(), 'path': store.filePath});
  }
}

class UiCommand extends Command<void> {
  UiCommand() {
    addSubcommand(UiStatusCommand());
    addSubcommand(UiTreeCommand());
    addSubcommand(UiDetailsCommand());
    addSubcommand(UiLayoutCommand());
    addSubcommand(UiScreenshotCommand());
  }
  @override
  final name = 'ui';
  @override
  final description =
      'Inspect Flutter Widget trees, details, layout, and screenshots.';
  @override
  Future<void> run() => throw UsageException('Choose a ui subcommand.', usage);
}

class UiStatusCommand extends UiVmCommand {
  @override
  final name = 'status';
  @override
  final description = 'Show Flutter Inspector and Widget tree availability.';
  @override
  String get usageFooter => 'Example: dart-vm ui status';
  @override
  Future<void> run() => withInspector(
    (client) async => printJson({
      'isolateId': await client.isolateId,
      'widgetTreeReady': await client.call('isWidgetTreeReady'),
      'widgetCreationTracked': await client.call('isWidgetCreationTracked'),
    }),
  );
}

class UiTreeCommand extends UiVmCommand {
  @override
  final name = 'tree';
  @override
  final description =
      'Print the root Widget summary tree and reusable node IDs.';
  @override
  String get usageFooter => 'Example: dart-vm ui tree';
  @override
  Future<void> run() => withInspector(
    (client) async => printJson(await client.call('getRootWidgetSummaryTree')),
  );
}

abstract class UiNodeCommand extends UiVmCommand {
  UiNodeCommand() {
    argParser.addOption(
      'id',
      valueHelp: 'widget-id',
      mandatory: true,
      help: 'Widget node ID from ui tree.',
    );
  }
  String get id => argResults!['id'] as String;
}

class UiDetailsCommand extends UiNodeCommand {
  @override
  final name = 'details';
  @override
  final description = 'Print properties and the details subtree for a Widget.';
  @override
  String get usageFooter => 'Example: dart-vm ui details --id=<widget-id>';
  @override
  Future<void> run() => withInspector(
    (client) async =>
        printJson(await client.call('getDetailsSubtree', {'arg': id})),
  );
}

class UiLayoutCommand extends UiNodeCommand {
  UiLayoutCommand() {
    argParser.addOption(
      'depth',
      valueHelp: 'depth',
      defaultsTo: '1',
      help: 'Layout subtree depth.',
    );
  }
  @override
  final name = 'layout';
  @override
  final description = 'Print Layout Explorer data for a Widget.';
  @override
  String get usageFooter =>
      'Example: dart-vm ui layout --id=<widget-id> --depth=1';
  @override
  Future<void> run() => withInspector(
    (client) async => printJson(
      await client.call('getLayoutExplorerNode', {
        'id': id,
        'subtreeDepth': argResults!['depth'],
      }),
    ),
  );
}

class UiScreenshotCommand extends UiNodeCommand {
  UiScreenshotCommand() {
    argParser
      ..addOption(
        'width',
        valueHelp: 'px',
        mandatory: true,
        help: 'Maximum screenshot width.',
      )
      ..addOption(
        'height',
        valueHelp: 'px',
        mandatory: true,
        help: 'Maximum screenshot height.',
      )
      ..addOption(
        'out',
        valueHelp: 'png-path',
        mandatory: true,
        help: 'PNG output path.',
      );
  }
  @override
  final name = 'screenshot';
  @override
  final description = 'Capture a Widget and write it to a PNG file.';
  @override
  String get usageFooter =>
      'Example: dart-vm ui screenshot --id=<widget-id> --width=390 --height=844 --out=widget.png';
  @override
  Future<void> run() => withInspector((client) async {
    final result = await client.call('screenshot', {
      'id': id,
      'width': argResults!['width'],
      'height': argResults!['height'],
    });
    if (result == null) {
      throw StateError('Inspector did not return a screenshot.');
    }
    final out = File(argResults!['out'] as String);
    await out.writeAsBytes(base64Decode(result as String));
    printJson({'out': out.path, 'bytes': await out.length()});
  });
}

class NetworkCommand extends Command<void> {
  NetworkCommand() {
    addSubcommand(StatusCommand());
    addSubcommand(LoggingCommand(enabled: true));
    addSubcommand(LoggingCommand(enabled: false));
    addSubcommand(RequestsCommand());
    addSubcommand(RequestCommand());
  }

  @override
  final name = 'network';

  @override
  final description = 'Inspect and control dart:io HTTP profile data.';

  @override
  Future<void> run() {
    throw UsageException('Choose a network subcommand.', usage);
  }
}

class StatusCommand extends VmCommand {
  @override
  final name = 'status';

  @override
  final description = 'Show the target isolate and HTTP profile logging state.';

  @override
  String get usageFooter => 'Example: dart-vm network status';

  @override
  Future<void> run() => withClient((client) async {
    final state = await client.loggingState();
    printJson({
      'isolateId': await client.isolateId,
      'loggingEnabled': state.enabled,
    });
  });
}

class LoggingCommand extends VmCommand {
  LoggingCommand({required this.enabled});

  final bool enabled;

  @override
  String get name => enabled ? 'on' : 'off';

  @override
  String get description => enabled
      ? 'Enable HTTP profiling for this App run.'
      : 'Stop recording future HTTP requests for this App run.';

  @override
  String get usageFooter => enabled
      ? 'Only future dart:io requests are recorded; profiling resets on App restart.\nExample: dart-vm network on'
      : 'Recorded data is retained until the App restarts or the profile is cleared.\nExample: dart-vm network off';

  @override
  Future<void> run() => withClient((client) async {
    final state = await client.loggingState(enabled);
    printJson({
      'isolateId': await client.isolateId,
      'loggingEnabled': state.enabled,
    });
  });
}

class RequestsCommand extends VmCommand {
  RequestsCommand() {
    argParser.addOption(
      'path',
      valueHelp: 'path-fragment',
      help: 'Only include request URIs containing this text.',
    );
  }

  @override
  final name = 'requests';

  @override
  final description = 'List recorded HTTP requests, newest first.';

  @override
  String get usageFooter =>
      'Example: dart-vm network requests --path=/activity/';

  @override
  Future<void> run() => withClient((client) async {
    final path = argResults!['path'] as String?;
    final profile = await client.requests();
    final requests =
        profile.requests
            .where(
              (request) =>
                  path == null || request.uri.toString().contains(path),
            )
            .toList()
          ..sort((left, right) => right.startTime.compareTo(left.startTime));
    printJson(requests.map(summarizeRequest).toList());
  });
}

class RequestCommand extends VmCommand {
  RequestCommand() {
    argParser.addOption(
      'id',
      valueHelp: 'request-id',
      help: 'Request ID to inspect; negative IDs work as --id=-2.',
      mandatory: true,
    );
    argParser.addFlag(
      'body',
      negatable: false,
      help:
          'Include UTF-8 request and response bodies. Headers and cookies are never printed.',
    );
  }

  @override
  final name = 'request';

  @override
  final description = 'Show a recorded HTTP request by ID.';

  @override
  String get invocation =>
      '${super.invocation.replaceFirst(' [arguments]', '')} '
      '--id=<request-id> [--body]';

  @override
  bool get takesArguments => false;

  @override
  String get usageFooter =>
      'request-id comes from the id field in network requests.\n'
      'Example: dart-vm network request --id=-242378432789 --body';

  @override
  Future<void> run() async {
    final id = argResults!['id'] as String;
    await withClient((client) async {
      final request = await client.request(id);
      printJson(describeRequest(request, body: argResults!['body'] as bool));
    });
  }
}
