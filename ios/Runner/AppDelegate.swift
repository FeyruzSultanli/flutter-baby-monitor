import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Last APNs registration result, for logs ("pending", "token", "error: ...").
  private var apnsStatus = "not requested"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

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
