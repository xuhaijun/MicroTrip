import '../models/oneday_plan.dart';
import 'ai_service.dart';

/// ============================================================
/// 一日游攻略服务（迁移自小程序 subpackages/travel/pages/oneday/oneday.js）
/// - buildTimeline：城市专属 5 段式时间轴（离线可用）
/// - optimize：AI 优化行程（未配置 Key 时 AiService 自动降级 mock）
/// ============================================================
class OneDayService {
  OneDayService._();

  /// 构建城市专属一日游时间轴（始终展示，离线可用）
  static List<OneDayPlanItem> buildTimeline(String city) {
    return [
      OneDayPlanItem(
        time: '09:00',
        period: '上午',
        icon: '🏛️',
        title: '$city历史博物馆',
        desc: '走进博物馆与老街区，先读懂这座城市的过往与烟火气',
      ),
      OneDayPlanItem(
        time: '12:00',
        period: '中午',
        icon: '🍜',
        title: '老字号地道午餐',
        desc: '找一家本地人排队的面馆或餐馆，人均 30 元左右吃顿扎实的',
      ),
      OneDayPlanItem(
        time: '14:30',
        period: '下午',
        icon: '🌳',
        title: '公园 / 近郊漫步',
        desc: '去城市中央公园或近郊景区透气，拍拍照、散散步最舒服',
      ),
      OneDayPlanItem(
        time: '17:30',
        period: '傍晚',
        icon: '🌊',
        title: '滨江观景看日落',
        desc: '傍晚到滨江步道或观景台，看落日染红天际、夜景初上',
      ),
      OneDayPlanItem(
        time: '19:30',
        period: '晚上',
        icon: '🍢',
        title: '夜市小吃收尾',
        desc: '钻进夜市来份烤串炸串配冰饮，用烟火气结束一天',
      ),
    ];
  }

  /// AI 优化行程（配置 API Key 时生成个性化建议，否则返回模拟文案）
  static Future<String> optimize(String city) {
    return AiService.ask(
      '请为我去$city的一日游做个性化行程优化，按时间段给出建议，'
      '覆盖上午/中午/下午/傍晚/晚上 5 个时段，每段一句话，最后给一条出行小贴士。',
      context: '当前城市：$city',
    );
  }
}
