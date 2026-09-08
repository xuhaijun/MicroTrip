import 'dart:convert';
import 'dart:io';

import '../core/http/http_client.dart';
import '../models/recognition_result.dart';
import '../services/auth_service.dart';

/// ============================================================
/// 拍照识物服务（Phase 3 — 真实云端 Vision）
///
/// 原 Phase 2 为 mock 实现；P3 改为调用 MicroTripServer
/// `POST {apiBase}/vision/recognize`（服务端代理云厂商图像分析，
/// 默认腾讯云 tiia，可切换阿里云/百度云），
/// 返回标签列表 + 与发现页 scenery/food 数据的匹配推荐。
///
/// 设计原则（用户要求「真实」）：
///  - 未配置后端地址 / 后端未启用 Vision → 抛出明确错误，不做 mock 伪造结果。
///  - 请求失败（网络/服务端 5xx）→ 原样抛出，由页面错误态展示。
///
/// 依赖：
///  - [AuthService.serverUrl]   后端地址（设置页配置）
///  - [AuthService.isLoggedIn]  是否携带 Bearer（/vision/recognize 需鉴权）
/// ============================================================
class PhotoRecognitionService {
  PhotoRecognitionService._();

  /// 识别图片并返回结构化结果
  ///
  /// [imagePath] 本地图片路径；[city] 当前城市（用于服务端匹配注入）。
  /// 失败抛 [ServiceException]（含 code）。
  static Future<RecognitionResult> recognize(
    String imagePath, {
    String city = '',
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw ServiceException('图片文件不存在: $imagePath', code: -1);
    }

    final serverUrl = AuthService.serverUrl;
    if (serverUrl.isEmpty) {
      throw ServiceException(
        '未配置后端服务地址。请在「设置 → 账号与后端服务」中填写 MicroTripServer 地址后使用拍照识物。',
        code: -1,
      );
    }

    // 读取图片并 base64 编码（不含 data: 前缀，由服务端按需处理）
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final data = await HttpClient.post(
        '${AuthService.apiBase}/vision/recognize',
        body: {'imageBase64': base64Image, 'city': city},
        needAuth: AuthService.isLoggedIn,
      );
      return RecognitionResult.fromVisionJson(
        Map<String, dynamic>.from(data as Map),
      );
    } on ServiceException catch (e) {
      // 服务端返回 501：Vision API 未配置（缺密钥），给出可操作的提示
      if (e.code == 501) {
        throw ServiceException(
          '后端未启用图像识别（Vision API）。请在服务端配置 '
          'VISION_SECRET_ID / VISION_SECRET_KEY 后重试。',
          code: 501,
        );
      }
      rethrow;
    }
  }
}
