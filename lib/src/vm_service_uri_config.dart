import 'dart:convert';
import 'dart:io';

import 'vm_service_uri.dart';

/// Persists the last VM Service URI selected by the local developer.
class VmServiceUriConfigStore {
  VmServiceUriConfigStore({String? filePath})
    : _file = File(filePath ?? defaultFilePath);

  final File _file;

  static String get defaultFilePath {
    final environment = Platform.environment;
    final configRoot = Platform.isWindows
        ? environment['APPDATA']
        : environment['XDG_CONFIG_HOME'] ??
              _join(environment['HOME'], '.config');
    if (configRoot == null || configRoot.isEmpty) {
      throw StateError('Cannot determine a local configuration directory.');
    }
    return _join(configRoot, 'dart-vm', 'config.json');
  }

  String get filePath => _file.path;

  Future<String?> read() async {
    if (!await _file.exists()) {
      return null;
    }
    final raw = await _file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['uri'] is! String) {
      throw StateError('Saved VM Service configuration is invalid.');
    }
    return decoded['uri'] as String;
  }

  Future<void> write(String uri) async {
    normalizeVmServiceUri(uri);
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode(<String, String>{'uri': uri}),
      flush: true,
    );
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>['600', _file.path]);
    }
  }

  Future<bool> clear() async {
    if (!await _file.exists()) {
      return false;
    }
    await _file.delete();
    return true;
  }

  static String _join(String? first, [String? second, String? third]) {
    if (first == null || first.isEmpty) {
      return '';
    }
    final parts = <String>[first];
    if (second != null && second.isNotEmpty) parts.add(second);
    if (third != null && third.isNotEmpty) parts.add(third);
    return parts.join(Platform.pathSeparator);
  }
}
