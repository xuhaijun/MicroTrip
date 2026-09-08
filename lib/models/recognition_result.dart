// ============================================================
// 拍照识物结果模型（Phase 3 升级为真实云端 Vision）
//
// P3：识别改为走 MicroTripServer /vision/recognize（腾讯云图像分析代理），
// 返回标签列表 + 与发现页 scenery/food 数据的匹配推荐。
// 模型保留原字段（name/category/confidence/tags），新增
// [labels] / [matchedScenery] / [matchedFood] 承载服务端结构化结果。
// ============================================================

import 'scenery_item.dart';
import 'food_item.dart';

/// 单个识别标签（来自云端 Vision）
class VisionLabel {
  const VisionLabel({
    required this.name,
    this.category = '',
    required this.confidence,
  });

  /// 标签名（如 "博物馆" / "美食" / "银杏"）
  final String name;

  /// 云端分类（如 "建筑" / "食物" / "植物"，中文或英文）
  final String category;

  /// 置信度（0.0 - 1.0）
  final double confidence;

  /// 置信度百分比文本
  String get confidenceText => '${(confidence * 100).toStringAsFixed(0)}%';

  factory VisionLabel.fromJson(Map<String, dynamic> json) => VisionLabel(
        name: (json['name'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// 识物识别结果
class RecognitionResult {
  RecognitionResult({
    required this.name,
    required this.category,
    required this.confidence,
    this.scientificName,
    this.description,
    this.habitat,
    this.tips,
    this.tags = const [],
    this.labels = const [],
    this.matchedScenery = const [],
    this.matchedFood = const [],
  });

  /// 识别名称（如 "银杏" / "中华田园犬" / 命中标签名）
  final String name;
  /// 分类（plant / animal / landmark / food / unknown）
  final RecognitionCategory category;
  /// 置信度（0.0 - 1.0）
  final double confidence;
  /// 学名 / 拉丁名（植物，真实 Vision 一般无此字段）
  final String? scientificName;
  /// 物种简介
  final String? description;
  /// 栖息地 / 生长环境
  final String? habitat;
  /// 旅游贴士（花期/注意事项等）
  final String? tips;
  /// 标签（UI 展示用，等同于各 label.name）
  final List<String> tags;

  /// 云端返回的全部标签（含置信度/分类）
  final List<VisionLabel> labels;

  /// 与「美景」数据的匹配推荐（最多 3 条）
  final List<SceneryItem> matchedScenery;

  /// 与「美食」数据的匹配推荐（最多 3 条）
  final List<FoodItem> matchedFood;

  /// 是否含有可推荐的景点/美食
  bool get hasMatches => matchedScenery.isNotEmpty || matchedFood.isNotEmpty;

  /// 由服务端 /vision/recognize 响应构造
  /// 服务端返回 { labels:[VisionLabel], matches:{ scenery:[SceneryItem], food:[FoodItem] } }
  factory RecognitionResult.fromVisionJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final labels = rawLabels is List
        ? rawLabels
            .map((e) => VisionLabel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <VisionLabel>[];

    final top = labels.isNotEmpty ? labels.first : null;

    final matches = json['matches'] is Map
        ? json['matches'] as Map
        : <String, dynamic>{};
    final rawScenery = matches['scenery'];
    final scenery = rawScenery is List
        ? rawScenery
            .map((e) => SceneryItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <SceneryItem>[];
    final rawFood = matches['food'];
    final food = rawFood is List
        ? rawFood
            .map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <FoodItem>[];

    return RecognitionResult(
      name: top?.name ?? '未识别到内容',
      category: _mapCategory(top?.category ?? ''),
      confidence: top?.confidence ?? 0,
      tags: labels.map((l) => l.name).toList(),
      labels: labels,
      matchedScenery: scenery,
      matchedFood: food,
    );
  }

  /// 把云端分类文本映射到本地识别分类
  static RecognitionCategory _mapCategory(String category) {
    final s = category.toLowerCase();
    if (s.contains('食物') ||
        s.contains('food') ||
        s.contains('cuisine') ||
        s.contains('dish') ||
        s.contains('meal')) {
      return RecognitionCategory.food;
    }
    if (s.contains('建筑') ||
        s.contains('场景') ||
        s.contains('地标') ||
        s.contains('风景') ||
        s.contains('landmark') ||
        s.contains('building') ||
        s.contains('scenery') ||
        s.contains('site') ||
        s.contains('architecture')) {
      return RecognitionCategory.landmark;
    }
    if (s.contains('植物') || s.contains('plant')) return RecognitionCategory.plant;
    if (s.contains('动物') || s.contains('animal')) return RecognitionCategory.animal;
    return RecognitionCategory.unknown;
  }

  /// 置信度百分比文本
  String get confidenceText => '${(confidence * 100).toStringAsFixed(0)}%';

  /// 分类中文名
  String get categoryText => switch (category) {
        RecognitionCategory.plant => '植物',
        RecognitionCategory.animal => '动物',
        RecognitionCategory.landmark => '地标',
        RecognitionCategory.food => '美食',
        RecognitionCategory.unknown => '未知',
      };

  /// 分类 emoji 图标
  String get categoryIcon => switch (category) {
        RecognitionCategory.plant => '🌿',
        RecognitionCategory.animal => '🐾',
        RecognitionCategory.landmark => '🏛',
        RecognitionCategory.food => '🍜',
        RecognitionCategory.unknown => '❓',
      };

  Map<String, dynamic> toMap() => {
        'name': name,
        'cat': category.name,
        'conf': confidence,
        'sci': scientificName,
        'desc': description,
        'hab': habitat,
        'tips': tips,
        'tags': tags,
      };

  factory RecognitionResult.fromMap(Map<String, dynamic> m) => RecognitionResult(
        name: m['name'].toString(),
        category: RecognitionCategory.values.firstWhere(
          (e) => e.name == m['cat']?.toString(),
          orElse: () => RecognitionCategory.unknown,
        ),
        confidence: (m['conf'] as num?)?.toDouble() ?? 0.0,
        scientificName: m['sci']?.toString(),
        description: m['desc']?.toString(),
        habitat: m['hab']?.toString(),
        tips: m['tips']?.toString(),
        tags: m['tags'] != null
            ? List<String>.from(m['tags'] as List)
            : [],
      );
}

/// 识别分类
enum RecognitionCategory {
  plant,    // 植物
  animal,   // 动物
  landmark, // 地标建筑
  food,     // 美食
  unknown,  // 未识别
}
