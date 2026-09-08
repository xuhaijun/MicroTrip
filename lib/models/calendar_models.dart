// ============================================================
// 万年历模型（迁移自小程序 subpackages/tools/pages/calendar/calendar.js
//  + utils/lunar.js + utils/holidays.js）
// - HolidayInfo：法定节假日/调休信息
// - CalendarDayInfo：月历网格中的一天
// - LunarDayInfo：选中日期的完整农历/老黄历详情（详情面板）
// ============================================================

/// 节假日信息（放假 / 调休补班 / 普通节日）
class HolidayInfo {
  const HolidayInfo({
    required this.type, // 'holiday' | 'workday' | 'festival'
    required this.name,
    this.emoji = '',
    this.isHoliday = false,
    this.isWorkday = false,
    this.label = '',
  });

  final String type;
  final String name;
  final String emoji;
  final bool isHoliday;
  final bool isWorkday;

  /// 网格角标文本：休 / 班 / 节日名
  final String label;
}

/// 月历网格中的一天
class CalendarDayInfo {
  const CalendarDayInfo({
    required this.day,
    required this.dateStr,
    this.isCurrentMonth = false,
    this.isPrev = false,
    this.isNext = false,
    this.isToday = false,
    this.isWeekend = false,
    this.holiday,
    this.lunarLabel = '',
  });

  /// 公历日（1-31）
  final int day;

  /// YYYY-MM-DD
  final String dateStr;
  final bool isCurrentMonth;
  final bool isPrev;
  final bool isNext;
  final bool isToday;
  final bool isWeekend;

  /// 节假日信息（可能为 null）
  final HolidayInfo? holiday;

  /// 农历小标签（优先级：节气 > 节日 > 初一月份 > 农历日）
  final String lunarLabel;
}

/// 选中日期的完整农历 / 老黄历详情
class LunarDayInfo {
  const LunarDayInfo({
    required this.dateStr,
    required this.weekDay,
    this.holidayName = '',
    this.lunarFull = '',
    this.ganzhiYear = '',
    this.ganzhiMonth = '',
    this.ganzhiDay = '',
    this.zodiac = '',
    this.jieqi = '',
    this.festivalsText = '',
    this.yiText = '',
    this.jiText = '',
    this.chongSha = '',
    this.naYin = '',
    this.pengZu = '',
    this.xiu = '',
    this.xiuLuck = '',
    this.zhiXing = '',
    this.constellation = '',
    this.weekOfYear = 0,
    this.dayOfYear = 0,
    this.diffText = '',
    this.travelTip = '',
    this.suggestion = '',
  });

  final String dateStr;
  final String weekDay;

  /// 节假日名（如「春节」，无则空）
  final String holidayName;

  /// 农历完整文本：二〇二六年七月初七日
  final String lunarFull;

  /// 干支：丙午年 / 丙申月 / 己丑日
  final String ganzhiYear;
  final String ganzhiMonth;
  final String ganzhiDay;

  /// 生肖：马
  final String zodiac;

  /// 当日节气（无则空）
  final String jieqi;

  /// 节日文本（传统节日 + 其他节日合并）
  final String festivalsText;

  /// 宜（顿号分隔）
  final String yiText;

  /// 忌（顿号分隔）
  final String jiText;

  /// 冲煞：冲羊(丁未)煞东
  final String chongSha;

  /// 五行纳音
  final String naYin;

  /// 彭祖百忌
  final String pengZu;

  /// 二十八宿
  final String xiu;

  /// 星宿吉凶
  final String xiuLuck;

  /// 建除十二值星
  final String zhiXing;

  /// 星座
  final String constellation;

  /// 年内第几周
  final int weekOfYear;

  /// 年内第几天
  final int dayOfYear;

  /// 距今天：今天 / 还有 N 天 / 已过 N 天
  final String diffText;

  /// 旅游向提示：宜出行 / 忌远行 / 空
  final String travelTip;

  /// 贴心建议（综合文案）
  final String suggestion;
}
