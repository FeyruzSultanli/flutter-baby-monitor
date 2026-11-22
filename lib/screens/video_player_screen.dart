import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../l10n/app_localizations.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;

  const VideoPlayerScreen({super.key, required this.videoPath});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // Nullable: stays null if the file is missing/empty, so dispose() must not
  // touch an uninitialized late field (B30).
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isGif = false;
  String? _errorMessage;

  bool _isPlayerInitialized = false;

  @override
  void initState() {
    super.initState();
    _isGif = widget.videoPath.endsWith('.gif');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isGif && !_isPlayerInitialized) {
      _isPlayerInitialized = true;
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = File(widget.videoPath);
      if (!await file.exists()) {
        throw Exception("${l10n.videoFileNotFound}: ${widget.videoPath}");
      }
      final len = await file.length();
      debugPrint("Video file size: $len bytes, path: ${widget.videoPath}");
      if (len == 0) {
        throw Exception(l10n.videoFileEmpty);
      }

      final controller = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoPlayerController = controller;
      
      // Initialize with a timeout to prevent hanging
      await controller.initialize().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception(l10n.videoInitTimeout);
        },
      );
      
      // The screen may have been closed while the player was initializing.
      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        aspectRatio: controller.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          debugPrint('Video playback error: $errorMessage');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                AppLocalizations.of(context).videoPlaybackError,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint("Video initialization error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    if (!_isGif) {
      _chewieController?.dispose();
      _videoPlayerController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.videoPlayer),
      ),
      body: Center(
        child: _errorMessage != null
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.videoPlaybackError,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.errUnknown,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : _isGif
                ? Image.file(File(widget.videoPath))
                : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                    ? Chewie(controller: _chewieController!)
                    : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
