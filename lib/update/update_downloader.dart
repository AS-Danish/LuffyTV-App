import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'update_manifest.dart';

class UpdateDownloadProgress {
  final int bytesDownloaded;
  final int totalBytes;
  final double bytesPerSecond;
  const UpdateDownloadProgress(
    this.bytesDownloaded,
    this.totalBytes,
    this.bytesPerSecond,
  );
}

class UpdateDownloadException implements Exception {
  final String message;
  final bool noSpace;
  const UpdateDownloadException(this.message, {this.noSpace = false});
  @override
  String toString() => message;
}

class UpdateDownloader {
  http.Client? _activeClient;
  bool _cancelled = false;

  Future<Directory> updateDirectory() async {
    final cache = await getTemporaryDirectory();
    final directory = Directory('${cache.path}/update');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> partFile(UpdateManifest manifest) async => File(
    '${(await updateDirectory()).path}/luffy_tv_update_${manifest.versionCode}.apk.part',
  );

  Future<File> apkFile(UpdateManifest manifest) async => File(
    '${(await updateDirectory()).path}/luffy_tv_update_${manifest.versionCode}.apk',
  );

  Future<void> cleanup({int? keepVersionCode}) async {
    final directory = await updateDirectory();
    final now = DateTime.now();
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final keep =
          keepVersionCode != null &&
          entity.path.contains('update_$keepVersionCode.apk');
      final stale =
          now.difference(await entity.lastModified()) > const Duration(days: 3);
      if (!keep && (keepVersionCode != null || stale)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<String> download(
    UpdateManifest manifest,
    void Function(UpdateDownloadProgress progress) onProgress,
  ) async {
    if (_activeClient != null) {
      throw const UpdateDownloadException(
        'An update download is already running.',
      );
    }
    _cancelled = false;
    final part = await partFile(manifest);
    final metadata = File('${part.path}.json');
    var existingBytes = 0;
    if (await part.exists() && await _metadataMatches(metadata, manifest)) {
      existingBytes = await part.length();
      if (manifest.apkSize != null && existingBytes > manifest.apkSize!) {
        await part.delete();
        existingBytes = 0;
      }
    } else {
      if (await part.exists()) await part.delete();
      if (await metadata.exists()) await metadata.delete();
    }

    await metadata.writeAsString(
      jsonEncode({
        'versionCode': manifest.versionCode,
        'url': manifest.apkUrl.toString(),
        'sha256': manifest.sha256,
        'apkSize': manifest.apkSize,
      }),
      flush: true,
    );
    if (manifest.apkSize != null && existingBytes == manifest.apkSize) {
      return part.path;
    }

    final client = http.Client();
    _activeClient = client;
    IOSink? sink;
    try {
      final request = http.Request('GET', manifest.apkUrl)
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers['Accept'] =
            'application/vnd.android.package-archive, application/octet-stream';
      if (existingBytes > 0) request.headers['Range'] = 'bytes=$existingBytes-';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final finalUri = response.request?.url ?? manifest.apkUrl;
      if (finalUri.scheme != 'https') {
        throw const UpdateDownloadException(
          'The APK redirected to an insecure URL.',
        );
      }
      if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        await part.delete();
        await metadata.delete();
        throw const UpdateDownloadException(
          'The server rejected the saved partial download. Please retry.',
        );
      }
      final resumed =
          response.statusCode == HttpStatus.partialContent &&
          existingBytes > 0 &&
          (response.headers['content-range'] ?? '').startsWith(
            'bytes $existingBytes-',
          );
      if (response.statusCode != HttpStatus.ok && !resumed) {
        throw UpdateDownloadException(
          'APK download returned HTTP ${response.statusCode}.',
        );
      }
      if (!resumed) existingBytes = 0;
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.contains('text/html') ||
          contentType.contains('application/json')) {
        throw UpdateDownloadException(
          'The APK URL returned $contentType instead of an APK.',
        );
      }

      final responseLength = response.contentLength ?? 0;
      final total =
          manifest.apkSize ??
          (responseLength > 0 ? existingBytes + responseLength : 0);
      sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      var downloaded = existingBytes;
      var windowBytes = 0;
      var lastUpdate = DateTime.now();
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (_cancelled) {
          throw const UpdateDownloadException('Download cancelled.');
        }
        sink.add(chunk);
        downloaded += chunk.length;
        windowBytes += chunk.length;
        final now = DateTime.now();
        final elapsed = now.difference(lastUpdate);
        if (elapsed >= const Duration(milliseconds: 250)) {
          onProgress(
            UpdateDownloadProgress(
              downloaded,
              total,
              windowBytes / (elapsed.inMilliseconds / 1000),
            ),
          );
          windowBytes = 0;
          lastUpdate = now;
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      onProgress(UpdateDownloadProgress(downloaded, total, 0));
      return part.path;
    } on FileSystemException catch (error) {
      throw UpdateDownloadException(
        error.message,
        noSpace:
            error.osError?.errorCode == 28 ||
            error.message.toLowerCase().contains('space'),
      );
    } finally {
      await sink?.close();
      client.close();
      _activeClient = null;
    }
  }

  Future<bool> _metadataMatches(File file, UpdateManifest manifest) async {
    if (!await file.exists()) return false;
    try {
      final raw = jsonDecode(await file.readAsString());
      return raw is Map &&
          raw['versionCode'] == manifest.versionCode &&
          raw['url'] == manifest.apkUrl.toString() &&
          raw['sha256'] == manifest.sha256 &&
          raw['apkSize'] == manifest.apkSize;
    } catch (_) {
      return false;
    }
  }

  void cancel() {
    _cancelled = true;
    _activeClient?.close();
  }

  Future<String> promoteVerified(
    UpdateManifest manifest,
    String partPath,
  ) async {
    final part = File(partPath);
    final apk = await apkFile(manifest);
    if (await apk.exists()) await apk.delete();
    final promoted = await part.rename(apk.path);
    final metadata = File('$partPath.json');
    if (await metadata.exists()) await metadata.delete();
    return promoted.path;
  }
}
