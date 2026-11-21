import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    AppDelegate.skipSoundStreamPluginOnIOS()
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// The sound_stream plugin is only used by offline mode, which is Android
  /// only (Nearby Connections). On iOS its registration creates an
  /// AVAudioEngine at launch; on the simulator that aborts the app (CoreAudio
  /// AURemoteIO RPC timeout) and on devices it needlessly takes the audio
  /// hardware before WebRTC. Make its registration a no-op on iOS; the Dart
  /// side only calls sound_stream on Android. See DECISIONS.md A11.
  private static func skipSoundStreamPluginOnIOS() {
    guard let pluginClass: AnyClass = NSClassFromString("SoundStreamPlugin"),
          let method = class_getClassMethod(pluginClass, NSSelectorFromString("registerWithRegistrar:"))
    else { return }
    let noop: @convention(block) (AnyObject, AnyObject) -> Void = { _, _ in }
    method_setImplementation(method, imp_implementationWithBlock(noop))
  }
}
