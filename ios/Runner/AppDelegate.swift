import AVFoundation
import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Last APNs registration result, for logs ("pending", "token", "error: ...").
  private var apnsStatus = "not requested"
  /// V2.1: network status + audio route channels (DeviceChannels.swift).
  private var deviceChannels: DeviceChannels?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let deviceRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "NinniDevice") {
      deviceChannels = DeviceChannels(messenger: deviceRegistrar.messenger())
    }

    // Push (see lib/core/services/push_registration.dart): plugins are
    // registered after launch since the UIScene migration, so
    // firebase_messaging misses the launch notification on which it would
    // call registerForRemoteNotifications. Dart asks for it here once
    // Firebase is configured; Firebase Messaging's app delegate proxy then
    // receives the APNs token.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BebekMonitorPush")
    else { return }
    let channel = FlutterMethodChannel(
      name: "bebek_monitor/push", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "registerForRemoteNotifications":
        self?.apnsStatus = "pending"
        UIApplication.shared.registerForRemoteNotifications()
        result(nil)
      case "apnsStatus":
        result(self?.apnsStatus)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsStatus = "token"
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    apnsStatus = "error: \(error.localizedDescription)"
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}

/// V2.1: small platform channels instead of extra packages.
///
/// - `ninni/network` (events): true while a network path is available (§3).
///   connectivity_plus was not used because it pulls in an MPL-2.0 package.
/// - `ninni/device` (methods): `audioRoute` (category, mode, options and the
///   current input/output ports) for the diagnostics screen (§1, §2).
final class DeviceChannels: NSObject, FlutterStreamHandler {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "ninni.network")
  private var sink: FlutterEventSink?
  private var started = false
  private var lastOnline = true
  private var networkChannel: FlutterEventChannel?
  private var deviceChannel: FlutterMethodChannel?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    networkChannel = FlutterEventChannel(name: "ninni/network", binaryMessenger: messenger)
    networkChannel?.setStreamHandler(self)
    deviceChannel = FlutterMethodChannel(name: "ninni/device", binaryMessenger: messenger)
    deviceChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "audioRoute":
        result(DeviceChannels.audioRoute())
      case "isOnline":
        result(self?.lastOnline ?? true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    if !started {
      started = true
      monitor.pathUpdateHandler = { [weak self] path in
        let online = path.status == .satisfied
        DispatchQueue.main.async {
          self?.lastOnline = online
          self?.sink?(online)
        }
      }
      monitor.start(queue: queue)
    } else {
      events(lastOnline)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  static func audioRoute() -> [String: Any] {
    let session = AVAudioSession.sharedInstance()
    let outputs = session.currentRoute.outputs.map { $0.portType.rawValue }
    let inputs = session.currentRoute.inputs.map { $0.portType.rawValue }
    var options: [String] = []
    let o = session.categoryOptions
    if o.contains(.mixWithOthers) { options.append("mixWithOthers") }
    if o.contains(.duckOthers) { options.append("duckOthers") }
    if o.contains(.allowBluetooth) { options.append("allowBluetooth") }
    if o.contains(.allowBluetoothA2DP) { options.append("allowBluetoothA2DP") }
    if o.contains(.defaultToSpeaker) { options.append("defaultToSpeaker") }
    if o.contains(.allowAirPlay) { options.append("allowAirPlay") }
    let permission: String
    switch session.recordPermission {
    case .granted: permission = "granted"
    case .denied: permission = "denied"
    default: permission = "undetermined"
    }
    return [
      "platform": "ios",
      "category": session.category.rawValue.replacingOccurrences(
        of: "AVAudioSessionCategory", with: ""),
      "mode": session.mode.rawValue.replacingOccurrences(of: "AVAudioSessionMode", with: ""),
      "options": options,
      "outputs": outputs,
      "inputs": inputs,
      "outputVolume": session.outputVolume,
      "otherAudioPlaying": session.isOtherAudioPlaying,
      "recordPermission": permission,
      "sampleRate": session.sampleRate,
    ]
  }
}
