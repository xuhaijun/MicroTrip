import 'package:flutter/material.dart';

import '../../models/weather.dart';

/// ============================================================
/// 天气图标映射（UI 层）
///
/// 模型层 [WeatherUtils.iconOf] 返回 emoji（纯 Dart，供纯 Dart 测试与分享文案使用，
/// 因此不能引入 Flutter 依赖）；界面统一使用本文件映射的 Material 线性图标，
/// 避免 iOS / Android / 各厂商 emoji 字体风格不一致。
///
/// 用法：`Icon(weatherIconOf(now.icon), size: 26, color: Colors.white)`
/// ============================================================
IconData weatherIconOf(String code) {
  // 去掉变体选择符 U+FE0F，保证不同字体/平台下查表键一致
  final key = WeatherUtils.iconOf(code).replaceAll('\uFE0F', '');
  return _byEmoji[key] ?? Icons.wb_cloudy;
}

/// emoji（去变体选择符后）→ Material 线性图标
const Map<String, IconData> _byEmoji = <String, IconData>{
  '\u{2600}': Icons.wb_sunny, // 晴
  '\u{26C5}': Icons.wb_cloudy, // 多云 / 晴间多云
  '\u{1F324}': Icons.wb_cloudy, // 少云
  '\u{2601}': Icons.cloud, // 阴
  '\u{1F319}': Icons.nightlight_round, // 晴（夜间）
  '\u{1F327}': Icons.grain, // 雨（小雨~暴雨）
  '\u{1F326}': Icons.grain, // 阵雨
  '\u{26C8}': Icons.thunderstorm, // 雷阵雨
  '\u{2744}': Icons.ac_unit, // 雪
  '\u{1F328}': Icons.ac_unit, // 雨夹雪 / 冻雨
  '\u{1F32B}': Icons.blur_on, // 薄雾 / 雾 / 浓雾
  '\u{1F637}': Icons.masks, // 霾
  '\u{1F32A}': Icons.tornado, // 扬沙 / 浮尘 / 沙尘暴
  '\u{1F975}': Icons.local_fire_department, // 热
  '\u{1F976}': Icons.ac_unit, // 冷
};

/// 出行建议 emoji → Material 线性图标（模型层 adviceOf 仍返回 emoji，此处仅做 UI 映射）
IconData adviceIconOf(String emoji) =>
    _adviceByEmoji[emoji.replaceAll('\uFE0F', '')] ?? Icons.lightbulb_outline;

const Map<String, IconData> _adviceByEmoji = <String, IconData>{
  '\u{1F9E5}': Icons.checkroom, // 严寒保暖
  '\u{1F454}': Icons.dry_cleaning, // 凉爽加外套
  '\u{1F455}': Icons.style, // 舒适轻薄
  '\u{1F9CA}': Icons.wb_sunny, // 炎热防暑
  '\u{2614}': Icons.beach_access, // 携带雨具
  '\u{1F462}': Icons.ac_unit, // 雨雪路滑
  '\u{1F637}': Icons.masks, // 能见度低戴口罩
  '\u{26A1}': Icons.bolt, // 雷暴避免户外
};
