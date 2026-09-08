import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/animations/anim_effects.dart';
import '../../core/http/http_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/food_item.dart';
import '../../models/recognition_result.dart';
import '../../models/scenery_item.dart';
import '../../providers/app_providers.dart';
import '../../services/photo_recognition_service.dart';
import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 拍照识物页（Phase 3 — 真实云端 Vision · 景点/美食识图）
///
/// 功能：
///  - 拍照 / 从相册选图
///  - 图片预览
///  - 真实识图：调用 MicroTripServer /vision/recognize（腾讯云图像分析代理）
///  - 结果展示（分类 / 名称 / 置信度 / 简介）
///  - 相关推荐：命中「美景」「美食」数据时展示可点击卡片，跳转详情页
///  - 重试识别 / 重新拍照
///
/// 对应小程序 subpackages/discover/pages/photo-recognize
/// ============================================================
class PhotoRecognitionPage extends ConsumerStatefulWidget {
  const PhotoRecognitionPage({super.key});

  @override
  ConsumerState<PhotoRecognitionPage> createState() =>
      _PhotoRecognitionPageState();
}

class _PhotoRecognitionPageState extends ConsumerState<PhotoRecognitionPage> {
  File? _imageFile;
  RecognitionResult? _result;
  bool _isProcessing = false;
  String? _error;

  final _picker = ImagePicker();

  @override
  void dispose() {
    super.dispose();
  }

  /// 重新选择（清空当前图片与结果）
  void _reselect() => setState(() {
        _imageFile = null;
        _result = null;
        _error = null;
      });

  /// 从相机拍照
  Future<void> _takePhoto() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xFile != null) {
        _setImage(File(xFile.path));
      }
    } catch (e) {
      setState(() => _error = '拍照失败: $e');
    }
  }

  /// 从相册选图
  Future<void> _pickFromGallery() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xFile != null) {
        _setImage(File(xFile.path));
      }
    } catch (e) {
      setState(() => _error = '选图失败: $e');
    }
  }

  /// 设置图片并开始识别
  void _setImage(File file) {
    setState(() {
      _imageFile = file;
      _result = null;
      _error = null;
      _isProcessing = true;
    });
    _recognize();
  }

  /// 识别图片（真实云端 Vision）
  Future<void> _recognize() async {
    if (_imageFile == null) return;
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    // 当前城市（用于服务端匹配注入）；cityProvider 来自 app_providers
    final city = ref.read(cityProvider).name;

    try {
      final result = await PhotoRecognitionService.recognize(
        _imageFile!.path,
        city: city,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      if (!mounted) return;
      // 提取可读错误信息（ServiceException 含 message）
      final msg = e is ServiceException ? e.message : e.toString();
      setState(() {
        _error = msg;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: '拍照识物',
            subtitle: '拍一张照片，小途帮你认出眼前的风景与美食',
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Expanded(
            child: _imageFile == null
                ? _buildSelector()
                : _buildResultView(),
          ),
        ],
      ),
    );
  }

  /// 初始选择器（拍照/相册）
  Widget _buildSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // 插画图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradientWith(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_camera_back,
                size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('拍照识物',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            '拍一张照片，小途用云端图像识别帮你认出眼前的风景与美食\n'
            '识别后会自动匹配发现页里的景点与美食推荐',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 32),
          // 拍照按钮
          FadeSlideIn(
            delay: 60,
            child: GradientButton(label: '拍照识别', onPressed: _takePhoto),
          ),
          const SizedBox(height: 12),
          // 相册按钮
          FadeSlideIn(
            delay: 120,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('从相册选择'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.round),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 结果视图（图片 + 识别结果）
  Widget _buildResultView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 图片预览
        FadeSlideIn(
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    topRight: Radius.circular(AppRadius.lg),
                  ),
                  child: Stack(
                    children: [
                      Image.file(
                        _imageFile!,
                        width: double.infinity,
                        height: 240,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _reselect,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('已选择照片，可重新选择或更换',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 处理中
        if (_isProcessing) ...[
          const FadeSlideIn(
            child: AppCard(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('正在识别中...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 错误
        if (_error != null) ...[
          FadeSlideIn(
            child: AppCard(
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.danger),
                  const SizedBox(height: 8),
                  const Text('识别失败',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _recognize,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 识别结果
        if (_result != null) ...[
          FadeSlideIn(delay: 60, child: _buildResultCard(_result!)),
          const SizedBox(height: 12),
          // 相关推荐（命中景点/美食时展示）
          if (_result!.hasMatches) ...[
            FadeSlideIn(delay: 120, child: _buildMatchesSection(_result!)),
            const SizedBox(height: 12),
          ],
          // 操作按钮
          FadeSlideIn(
            delay: 180,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _recognize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新识别'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(label: '继续拍照', onPressed: _reselect),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 识别结果卡片
  Widget _buildResultCard(RecognitionResult result) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：分类标签 + 置信度
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${result.categoryIcon} ${result.categoryText}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              // 置信度
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    '置信度 ${result.confidenceText}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 名称
          Text(
            result.name,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          if (result.scientificName != null) ...[
            const SizedBox(height: 4),
            Text(
              result.scientificName!,
              style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          // 简介
          if (result.description != null) ...[
            _InfoSection(
              icon: Icons.info_outline,
              title: '简介',
              content: result.description!,
            ),
            const SizedBox(height: 12),
          ],
          // 栖息地
          if (result.habitat != null) ...[
            _InfoSection(
              icon: Icons.public,
              title: '栖息地 / 分布',
              content: result.habitat!,
            ),
            const SizedBox(height: 12),
          ],
          // 贴士
          if (result.tips != null) ...[
            _InfoSection(
              icon: Icons.lightbulb_outline,
              title: '旅行贴士',
              content: result.tips!,
              iconColor: AppColors.accent,
            ),
            const SizedBox(height: 12),
          ],
          // 标签
          if (result.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: result.tags.map((tag) {
                return Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 相关推荐区（命中景点/美食时展示可点击卡片）
  Widget _buildMatchesSection(RecognitionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: '相关推荐'),
        const SizedBox(height: 12),
        if (result.matchedScenery.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('🏞 相关美景',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          _RecommendRow<SceneryItem>(
            items: result.matchedScenery,
            onTap: (item) => context.push('/scenery-detail/${item.id}'),
            titleOf: (item) => item.name,
            subOf: (item) => item.tag.isNotEmpty ? item.tag : item.address,
            ratingOf: (item) => item.rating,
            emojiOf: (item) => item.image,
          ),
          const SizedBox(height: 12),
        ],
        if (result.matchedFood.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('🍜 相关美食',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          _RecommendRow<FoodItem>(
            items: result.matchedFood,
            onTap: (item) => context.push('/food-detail/${item.id}'),
            titleOf: (item) => item.name,
            subOf: (item) => item.tag.isNotEmpty ? item.tag : item.price,
            ratingOf: (item) => item.rating,
            emojiOf: (item) => item.image,
          ),
        ],
      ],
    );
  }
}

/// 通用横向推荐卡片行（景点 / 美食复用）
class _RecommendRow<T> extends StatelessWidget {
  const _RecommendRow({
    required this.items,
    required this.onTap,
    required this.titleOf,
    required this.subOf,
    required this.ratingOf,
    required this.emojiOf,
  });

  final List<T> items;
  final void Function(T) onTap;
  final String Function(T) titleOf;
  final String? Function(T) subOf;
  final double Function(T) ratingOf;
  final String Function(T) emojiOf;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          final sub = subOf(item);
          return GestureDetector(
            onTap: () => onTap(item),
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // emoji 图标
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(emojiOf(item),
                        style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 10),
                  // 名称
                  Text(
                    titleOf(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  // 副信息
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  const Spacer(),
                  // 评分
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        ratingOf(item).toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 信息小节
class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.content,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String content;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(content,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
            ],
          ),
        ),
      ],
    );
  }
}
