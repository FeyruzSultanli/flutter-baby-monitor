import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;

class VideoRecorderService {
  // WebRTC Recorder
  MediaRecorder? _mediaRecorder;
  
  // Offline Recorder
  bool _isOfflineRecording = false;
  String? _offlineTempDir;
  int _frameCount = 0;

  // Common
  bool get isRecording => _mediaRecorder != null || _isOfflineRecording;

  /// Starts recording a WebRTC MediaStream.
  /// Returns the path where the video is being recorded.
  Future<String> startWebRTCRecording(MediaStream stream) async {
    if (isRecording) throw Exception("Already recording");

    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    
    final fileName = 'webrtc_rec_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final filePath = '${recordingsDir.path}/$fileName';

    _mediaRecorder = MediaRecorder();
    
    // Start recording
    // Note: flutter_webrtc MediaRecorder.start only takes videoTrack in this version.
    // Audio recording might depend on the platform implementation or require a different approach.
    // For now, we proceed with videoTrack only to ensure the app builds and records video.
    await _mediaRecorder!.start(
      filePath, 
      videoTrack: stream.getVideoTracks().first,
    );
    
    return filePath;
  }

  /// Stops WebRTC recording and saves to Gallery.
  Future<void> stopWebRTCRecording(String filePath) async {
    if (_mediaRecorder == null) return;

    await _mediaRecorder!.stop();
    _mediaRecorder = null;

    // Give it a moment to finalize the file write
    await Future.delayed(const Duration(milliseconds: 500));

    // Check file integrity
    final file = File(filePath);
    if (await file.exists()) {
       final len = await file.length();
       debugPrint("Recorded file size: $len bytes");
       if (len < 1024) {
         debugPrint("Warning: File is too small ($len bytes), might be empty or corrupt.");
       }
    } else {
      debugPrint("Error: Recorded file not found at $filePath");
    }

    // Save to Gallery
    await _saveToGallery(filePath, isVideo: true);
  }

  /// Starts offline recording (collecting frames).
  Future<void> startOfflineRecording() async {
    if (isRecording) throw Exception("Already recording");

    final tempDir = await getTemporaryDirectory();
    final dirName = 'offline_rec_${DateTime.now().millisecondsSinceEpoch}';
    _offlineTempDir = '${tempDir.path}/$dirName';
    await Directory(_offlineTempDir!).create();
    
    _frameCount = 0;
    _isOfflineRecording = true;
  }

  /// Adds a frame to the offline recording.
  Future<void> addOfflineFrame(Uint8List bytes) async {
    if (!_isOfflineRecording || _offlineTempDir == null) return;

    // Save every 3rd frame to reduce load and GIF size, or just save all.
    // Saving all for now.
    final framePath = '$_offlineTempDir/frame_${_frameCount.toString().padLeft(5, '0')}.jpg';
    final file = File(framePath);
    await file.writeAsBytes(bytes);
    _frameCount++;
  }

  /// Stops offline recording, creates a GIF, and saves to Gallery.
  Future<void> stopOfflineRecording() async {
    if (!_isOfflineRecording || _offlineTempDir == null) return;

    _isOfflineRecording = false;
    final tempDir = _offlineTempDir!;
    _offlineTempDir = null;

    if (_frameCount == 0) {
      // No frames recorded
      await Directory(tempDir).delete(recursive: true);
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDir.path}/recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    
    // Run GIF creation in background isolate
    // We pass the paths as strings, avoid passing complex objects
    final params = {
      'tempDir': tempDir,
      'outputDir': recordingsDir.path,
    };

    try {
      final outputPath = await compute(_createGifInIsolate, params);
      if (outputPath != null) {
         // Save to Gallery (Main Thread)
         await _saveToGallery(outputPath, isVideo: false);
      }
    } catch (e) {
      debugPrint("Offline recording processing failed: $e");
    }
  }

  Future<void> _saveToGallery(String filePath, {required bool isVideo}) async {
    try {
      // Check if file exists
      if (!File(filePath).existsSync()) {
        debugPrint('File not found: $filePath');
        return;
      }
      
      // Save to gallery
      if (isVideo) {
        await Gal.putVideo(filePath);
      } else {
        await Gal.putImage(filePath); // Gal.putImage works for GIFs too usually
      }
      debugPrint('Saved to gallery: $filePath');
      
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
    }
  }
}

// Top-level function for background GIF creation
Future<String?> _createGifInIsolate(Map<String, String> params) async {
  final tempDir = params['tempDir']!;
  final outputDir = params['outputDir']!;
  final outputFileName = 'offline_recording_${DateTime.now().millisecondsSinceEpoch}.gif';
  final outputPath = '$outputDir/$outputFileName';

  try {
    final encoder = img.GifEncoder();
    final directory = Directory(tempDir);
    final files = directory.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) return null;

    int count = 0;
    // Limit processing to prevent OOM in isolate as well, increases stability
    for (var file in files) {
      final bytes = await file.readAsBytes();
      final image = img.decodeJpg(bytes);
      if (image != null) {
        // Force resize for reasonable GIF size and speed
        final resized = img.copyResize(image, width: 320); 
        encoder.addFrame(resized, duration: 10);
        count++;
      }
      if (count > 200) break; // Limit to 200 frames (approx 20 sec video)
    }

    final gifBytes = encoder.finish();
    if (gifBytes != null) {
      final gifFile = File(outputPath);
      await gifFile.writeAsBytes(gifBytes);
      
      // Cleanup temp
      await Directory(tempDir).delete(recursive: true);
      return outputPath;
    }
  } catch (e) {
    debugPrint('Isolate GIF error: $e');
  }
  
  // Cleanup even if failed
  try {
     await Directory(tempDir).delete(recursive: true);
  } catch (_) {}
  
  return null;
}
