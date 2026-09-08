/// ============================================================
/// 敏感密钥配置模板（此文件可提交到版本库）
///
/// 用法：复制本文件为 secrets.dart（同目录），并填入真实密钥：
///   cp lib/core/config/secrets.example.dart lib/core/config/secrets.dart
///
/// secrets.dart 已被 .gitignore 忽略，不会提交真实密钥；
/// 本示例文件仅含占位符，可安全入库。
/// ============================================================
class Secrets {
  Secrets._();

  /// 和风天气 API Key（https://dev.qweather.com/）
  static const String weatherApiKey = '在此填写和风天气API Key';

  /// 智谱 AI API Key（https://open.bigmodel.cn/）
  static const String aiApiKey = '在此填写智谱AI API Key';

  /// 腾讯地图 Key（逆地理编码，https://lbs.qq.com/）
  static const String tencentMapKey = '在此填写腾讯地图Key';

  /// 天地图 tk（浏览器端应用，https://console.tianditu.gov.cn/api/key）
  static const String tdtKey = '在此填写天地图tk';
}
