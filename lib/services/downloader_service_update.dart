import 'dart:io';

import 'package:downloader_music/services/downloader_service.dart';
import 'package:downloader_music/utils/binary_path.dart';


// lib/services/downloader_service.dart (បន្ថែមនៅក្នុង class DownloaderService)
class UpdateResult {
  final bool success;
  final bool alreadyLatest;
  final String message;
  final String? newVersion;

  UpdateResult({
    required this.success,
    this.alreadyLatest = false,
    required this.message,
    this.newVersion,
  });
}

extension DownloaderServiceUpdate on DownloaderService {
  /// Run "yt-dlp -U" ដើម្បី self-update binary
  static Future<UpdateResult> checkAndUpdate() async {
    try {
      final ytDlpPath = BinaryPath.getYtDlpPath();

      final result = await Process.run(ytDlpPath, ['-U']);
      // ប្រើ Process.run() (មិនមែន start) ត្រង់នេះព្រោះ
      // ការ update ចំណាយពេលតែប៉ុន្មានវិនាទី មិនមែន long-running task
      // ដូច្នេះមិនចាំបាច់ stream progress ដូច download

      final output = '${result.stdout}\n${result.stderr}'.trim();

      if (result.exitCode != 0) {
        return UpdateResult(
          success: false,
          message: 'Update បរាជ័យ: $output',
        );
      }

      if (output.contains('is up to date') ||
          output.contains('yt-dlp is up to date')) {
        return UpdateResult(
          success: true,
          alreadyLatest: true,
          message: 'yt-dlp ជា version ថ្មីបំផុតរួចហើយ',
        );
      }

      if (output.contains('Updated yt-dlp')) {
        // ព្យាយាមទាញយក version ថ្មីចេញពី output
        final versionMatch =
            RegExp(r'to\s+(?:version\s+)?([\d.]+)').firstMatch(output);
        return UpdateResult(
          success: true,
          alreadyLatest: false,
          message: 'Update ជោគជ័យ',
          newVersion: versionMatch?.group(1),
        );
      }

      // ករណីផ្សេងៗដែលមិនច្បាស់ — ចាត់ទុកថា success ព្រោះ exit code 0
      return UpdateResult(success: true, message: output);
    } catch (e) {
      return UpdateResult(
        success: false,
        message: 'មិនអាច run update បានទេ: $e',
      );
    }
  }

  /// ពិនិត្យមើល version បច្ចុប្បន្នរបស់ yt-dlp (សម្រាប់បង្ហាញនៅ UI)
  static Future<String?> getCurrentVersion() async {
    try {
      final ytDlpPath = BinaryPath.getYtDlpPath();
      final result = await Process.run(ytDlpPath, ['--version']);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return null;
  }
}