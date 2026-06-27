import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/download_progress.dart';
import '../services/downloader_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _downloaderService = DownloaderService();

  DownloadFormat _selectedFormat = DownloadFormat.mp4_1080p;
  String? _outputDir;

  DownloadProgress _progress = DownloadProgress(status: DownloadStatus.idle);
  bool get _isDownloading => _progress.status == DownloadStatus.downloading ||
      _progress.status == DownloadStatus.merging;

  bool _isUpdating = false;
  String? _ytDlpVersion;


  @override
  void initState() {
    super.initState();
    _setDefaultOutputDir();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await DownloaderServiceUpdate.getCurrentVersion();
    if (mounted) setState(() => _ytDlpVersion = version);
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);

    final result = await DownloaderServiceUpdate.checkAndUpdate();

    if (!mounted) return;
    setState(() => _isUpdating = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    if (result.success && !result.alreadyLatest) {
      await _loadVersion(); // refresh version label
    }
  }

  Future<void> _setDefaultOutputDir() async {
    final dir = await getDownloadsDirectory();
    setState(() => _outputDir = dir?.path);
  }

  Future<void> _pickOutputDir() async {
    final result = await FilePicker.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDir = result);
    }
  }

  void _startDownload() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('សូមបញ្ចូល URL សិន');
      return;
    }
    if (_outputDir == null) {
      _showError('សូមជ្រើស Folder សម្រាប់ Save ឯកសារ');
      return;
    }

    setState(() {
      _progress = DownloadProgress(status: DownloadStatus.downloading);
    });

    _downloaderService
        .download(url: url, format: _selectedFormat, outputDir: _outputDir!)
        .listen(
          (progress) {
            if (!mounted) return;
            setState(() => _progress = progress);
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _progress = DownloadProgress(
                  status: DownloadStatus.error,
                  errorMessage: e.toString(),
                ));
          },
        );
  }

  void _cancelDownload() {
    _downloaderService.cancel();
    setState(() {
      _progress = DownloadProgress(status: DownloadStatus.idle);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: const Text('Video / Mp3 Downloader', style: TextStyle(color: Colors.white),),
        actions: [
          if (_ytDlpVersion != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  'yt-dlp $_ytDlpVersion',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14
                  )
                ),
              ),
            ),
          IconButton(
            style: IconButton.styleFrom(
              foregroundColor: Colors.white,
              padding: EdgeInsets.only(right: 12)
            ),
            icon: _isUpdating
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, size: 24,),
            tooltip: 'Update yt-dlp',
            onPressed: _isUpdating ? null : _handleUpdate,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- URL Input ---
                TextField(
                  controller: _urlController,
                  enabled: !_isDownloading,
                  decoration: const InputDecoration(
                    labelText: 'Video URL',
                    hintText: 'https://youtube.com/watch?v=...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  
                ),
                const SizedBox(height: 16),

                // --- Format Dropdown ---
                DropdownButtonFormField<DownloadFormat>(
                  initialValue: _selectedFormat,
                  decoration: const InputDecoration(
                    labelText: 'Format',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: DownloadFormat.mp4_1080p,
                      child: Text('MP4 - 1080p'),
                    ),
                    DropdownMenuItem(
                      value: DownloadFormat.mp4_720p,
                      child: Text('MP4 - 720p'),
                    ),
                    DropdownMenuItem(
                      value: DownloadFormat.mp3,
                      child: Text('MP3 (Audio Only)'),
                    ),
                  ],
                  onChanged: _isDownloading
                      ? null
                      : (value) => setState(() => _selectedFormat = value!),
                ),
                const SizedBox(height: 16),

                // --- Output Folder Picker ---
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _outputDir ?? 'Unselect Folder',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isDownloading ? null : _pickOutputDir,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select Folder'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Download / Cancel Button ---
                SizedBox(
                  height: 48,
                  child: _isDownloading
                      ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:  Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent)
                          ),
                          onPressed: _cancelDownload,
                          icon: const Icon(Icons.stop, size: 26,),
                          label: const Text('Cancel', style: TextStyle(fontSize: 16)),
                        )
                      : ElevatedButton.icon(
                          onPressed: _startDownload,
                          icon: const Icon(Icons.download, size: 26,),
                          label: const Text('Download',style: TextStyle(fontSize: 16),),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor:  Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                // --- Progress Section ---
                _buildProgressSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    switch (_progress.status) {
      case DownloadStatus.idle:
        return const SizedBox.shrink();

      case DownloadStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress.percent / 100,
                minHeight: 12,
                borderRadius: BorderRadius.circular(8),
                color: Colors.blueAccent,
                backgroundColor: Colors.blueAccent.shade100,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_progress.percent.toStringAsFixed(1)}%'),
                if (_progress.speed.isNotEmpty)
                  Text('${_progress.speed}  •  ETA ${_progress.eta}'),
              ],
            ),
          ],
        );

      case DownloadStatus.merging:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 12,
                borderRadius: BorderRadius.circular(8),
                color: Colors.blueAccent,
                backgroundColor: Colors.blueAccent.shade100,
              ),
            ),
            const SizedBox(height: 8),
            const Text('កំពុង Merge Video និង Audio...'),
          ],
        );

      // *** ករណីថ្មី ***
      case DownloadStatus.extracting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              minHeight: 12,
              borderRadius: BorderRadius.circular(8),
              color: Colors.blueAccent,
              backgroundColor: Colors.blueAccent.shade100,
            ), // indeterminate
            SizedBox(height: 8),
            Text('កំពុង Extract Audio ទៅ MP3...'),
          ],
        );

      case DownloadStatus.completed:
        return Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Download Successfully!'),
          ],
        );

      case DownloadStatus.error:
        return Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _progress.errorMessage ?? 'មានបញ្ហាកើតឡើង',
                style: const TextStyle(color: Colors.red),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    }
  }
}