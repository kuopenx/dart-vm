import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'vm_service_uri.dart';

/// Generic client for calling a Dart VM Service isolate extension.
class ServiceExtensionClient {
  ServiceExtensionClient._(this._service, this._isolateId);

  final VmService _service;
  final String _isolateId;

  static Future<ServiceExtensionClient> connect(
    String uri, {
    required String extension,
    String? isolate,
  }) async {
    final service = await vmServiceConnectUri(normalizeVmServiceUri(uri));
    try {
      final vm = await service.getVM();
      final isolateId = await _resolveIsolateId(
        service,
        vm,
        extension,
        isolate,
      );
      return ServiceExtensionClient._(service, isolateId);
    } catch (_) {
      await service.dispose();
      rethrow;
    }
  }

  String get isolateId => _isolateId;

  Future<Object?> call(String extension, Map<String, String> parameters) async {
    final response = await _service.callServiceExtension(
      extension,
      isolateId: _isolateId,
      args: parameters,
    );
    final result = response.json;
    if (result == null) {
      return null;
    }
    return result;
  }

  Future<void> dispose() => _service.dispose();

  static Future<String> _resolveIsolateId(
    VmService service,
    VM vm,
    String extension,
    String? selector,
  ) async {
    final isolates = vm.isolates ?? const <IsolateRef>[];
    IsolateRef? selected;

    if (selector != null && selector.isNotEmpty) {
      for (final isolate in isolates) {
        if (isolate.id == selector || isolate.name == selector) {
          selected = isolate;
          break;
        }
      }
      if (selected?.id == null) {
        throw StateError('No isolate matches "$selector".');
      }
    } else {
      for (final isolate in isolates) {
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
    }

    final id = selected?.id;
    if (id == null) {
      throw StateError(
        'No non-system isolate is available from this VM Service.',
      );
    }

    final detail = await service.getIsolate(id);
    if (!(detail.extensionRPCs ?? const <String>[]).contains(extension)) {
      throw StateError(
        'Extension "$extension" is unavailable in isolate ${detail.name ?? id}.',
      );
    }
    return id;
  }
}
