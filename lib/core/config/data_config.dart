import '../storage/app_storage.dart';

/// ============================================================
/// 数据源配置（模拟数据总开关）
///
/// 控制「美景 / 美食」等信息类数据的数据来源（服务端优先策略）：
///  - false（默认）：优先从后端服务地址（[AuthService.serverUrl]）拉取真实数据；
///                   仅当「未配置后端地址」或「请求失败」时，自动回退到 App 内置示例，
///                   保证界面永不可用、网络抖动不闪白。
///  - true：强制使用 App 内置示例数据（离线演示 / 调试用）。
///
/// 开关持久化在本地偏好（travel_useMockData），设置页可切换。
/// 语义由 [FoodService]/[SceneryService] 的 `_shouldUseMock` 落地：
///   实际走 mock 的条件 = （开关强制开）OR（未配置后端地址）。
/// ============================================================
class DataConfig {
  DataConfig._();

  /// 是否使用模拟数据（默认关闭 → 服务端优先，无法连接时回退本地示例）
  static bool get useMockData =>
      AppStorage.getBool(AppStorage.kUseMockData, defaultValue: false);

  /// 持久化开关
  static Future<void> setUseMockData(bool value) =>
      AppStorage.setBool(AppStorage.kUseMockData, value);
}
