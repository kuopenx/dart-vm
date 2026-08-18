import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'vm_service_uri.dart';

typedef ProcessSnapshotLoader = Future<String> Function();
typedef VmServiceProbe = Future<bool> Function(String uri);

/// One reachable Dart VM Service exposed by a local development-service.
final class RunningVmService {
  const RunningVmService({
    required this.pid,
    required this.kind,
    required this.deviceName,
    required this.packageName,
    required this.uri,
  });

  final int pid;
  final String? kind;
  final String? deviceName;
  final String? packageName;
  final String uri;

  Map<String, Object?> toJson() => <String, Object?>{
    'pid': pid,
    'kind': kind,
    'deviceName': deviceName,
    'packageName': packageName,
    'uri': uri,
    'reachable': true,
  };
}

/// Discovers reachable VM Services started by local Flutter tooling or IDEs.
final class VmServiceDiscovery {
  VmServiceDiscovery({
    ProcessSnapshotLoader? processSnapshotLoader,
    VmServiceProbe? probe,
  }) : _processSnapshotLoader = processSnapshotLoader ?? _loadProcessSnapshot,
       _probe = probe ?? _probeVmService;

  final ProcessSnapshotLoader _processSnapshotLoader;
  final VmServiceProbe _probe;

  Future<List<RunningVmService>> discover() async {
    final snapshot = await _processSnapshotLoader();
    final candidates = _parseCandidates(snapshot);
    final reachable = await Future.wait(
      candidates.map((candidate) async {
        return await _probe(candidate.uri) ? candidate : null;
      }),
    );
    final services = reachable.whereType<RunningVmService>().toList();
    services.sort(_compareServices);
    return List<RunningVmService>.unmodifiable(services);
  }
}

Future<String> _loadProcessSnapshot() async {
  final ProcessResult result;
  if (Platform.isWindows) {
    result = await Process.run('powershell', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'Get-CimInstance Win32_Process | ForEach-Object { "$($_.ProcessId)`t$($_.CommandLine)" }',
    ]);
  } else {
    result = await Process.run('ps', <String>['-axo', 'pid=,command=']);
  }
  if (result.exitCode != 0) {
    final error = (result.stderr as String).trim();
    throw StateError(
      error.isEmpty
          ? 'Could not inspect local processes.'
          : 'Could not inspect local processes: $error',
    );
  }
  return result.stdout as String;
}

Future<bool> _probeVmService(String uri) async {
  VmService? service;
  try {
    service = await vmServiceConnectUri(
      normalizeVmServiceUri(uri),
    ).timeout(const Duration(seconds: 2));
    await service.getVM().timeout(const Duration(seconds: 2));
    return true;
  } catch (_) {
    return false;
  } finally {
    await service?.dispose();
  }
}

List<RunningVmService> _parseCandidates(String snapshot) {
  final byUri = <String, RunningVmService>{};
  for (final line in snapshot.split('\n')) {
    if (!line.contains('development-service') ||
        !line.contains('--vm-service-uri=')) {
      continue;
    }
    final process = RegExp(r'^\s*(\d+)\s+(.+)$').firstMatch(line);
    final pid = int.tryParse(process?.group(1) ?? '');
    final command = process?.group(2);
    if (pid == null || command == null) {
      continue;
    }
    final uri = _optionValue(command, 'vm-service-uri', singleToken: true);
    if (uri == null) {
      continue;
    }
    final app = _parseAppName(_optionValue(command, 'app-name'));
    byUri.putIfAbsent(
      uri,
      () => RunningVmService(
        pid: pid,
        kind: app?.kind,
        deviceName: app?.deviceName,
        packageName: app?.packageName,
        uri: uri,
      ),
    );
  }
  return byUri.values.toList(growable: false);
}

String? _optionValue(String command, String name, {bool singleToken = false}) {
  final marker = '--$name=';
  final markerIndex = command.indexOf(marker);
  if (markerIndex < 0) {
    return null;
  }
  final value = command.substring(markerIndex + marker.length);
  if (singleToken) {
    final end = value.indexOf(RegExp(r'\s'));
    return (end < 0 ? value : value.substring(0, end)).trim();
  }
  final nextOption = RegExp(r'\s--[A-Za-z0-9-]+(?:=|\s|$)').firstMatch(value);
  return (nextOption == null ? value : value.substring(0, nextOption.start))
      .trim();
}

_AppName? _parseAppName(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final match = RegExp(
    r'^Kind:\s*(.*?)\s+-\s+Device:\s*(.*?)\s+-\s+Package:\s*(.*?)$',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }
  return _AppName(
    kind: _nonEmpty(match.group(1)),
    deviceName: _nonEmpty(match.group(2)),
    packageName: _nonEmpty(match.group(3)),
  );
}

String? _nonEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _compareServices(RunningVmService left, RunningVmService right) {
  final deviceOrder = (left.deviceName ?? '').compareTo(right.deviceName ?? '');
  if (deviceOrder != 0) {
    return deviceOrder;
  }
  final packageOrder = (left.packageName ?? '').compareTo(
    right.packageName ?? '',
  );
  return packageOrder != 0 ? packageOrder : left.pid.compareTo(right.pid);
}

final class _AppName {
  const _AppName({this.kind, this.deviceName, this.packageName});

  final String? kind;
  final String? deviceName;
  final String? packageName;
}
