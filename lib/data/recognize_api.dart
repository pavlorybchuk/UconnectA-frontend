import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../auth/api_client.dart';
import 'api.dart';

/// Handles photo-recognition API calls.
///
/// Workflow:
///   1. Compress the captured image into a ZIP archive in the temp directory.
///   2. POST the ZIP as `multipart/form-data` to [Api.recognizePhoto].
///   3. Return the decoded JSON response.
///   4. Clean up the temporary ZIP file.
class RecognizeApi {
  final ApiClient _client;

  RecognizeApi(this._client);

  /// Zips [photoFile] and uploads it to the server.
  ///
  /// Throws an [Exception] with a human-readable message on failure.
  Future<Map<String, dynamic>> recognizePhoto(File photoFile) async {
    File? zipFile;

    try {
      // ── 1. Build ZIP in temp dir ─────────────────────────────────────
      zipFile = await _buildZip(photoFile);

      // ── 2. Multipart POST ────────────────────────────────────────────
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          zipFile.path,
          filename: p.basename(zipFile.path),
        ),
      });

      final response = await _client.postFormData(
        Api.recognizePhoto,
        data: formData,
      );

      final body = response.data;
      if (body is Map<String, dynamic>) return body;
      if (body is Map) return Map<String, dynamic>.from(body);

      // Server returned a non-map (e.g. plain string success message).
      return {'raw': body};
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      throw Exception('[$status] $msg');
    } finally {
      // ── 3. Clean up temp ZIP ─────────────────────────────────────────
      try {
        zipFile?.deleteSync();
      } catch (_) {}
    }
  }

  /// Creates a ZIP archive containing [source] and returns the [File].
  ///
  /// Runs in an isolate so the UI thread stays responsive.
  Future<File> _buildZip(File source) async {
    final tempDir = await getTemporaryDirectory();
    final zipPath = p.join(
      tempDir.path,
      'photo_${DateTime.now().millisecondsSinceEpoch}.zip',
    );

    await compute(_writeZip, _ZipArgs(source.path, zipPath));
    return File(zipPath);
  }
}

// ── Isolate helpers ──────────────────────────────────────────────────────────

class _ZipArgs {
  final String sourcePath;
  final String zipPath;
  const _ZipArgs(this.sourcePath, this.zipPath);
}

/// Top-level function required by [compute].
void _writeZip(_ZipArgs args) {
  final encoder = ZipFileEncoder();
  encoder.create(args.zipPath);
  encoder.addFile(File(args.sourcePath));
  encoder.close();
}
