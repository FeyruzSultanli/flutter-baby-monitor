import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/webrtc/multi_peer_service.dart';
import '../core/webrtc/firestore_signaling.dart'; // Varsayılan signaling servisi
import '../l10n/app_localizations.dart';

class MultiCameraScreen extends StatefulWidget {
  const MultiCameraScreen({super.key});

  @override
  State<MultiCameraScreen> createState() => _MultiCameraScreenState();
}

class _MultiCameraScreenState extends State<MultiCameraScreen> {
  late MultiPeerService _multiPeerService;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Servisi başlatıyoruz. Signaling factory'yi buraya enjekte ediyoruz.
    _multiPeerService = MultiPeerService(
      signalingFactory: () => FirestoreSignaling(), 
    );
    
    // Değişiklikleri dinle
    _multiPeerService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
    _multiPeerService.removeListener(_onServiceUpdate);
    _multiPeerService.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _addCamera() async {
    final l10n = AppLocalizations.of(context);
    final TextEditingController controller = TextEditingController();
    final String? roomId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addCamera),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.enterRoomId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.add),
          ),
        ],
      ),
    );

    if (roomId != null && roomId.isNotEmpty) {
      await _multiPeerService.addPeer(roomId);
      // Yeni eklenen kameraya geçiş yap
      if (_multiPeerService.peers.isNotEmpty) {
        // PageView'ı güncellemek için biraz bekleyebiliriz veya state update sonrası
        // _pageController.jumpToPage(...) yapabiliriz.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final peerList = _multiPeerService.peers.values.toList();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.multiCameraMonitoring),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: _addCamera,
          ),
        ],
      ),
      body: peerList.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 80,
                      color: scheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.noCameraAdded,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tap the + button to add your first camera',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Add Camera'),
                      onPressed: _addCamera,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Üstte sekmeler veya küçük önizlemeler
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: peerList.length,
                    itemBuilder: (context, index) {
                      final peer = peerList[index];
                      final isActive = peer.roomId == _multiPeerService.activeRoomId;
                      return GestureDetector(
                        onTap: () {
                          _multiPeerService.setActivePeer(peer.roomId);
                          _pageController.jumpToPage(index);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isActive ? scheme.primary : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              '${l10n.baby} ${index + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.white : scheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Ana görüntü alanı
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: peerList.length,
                    onPageChanged: (index) {
                      final peer = peerList[index];
                      _multiPeerService.setActivePeer(peer.roomId);
                    },
                    itemBuilder: (context, index) {
                      final peer = peerList[index];
                      return Container(
                        color: Colors.black,
                        child: Stack(
                          children: [
                            RTCVideoView(
                              peer.remoteRenderer,
                              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            ),
                            Positioned(
                              bottom: 20,
                              left: 20,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${l10n.room}: ${peer.roomId}\n${l10n.status}: ${peer.status.name}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 20,
                              right: 20,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _multiPeerService.removePeer(peer.roomId),
                              ),
                            ),
                          ],
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
