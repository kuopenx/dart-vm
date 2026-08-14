import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'vm_service_uri.dart';

class NetworkProfileClient {
  NetworkProfileClient._(this._service);

  final VmService _service;
  String? _isolateId;

  static Future<NetworkProfileClient> connect(String uri) async {
    final service = await vmServiceConnectUri(normalizeVmServiceUri(uri));
    return NetworkProfileClient._(service);
  }

  Future<String> get isolateId async {
    if (_isolateId case final isolateId?) {
      return isolateId;
    }

    final vm = await _service.getVM();
    IsolateRef? selected;
    for (final isolate in vm.isolates ?? const <IsolateRef>[]) {
      if (isolate.name == 'main' && isolate.id != null) {
        selected = isolate;
        break;
      }
      if (selected == null &&
          isolate.isSystemIsolate != true &&
          isolate.id != null) {
        selected = isolate;
      }
    }

    final selectedId = selected?.id;
    if (selectedId == null) {
      throw StateError(
        'No non-system isolate is available from this VM Service.',
      );
    }

    final isolate = await _service.getIsolate(selectedId);
    if (!(isolate.extensionRPCs ?? const <String>[]).contains(
      'ext.dart.io.getHttpProfile',
    )) {
      throw StateError(
        'HTTP profiling is unavailable in isolate ${isolate.name ?? selectedId}.',
      );
    }
    return _isolateId = selectedId;
  }

  Future<HttpTimelineLoggingState> loggingState([bool? enabled]) async {
    return _service.httpEnableTimelineLogging(await isolateId, enabled);
  }

  Future<HttpProfile> requests() async {
    return _service.getHttpProfile(await isolateId);
  }

  Future<HttpProfileRequest> request(String id) async {
    return _service.getHttpProfileRequest(await isolateId, id);
  }

  Future<void> dispose() => _service.dispose();
}

class InspectorClient {
  InspectorClient._(this._service);
  final VmService _service;
  String? _isolateId;
  static const _group = 'dart-vm';

  static Future<InspectorClient> connect(String uri) async =>
      InspectorClient._(await vmServiceConnectUri(normalizeVmServiceUri(uri)));

  Future<String> get isolateId async {
    if (_isolateId case final id?) return id;
    final vm = await _service.getVM();
    final id = (vm.isolates ?? const <IsolateRef>[])
        .where((isolate) => isolate.name == 'main' && isolate.id != null)
        .firstOrNull
        ?.id;
    if (id == null) throw StateError('No main isolate is available.');
    final isolate = await _service.getIsolate(id);
    if (!(isolate.extensionRPCs ?? const <String>[]).contains(
      'ext.flutter.inspector.isWidgetTreeReady',
    )) {
      throw StateError(
        'This App does not provide Flutter Inspector extensions.',
      );
    }
    return _isolateId = id;
  }

  Future<dynamic> call(
    String method, [
    Map<String, dynamic> args = const {},
  ]) async {
    final response = await _service.callServiceExtension(
      'ext.flutter.inspector.$method',
      isolateId: await isolateId,
      args: {'objectGroup': _group, ...args},
    );
    final result = response.json?['result'];
    if (result is! String) return result;
    try {
      return jsonDecode(result);
    } on FormatException {
      return result;
    }
  }

  Future<void> dispose() => _service.dispose();
}

Map<String, Object?> summarizeRequest(HttpProfileRequestRef request) {
  final endTime = request.endTime;
  final durationUs = endTime?.difference(request.startTime).inMicroseconds;
  return {
    'id': request.id,
    'method': request.method,
    'uri': request.uri.toString(),
    'statusCode': request.response?.statusCode,
    'startTime': request.startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'durationUs': durationUs,
    'durationMs': durationUs == null
        ? null
        : durationUs / Duration.microsecondsPerMillisecond,
    'complete': request.isResponseComplete,
  };
}

Map<String, Object?> describeRequest(
  HttpProfileRequest request, {
  required bool body,
}) {
  return {
    ...summarizeRequest(request),
    'requestBytes': request.requestBody?.length ?? 0,
    'responseBytes': request.responseBody?.length ?? 0,
    'requestError': request.request?.error,
    'responseError': request.response?.error,
    if (body) ...{
      'requestBody': _decodeUtf8(request.requestBody),
      'responseBody': _decodeUtf8(request.responseBody),
    },
  };
}

String _decodeUtf8(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) {
    return '';
  }
  return utf8.decode(bytes, allowMalformed: true);
}
