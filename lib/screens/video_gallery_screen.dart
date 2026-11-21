import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'video_player_screen.dart';
import '../l10n/app_localizations.dart';

class VideoGalleryScreen extends StatefulWidget {
  const VideoGalleryScreen({super.key});

  @override
  State<VideoGalleryScreen> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen> {
  List<FileSystemEntity> _videos = [];
  // One thumbnail future per file. Creating the future inside build() made
  // every rebuild re-extract every thumbnail (B31).
  final Map<String, Future<String?>> _thumbnailFutures = {};

  Future<String?> _thumbnailFor(String path) =>
      _thumbnailFutures.putIfAbsent(path, () => _generateThumbnail(path));
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');
      
      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync()
          .where((file) => file.path.endsWith('.mp4') || file.path.endsWith('.gif'))
          .toList();
        
        // Sort by date (newest first)
        files.sort((a, b) {
          return b.statSync().modified.compareTo(a.statSync().modified);
        });

        if (!mounted) return;
        setState(() {
          _videos = files;
        });
      }
    } catch (e) {
      debugPrint('Error loading videos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _generateThumbnail(String path) async {
    if (path.endsWith('.gif')) {
      return path; // Use the GIF itself as thumbnail
    }
    try {
      final fileName = await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 200,
        quality: 75,
      );
      return fileName;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('d MMM HH:mm').format(date);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _deleteVideo(FileSystemEntity file) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (await file.exists()) {
        await file.delete();
        _thumbnailFutures.remove(file.path);
        if (!mounted) return;
        setState(() {
          _videos.remove(file);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.recordingDeleted)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting video: $e');
    }
  }

  Future<void> _shareVideo(String path) async {
    final l10n = AppLocalizations.of(context);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: '${l10n.appTitle} ${l10n.recordings}'),
      );
    } catch (e) {
      debugPrint('Error sharing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recordings),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.amber.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.videoPlaybackHint,
                    style: TextStyle(fontSize: 12, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _videos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off_outlined, size: 64, color: scheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noRecordsFound,
                              style: TextStyle(color: scheme.outline, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final file = _videos[index];
                    final stat = file.statSync();
                    final isGif = file.path.endsWith('.gif');

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(videoPath: file.path),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  FutureBuilder<String?>(
                                    future: _thumbnailFor(file.path),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Container(
                                          color: Colors.black12,
                                          child: const Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return Image.file(
                                          File(snapshot.data!),
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => const Icon(Icons.error),
                                        );
                                      }
                                      return Container(
                                        color: Colors.black12,
                                        child: const Icon(Icons.broken_image),
                                      );
                                    },
                                  ),
                                  if (!isGif)
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white70,
                                        size: 48,
                                      ),
                                    ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _shareVideo(file.path),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.share,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _deleteVideo(file),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: scheme.surfaceContainerHighest,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDate(stat.modified),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      Text(
                                        _formatSize(stat.size),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    isGif ? l10n.gifAnimation : l10n.videoRecording,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
