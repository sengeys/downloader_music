// lib/utils/binary_path.dart (កែប្រែ)
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BinaryPath {
  static String? _cachedYtDlp;
  static String? _cachedFfmpeg;


  /// ត្រូវហៅ method នេះតែម្តងនៅពេល app ចាប់ផ្តើម (main.dart)
  /// វានឹង copy binaries ពី assets ទៅ Application Support folder
  /// បើមិនទាន់មាន (first run only)
  static Future<void> ensureBinariesReady() async {
    final supportDir = await getApplicationSupportDirectory();
    final binDir = Directory(p.join(supportDir.path, 'bin'));
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    final ytDlpName = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
    final ffmpegName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';

    _cachedYtDlp = p.join(binDir.path, ytDlpName);
    _cachedFfmpeg = p.join(binDir.path, ffmpegName);

    // Copy ពី bundled assets ទៅ writable folder ករណីមិនទាន់មាន
    await _copyIfMissing(_cachedYtDlp!, _assetPathFor(ytDlpName));
    await _copyIfMissing(_cachedFfmpeg!, _assetPathFor(ffmpegName));

    // ត្រូវប្រាកដថា executable (សំខាន់សម្រាប់ macOS/Linux)
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', _cachedYtDlp!]);
      await Process.run('chmod', ['+x', _cachedFfmpeg!]);
    }
  }

  static String _assetPathFor(String fileName) {
    final folder = Platform.isWindows ? 'windows' : 'macos';
    if (kDebugMode) {
      return p.join(Directory.current.path, 'assets', 'bin', folder, fileName);
    }
    final exeDir = p.dirname(Platform.resolvedExecutable);
    if (Platform.isWindows) {
      return p.join(exeDir, 'data', 'flutter_assets', 'assets', 'bin', folder, fileName);
    }
    return p.join(exeDir, '..', 'Frameworks', 'App.framework', 'Resources',
        'flutter_assets', 'assets', 'bin', folder, fileName);
  }

  static Future<void> _copyIfMissing(String destPath, String sourcePath) async {
    final destFile = File(destPath);
    if (!await destFile.exists()) {
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);
    }
  }

  static String getYtDlpPath() {
    if (_cachedYtDlp == null) {
      throw StateError('ត្រូវហៅ ensureBinariesReady() មុននឹងប្រើ getYtDlpPath()');
    }
    return _cachedYtDlp!;
  }

  static String getFfmpegPath() {
    if (_cachedFfmpeg == null) {
      throw StateError('ត្រូវហៅ ensureBinariesReady() មុននឹងប្រើ getFfmpegPath()');
    }
    return _cachedFfmpeg!;
  }
}