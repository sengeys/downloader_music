// lib/services/downloader_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/download_progress.dart';
import '../utils/binary_path.dart';

enum DownloadFormat { mp4_1080p, mp4_720p, mp3 }

class DownloaderService {
  Process? _currentProcess;

  // RegEx សម្រាប់ចាប់ព័ត៌មានពី log line របស់ yt-dlp
  // ឧទាហរណ៍បន្ទាត់ដើម: "[download]  25.0% of 10.00MiB at 3.20MiB/s ETA 00:12"
  static final RegExp _progressRegex = RegExp(
    r'\[download\]\s+(\d+\.?\d*)%\s+of\s+[\d.]+\w+\s+at\s+([\d.]+\w+/s)\s+ETA\s+([\d:]+)',
  );

  // Pattern សម្រាប់ករណីដែលគ្មាន speed/eta (ដូចជានៅដើម ឬចុង download)
  static final RegExp _percentOnlyRegex = RegExp(r'\[download\]\s+(\d+\.?\d*)%');

  // បន្ថែម RegEx ថ្មី
  static final RegExp _extractAudioRegex = RegExp(r'\[(ExtractAudio|ffmpeg)\]');

  // កែ _mergingRegex ឲ្យកាន់តែច្បាស់ (មិនច្របូកច្របល់ជាមួយ ExtractAudio)
  static final RegExp _mergingRegex = RegExp(r'\[Merger\]');

  /// ចាប់ផ្តើម Download — ត្រឡប់ Stream ដែលបញ្ចេញ DownloadProgress ជានិច្ច
  Stream<DownloadProgress> download({
    required String url,
    required DownloadFormat format,
    required String outputDir,
  }) {
    final controller = StreamController<DownloadProgress>();
    _runDownload(url, format, outputDir, controller);
    return controller.stream;
  }

  Future<void> _runDownload(
    String url,
    DownloadFormat format,
    String outputDir,
    StreamController<DownloadProgress> controller,
  ) async {
    try {
      final ytDlpPath = BinaryPath.getYtDlpPath();
      final ffmpegPath = BinaryPath.getFfmpegPath();

      final args = _buildArgs(url, format, outputDir, ffmpegPath);

      controller.add(DownloadProgress(status: DownloadStatus.downloading));

      // *** សំខាន់បំផុត: Process.start() ជា async, មិន freeze UI ***
      _currentProcess = await Process.start(ytDlpPath, args);

      // Listen stdout (កន្លែង yt-dlp print progress)
      _currentProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _parseLine(line, controller));

      // Listen stderr (កន្លែង error ច្រើនកើតមាន)
      final stderrBuffer = StringBuffer();
      _currentProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => stderrBuffer.writeln(line));

      final exitCode = await _currentProcess!.exitCode;

      if (exitCode == 0) {
        controller.add(DownloadProgress(
          status: DownloadStatus.completed,
          percent: 100.0,
        ));
      } else {
        controller.add(DownloadProgress(
          status: DownloadStatus.error,
          errorMessage: stderrBuffer.isNotEmpty
              ? stderrBuffer.toString()
              : 'yt-dlp បានបញ្ចប់ដោយ exit code $exitCode',
        ));
      }

      await controller.close();
    } catch (e) {
      controller.add(DownloadProgress(
        status: DownloadStatus.error,
        errorMessage: e.toString(),
      ));
      await controller.close();
    }
  }

  void _parseLine(String line, StreamController<DownloadProgress> controller) {
  // ករណី១: Merging video+audio (សម្រាប់ MP4 ប៉ុណ្ណោះ)
  if (_mergingRegex.hasMatch(line)) {
    controller.add(DownloadProgress(
      status: DownloadStatus.merging,
      percent: 99.0,
      rawLine: line,
    ));
    return;
  }

  // ករណី២: កំពុង Extract Audio ទៅ MP3 (សម្រាប់ MP3 ប៉ុណ្ណោះ)
  if (_extractAudioRegex.hasMatch(line)) {
    controller.add(DownloadProgress(
      status: DownloadStatus.extracting,
      percent: 99.0,
      rawLine: line,
    ));
    return;
  }

  // ករណី៣: មាន full progress info (% + speed + ETA) — ដំណាក់កាល download ដើម
  final fullMatch = _progressRegex.firstMatch(line);
  if (fullMatch != null) {
    controller.add(DownloadProgress(
      status: DownloadStatus.downloading,
      percent: double.tryParse(fullMatch.group(1)!) ?? 0.0,
      speed: fullMatch.group(2)!,
      eta: fullMatch.group(3)!,
      rawLine: line,
    ));
    return;
  }

  // ករណី៤: មានតែ % (គ្មាន speed/eta)
  final percentMatch = _percentOnlyRegex.firstMatch(line);
  if (percentMatch != null) {
    controller.add(DownloadProgress(
      status: DownloadStatus.downloading,
      percent: double.tryParse(percentMatch.group(1)!) ?? 0.0,
      rawLine: line,
    ));
  }
}

  List<String> _buildArgs(
  String url,
  DownloadFormat format,
  String outputDir,
  String ffmpegPath,
) {
  final outputTemplate = '$outputDir/%(title)s.%(ext)s';

  switch (format) {
    case DownloadFormat.mp3:
      return [
        '-x',
        '--audio-format', 'mp3',
        '--ffmpeg-location', ffmpegPath,
        '-o', outputTemplate,
        url,
      ];

    case DownloadFormat.mp4_1080p:
      return [
        '-f', 'bestvideo[height<=1080]+bestaudio/best[height<=1080]',
        '--merge-output-format', 'mp4',
        '--ffmpeg-location', ffmpegPath,
        '--postprocessor-args', 'ffmpeg:-c:v copy -c:a aac -b:a 192k',
        '-o', outputTemplate,
        url,
      ];

    case DownloadFormat.mp4_720p:
      return [
        '-f', 'bestvideo[height<=720]+bestaudio/best[height<=720]',
        '--merge-output-format', 'mp4',
        '--ffmpeg-location', ffmpegPath,
        '--postprocessor-args', 'ffmpeg:-c:v copy -c:a aac -b:a 192k',
        '-o', outputTemplate,
        url,
      ];
  }
}

  /// បោះបង់ download ដែលកំពុងដំណើរការ
  void cancel() {
    _currentProcess?.kill();
    _currentProcess = null;
  }
}


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