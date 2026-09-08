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
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 后台轨迹定位通道：Dart 侧通过 MethodChannel('microtrip/location') 控制
    let location = BackgroundLocationManager.shared
    let channel = FlutterMethodChannel(
      name: "microtrip/location",
      binaryMessenger: engineBridge.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "startBackgroundLocation":
        location.start()
        result(nil)
      case "stopBackgroundLocation":
        location.stop()
        result(nil)
      case "scheduleBackgroundRefresh":
        location.setupBGTask()
        location.scheduleRefresh()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    // 注册 BGTask 处理（仅声明一次即可）
    location.setupBGTask()
  }
}
