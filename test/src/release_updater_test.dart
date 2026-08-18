import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dart_vm/dart_vm.dart';
import 'package:test/test.dart';

void main() {
  group('release version handling', () {
    test('normalizes release tags and compares semantic versions', () {
      expect(ReleaseUpdater.normalizeVersion('v0.3.0'), '0.3.0');
      expect(ReleaseUpdater.compareVersions('0.3.0', '0.2.9'), greaterThan(0));
      expect(ReleaseUpdater.compareVersions('0.2.0', 'v0.2.0'), 0);
      expect(ReleaseUpdater.compareVersions('0.1.9', '0.2.0'), lessThan(0));
    });

    test('rejects malformed release versions', () {
      expect(
        () => ReleaseUpdater.normalizeVersion('latest'),
        throwsFormatException,
      );
    });
  });

  group('release checksums', () {
    const hash =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('selects the checksum for the requested asset', () {
      expect(
        ReleaseUpdater.checksumForAsset(
          '$hash  dart-vm-darwin-arm64.zip\n',
          'dart-vm-darwin-arm64.zip',
        ),
        hash,
      );
    });

    test('rejects missing and invalid checksums', () {
      expect(
        () => ReleaseUpdater.checksumForAsset('', 'dart-vm.zip'),
        throwsFormatException,
      );
      expect(
        () => ReleaseUpdater.checksumForAsset(
          'invalid  dart-vm.zip',
          'dart-vm.zip',
        ),
        throwsFormatException,
      );
    });
  });

  test('refuses to replace the Dart SDK executable', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'tag_name': 'v0.3.0'}));
      await request.response.close();
    });
    final base = Uri.parse('http://127.0.0.1:${server.port}/');
    final updater = ReleaseUpdater(
      currentVersion: '0.2.0',
      latestReleaseUri: base,
      releaseDownloadBaseUri: base,
      executablePath: Platform.resolvedExecutable,
      assetName: 'dart-vm-test.zip',
    );

    await expectLater(
      updater.upgrade(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('compiled'),
        ),
      ),
    );
  });

  test('downloads, verifies, extracts, and replaces the executable', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dart-vm-updater-test-',
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });

    final sourceDirectory = Directory('${directory.path}/source')..createSync();
    final binaryName = Platform.isWindows ? 'dart-vm.exe' : 'dart-vm';
    final sourceBinary = File('${sourceDirectory.path}/$binaryName');
    await sourceBinary.writeAsString('new executable');
    final archive = File('${directory.path}/dart-vm-test.zip');
    final ProcessResult zip;
    if (Platform.isWindows) {
      final sourcePath = _powerShellLiteral(sourceBinary.path);
      final archivePath = _powerShellLiteral(archive.path);
      zip = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Compress-Archive -LiteralPath $sourcePath '
            '-DestinationPath $archivePath',
      ]);
    } else {
      zip = await Process.run('zip', [
        '-q',
        archive.path,
        binaryName,
      ], workingDirectory: sourceDirectory.path);
    }
    expect(zip.exitCode, 0, reason: zip.stderr.toString());

    final archiveBytes = await archive.readAsBytes();
    final checksum = sha256.convert(archiveBytes).toString();
    final target = File('${directory.path}/$binaryName');
    await target.writeAsString('old executable');

    server.listen((request) async {
      switch (request.uri.path) {
        case '/latest':
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'tag_name': 'v0.3.0'}));
        case '/download/v0.3.0/dart-vm-test.zip':
          request.response.add(archiveBytes);
        case '/download/v0.3.0/checksums.txt':
          request.response.write('$checksum  dart-vm-test.zip\n');
        default:
          request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final base = Uri.parse('http://127.0.0.1:${server.port}/');
    final updater = ReleaseUpdater(
      currentVersion: '0.2.0',
      latestReleaseUri: base.resolve('latest'),
      releaseDownloadBaseUri: base.resolve('download/'),
      executablePath: target.path,
      assetName: 'dart-vm-test.zip',
    );

    final result = await updater.upgrade();

    expect(result, {
      'updated': true,
      'previousVersion': '0.2.0',
      'version': '0.3.0',
    });
    expect(await target.readAsString(), 'new executable');
  });
}

String _powerShellLiteral(String value) => "'${value.replaceAll("'", "''")}'";
