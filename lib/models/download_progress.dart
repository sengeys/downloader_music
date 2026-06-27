// lib/models/download_progress.dart
enum DownloadStatus { idle, downloading, merging, extracting, completed, error }

class DownloadProgress {
  final DownloadStatus status;
  final double percent;       // 0.0 - 100.0
  final String speed;         // e.g. "3.2MiB/s"
  final String eta;           // e.g. "00:12"
  final String? errorMessage;
  final String rawLine;       // log ដើមៗ សម្រាប់ debug

  DownloadProgress({
    required this.status,
    this.percent = 0.0,
    this.speed = '',
    this.eta = '',
    this.errorMessage,
    this.rawLine = '',
  });
}