// ============================================================
// 后台轨迹定位管理器（ios/Runner/BackgroundLocationManager.swift）
//
// 职责：在 App 退到后台 / 锁屏时，仍持续接收 CLLocationManager 的位置更新，
// 并定期通过 BGTaskScheduler 触发一次「轨迹上传/续订」，保证轨迹完整。
//
// ⚠️ 完成度提示（需 Mac + Xcode）：
//  1. 必须在 Xcode → Signing & Capabilities 勾选 Background Modes：
//     - Location updates
//     - Background fetch
//  2. Info.plist 已加 UIBackgroundModes(location/fetch) 与
//     BGTaskSchedulerPermittedIdentifiers(com.microtrip.backgroundRefresh)。
//  3. 真实轨迹落库/上传逻辑建议在 didUpdateLocations 中批量缓存，
//     再于 BGTask 或网络恢复时同步到 MicroTripServer（见 NetworkClient）。
//  4. 本文件仅提供「保活 + 回调」骨架，未引入具体数据库依赖。
// ============================================================

import BackgroundTasks
import CoreLocation
import Foundation

final class BackgroundLocationManager: NSObject, CLLocationManagerDelegate {

  /// 单例（AppDelegate 注册 MethodChannel 时调用）
  static let shared = BackgroundLocationManager()

  /// 与 Info.plist / BGTaskSchedulerPermittedIdentifiers 保持一致
  private let refreshTaskId = "com.microtrip.backgroundRefresh"

  private let manager = CLLocationManager()

  /// 位置回调（Dart 侧通过 EventChannel / 本地缓存读取）
  var onLocationUpdate: ((CLLocation) -> Void)?

  private override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
    // 后台持续定位的关键开关：必须配合 UIBackgroundModes(location)
    manager.allowsBackgroundLocationUpdates = true
    // 关闭自动暂停，避免系统为省电停掉更新（按需可改为 true 由业务控制）
    manager.pausesLocationUpdatesAutomatically = false
    manager.activityType = .automotiveNavigation
  }

  // ---- 对外控制 ----
  func start() {
    // 始终授权：后台持续记录需要 Always（已配 NSLocationAlwaysAndWhenInUseUsageDescription）
    manager.requestAlwaysAuthorization()
    manager.startUpdatingLocation()
  }

  func stop() {
    manager.stopUpdatingLocation()
  }

  // ---- BGTaskScheduler 注册与续订 ----
  func setupBGTask() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: refreshTaskId,
      using: nil
    ) { task in
      self.handleRefresh(task as! BGAppRefreshTask)
    }
  }

  /// 提交一次后台刷新任务（建议在前台或每次任务结束时调用）
  func scheduleRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
    // 最早 15 分钟后由系统调度
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      NSLog("[MicroTrip] 提交 BGTask 失败: \(error.localizedDescription)")
    }
  }

  private func handleRefresh(_ task: BGAppRefreshTask) {
    // 任务即将超时时标记为失败，避免系统处罚
    task.expirationHandler = {
      task.setTaskCompleted(success: false)
    }

    // 触发一次定位刷新 / 轨迹同步（真实实现在此调用 NetworkClient）
    // 示例：NetworkClient.shared.syncPendingTrajectories { _ in }
    onLocationUpdate?(CLLocation(
      latitude: manager.location?.coordinate.latitude ?? 0,
      longitude: manager.location?.coordinate.longitude ?? 0
    ))

    // 链式续订下一次后台刷新
    scheduleRefresh()
    task.setTaskCompleted(success: true)
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let last = locations.last else { return }
    // 真实实现：写入轨迹缓冲区（本地），由同步模块择机上传
    onLocationUpdate?(last)
  }

  func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    // 仅记录，不崩溃（如授权被拒、GPS 暂不可用）
    NSLog("[MicroTrip] 定位错误: \(error.localizedDescription)")
  }
}
