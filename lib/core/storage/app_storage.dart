import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// ============================================================
/// 本地存储服务
/// 迁移自小程序 utils/storage.js：
///  - 所有键带 `travel_` 前缀隔离（与小程序完全一致，便于未来数据互迁）
///  - 列表型数据提供「去重插入 / 按 id 删除 / 按 id 局部更新」能力
///  - JSON 自动编解码，上层直接拿到 Dart 对象
/// ============================================================
class AppStorage {
  AppStorage._();

  static const String prefix = AppConfig.storagePrefix;

  /// 单例持有的 SharedPreferences 实例（在 main() 中初始化）
  static late SharedPreferences _prefs;

  /// 在 runApp 之前调用（见 main.dart）
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 存储键枚举（与小程序 storage.js 的 Keys 一一对应）
  static const String kUserInfo = 'userInfo';
  static const String kUserSettings = 'userSettings';
  static const String kUserProfile = 'userProfile';
  static const String kCurrentCity = 'currentCity';
  static const String kRecentCities = 'recentCities';
  static const String kWeatherCache = 'weatherCache';
  static const String kTrajectoryList = 'trajectoryList';
  static const String kMemoList = 'memoList';
  static const String kAiChatHistory = 'aiChatHistory';
  static const String kFavoriteFood = 'favoriteFood';
  static const String kFavoriteScenery = 'favoriteScenery';
  static const String kAiConfig = 'aiConfig';
  static const String kWeatherConfig = 'weatherConfig';
  /// 模拟数据总开关：true=强制使用 App 内置示例；false=服务端优先（默认，
  /// 无法连接时自动回退本地示例）。语义详见 [DataConfig.useMockData]。
  static const String kUseMockData = 'useMockData';

  /// 是否已完成首次引导页（引导页仅在首次安装后展示一次）
  static const String kGuideSeen = 'guideSeen';

  /// 是否已同意《用户协议 & 隐私政策》（首次启动弹框征询，
  /// 同意后置 true；清除全部本地数据后重置为 false）
  static const String kPrivacyAgreed = 'privacyAgreed';

  // ---------------- 基础读写 ----------------

  static String _key(String key) => '$prefix$key';

  /// 保存任意可 JSON 序列化的对象
  static Future<bool> setObject(String key, Object? value) {
    if (value == null) return _prefs.remove(_key(key));
    return _prefs.setString(_key(key), jsonEncode(value));
  }

  /// 读取对象（自动 JSON 解码），不存在时返回 [defaultValue]
  static dynamic getObject(String key, {Object? defaultValue}) {
    final raw = _prefs.getString(_key(key));
    if (raw == null || raw.isEmpty) return defaultValue;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return defaultValue;
    }
  }

  static Future<bool> remove(String key) => _prefs.remove(_key(key));

  /// 读取布尔值（默认 [defaultValue]）
  static bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(_key(key)) ?? defaultValue;

  /// 保存布尔值
  static Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);

  // ---------------- 列表便捷操作 ----------------

  /// 插入/覆盖列表项（有 id 时按 id 去重，新的在前），并限制长度
  static Future<List<dynamic>> appendToList(
    String key,
    Map<String, dynamic> item, {
    int maxLen = 100,
  }) async {
    final list = (getObject(key, defaultValue: []) as List).cast<Map>();
    final mapped = list.map((e) => Map<String, dynamic>.from(e)).toList();
    if (item.containsKey('id') && item['id'] != null) {
      final idx =
          mapped.indexWhere((e) => e['id']?.toString() == item['id']?.toString());
      if (idx > -1) {
        mapped[idx] = item;
      } else {
        mapped.insert(0, item);
      }
    } else {
      mapped.insert(0, item);
    }
    if (mapped.length > maxLen) mapped.removeRange(maxLen, mapped.length);
    await setObject(key, mapped);
    return mapped;
  }

  /// 按 id 删除列表项
  static Future<List<dynamic>> removeFromList(String key, Object id) async {
    final list = (getObject(key, defaultValue: []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.removeWhere((e) => e['id']?.toString() == id.toString());
    await setObject(key, list);
    return list;
  }

  /// 按 id 局部更新列表项
  static Future<Map<String, dynamic>?> updateListItem(
    String key,
    Object id,
    Map<String, dynamic> updates,
  ) async {
    final list = (getObject(key, defaultValue: []) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final idx = list.indexWhere((e) => e['id']?.toString() == id.toString());
    if (idx == -1) return null;
    list[idx] = {...list[idx], ...updates};
    await setObject(key, list);
    return list[idx];
  }

  /// 生成唯一 id（时间戳36进制 + 随机串，与小程序 generateId 一致）
  static String generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = (Random().nextInt(0x100000)).toRadixString(36).padLeft(4, '0');
    return '$ts$rand';
  }

  /// 清除本应用全部数据（仅删除 travel_ 前缀键）
  static Future<void> clearAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
