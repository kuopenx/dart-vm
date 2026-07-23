import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_vm/dart_vm.dart';

const version = '0.1.0';

Future<void> main(List<String> arguments) async {
  final runner =
      CommandRunner<void>(
          'dart-vm',
          '通过运行中的 Dart VM Service 查看 dart:io HTTP 网络采集数据。',
        )
        ..argParser.addOption(
          'uri',
          abbr: 'u',
          valueHelp: 'VM_SERVICE_URI',
          help: 'HTTP(S) 或 WebSocket VM Service URI；默认读取 DART_VM_SERVICE_URI。',
          defaultsTo: Platform.environment['DART_VM_SERVICE_URI'],
        )
        ..argParser.addFlag('version', negatable: false, help: '输出版本号。')
        ..addCommand(NetworkCommand());

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
    stderr.writeln('dart-vm：$error');
    exitCode = 1;
  }
}

abstract class VmCommand extends Command<void> {
  String get uri {
    final value = globalResults?['uri'] as String?;
    if (value == null || value.isEmpty) {
      throw UsageException(
        '请传入 --uri <VM_SERVICE_URI>，或设置 DART_VM_SERVICE_URI。',
        usage,
      );
    }
    return value;
  }

  Future<T> withClient<T>(
    Future<T> Function(NetworkProfileClient client) action,
  ) async {
    final client = await NetworkProfileClient.connect(uri);
    try {
      return await action(client);
    } finally {
      await client.dispose();
    }
  }

  void printJson(Object? value) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(value));
  }
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
  final description = '查看和控制 dart:io HTTP 网络采集数据。';

  @override
  Future<void> run() {
    throw UsageException('请选择一个 network 子命令。', usage);
  }
}

class StatusCommand extends VmCommand {
  @override
  final name = 'status';

  @override
  final description = '查看目标 isolate 与 HTTP 网络采集开关状态。';

  @override
  String get usageFooter => '示例：dart-vm network status';

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
  String get description =>
      enabled ? '开启当前 App 运行期间的 HTTP 网络采集。' : '停止记录当前 App 后续发出的 HTTP 请求。';

  @override
  String get usageFooter => enabled
      ? '只记录开启后的 dart:io 请求；App 重启后采集会关闭。\n示例：dart-vm network on'
      : '已记录的数据不会被清空；App 重启后数据会丢失。\n示例：dart-vm network off';

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
    argParser.addOption('path', valueHelp: '路径片段', help: '只保留 URI 包含该文本的请求。');
  }

  @override
  final name = 'requests';

  @override
  final description = '按开始时间倒序列出已记录的 HTTP 请求。';

  @override
  String get usageFooter => '示例：dart-vm network requests --path=/activity/';

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
      help: '要查看的请求 ID；负数 ID 可直接使用 --id=-2 的形式传入。',
      mandatory: true,
    );
    argParser.addFlag(
      'body',
      negatable: false,
      help: '输出 UTF-8 请求与响应 body；不会输出 headers 或 cookies。',
    );
  }

  @override
  final name = 'request';

  @override
  final description = '查看指定 ID 的已记录 HTTP 请求。';

  @override
  String get invocation =>
      '${super.invocation.replaceFirst(' [arguments]', '')} '
      '--id=<request-id> [--body]';

  @override
  bool get takesArguments => false;

  @override
  String get usageFooter =>
      'request-id 来自 network requests 的 id 字段。\n'
      '示例：dart-vm network request --id=-242378432789 --body';

  @override
  Future<void> run() async {
    final id = argResults!['id'] as String;
    await withClient((client) async {
      final request = await client.request(id);
      printJson(describeRequest(request, body: argResults!['body'] as bool));
    });
  }
}
