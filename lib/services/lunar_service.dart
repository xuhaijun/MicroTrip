import 'package:lunar/lunar.dart';

import '../models/calendar_models.dart';
import 'holiday_data.dart';

/// ============================================================
/// 农历 / 老黄历服务（封装 lunar 包，与小程序 utils/lunar.js 逻辑一致）
/// 底层 lunar: ^1.7.8（6tail 官方 Dart 版，与小程序 lunar-lib.js 同源）
/// 提供：农历日期、干支、生肖、节气、节日、宜忌、冲煞、纳音、
///       彭祖百忌、二十八宿、建除十二值星、星座
/// ============================================================
class LunarService {
  LunarService._();

  /// 旅游相关宜 / 忌关键词（用于「宜出行 / 忌远行」高亮）
  static const List<String> _travelYi = ['出行', '旅游', '远行', '移徙', '出游', '游猎'];
  static const List<String> _travelJi = ['出行', '远行', '出游', '旅游', '移徙'];

  static const List<String> _weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

  /// 日期格式化 YYYY-MM-DD
  static String fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 中文星期
  static String getWeekDay(DateTime date) => _weekDays[date.weekday % 7];

  /// 获取某公历日期的完整农历 / 老黄历信息
  static LunarDayInfo getLunarInfo(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final l = Lunar.fromDate(d);

    final monthText = l.getMonthInChinese(); // 六月 / 闰六月
    final dayText = l.getDayInChinese(); // 廿五
    final yearText = l.getYearInChinese(); // 二〇二六年

    final festivals = l.getFestivals();
    final otherFestivals = l.getOtherFestivals();
    final jieqi = l.getJieQi();

    final yi = l.getDayYi();
    final ji = l.getDayJi();

    final pengGan = l.getPengZuGan();
    final pengZhi = l.getPengZuZhi();
    final pengZu = [pengGan, pengZhi].where((e) => e.isNotEmpty).join('；');

    // 旅游向提示
    final hasTravelYi = yi.any((x) => _travelYi.any((k) => x.contains(k)));
    final hasTravelJi = ji.any((x) => _travelJi.any((k) => x.contains(k)));

    // 冲煞文本：冲羊(丁未)煞东
    String chongSha = '';
    final chong = l.getDayChongShengXiao();
    if (chong.isNotEmpty) {
      final desc = l.getDayChongDesc().replaceAll(chong, '');
      chongSha = '冲$chong$desc';
      final sha = l.getDaySha();
      if (sha.isNotEmpty) chongSha += '煞$sha';
    }

    // 节日文本
    final festivalsText = [...festivals, ...otherFestivals].join('、');

    // 年内第几天 / 第几周
    final dayOfYear = _dayOfYear(d);
    final firstDayWeek = DateTime(d.year, 1, 1).weekday % 7; // 0=周日
    final weekOfYear = ((dayOfYear - 1 + firstDayWeek) / 7).floor() + 1;

    // 距离今天
    final today = DateTime.now();
    final today0 = DateTime(today.year, today.month, today.day);
    final diff = d.difference(today0).inDays;
    String diffText = '今天';
    if (diff > 0) {
      diffText = '还有 $diff 天';
    } else if (diff < 0) {
      diffText = '已过 ${-diff} 天';
    }

    // 贴心建议（替代模拟天气）
    String suggestion;
    if (hasTravelYi) {
      suggestion = '黄历宜出行，正是出游好日子，安排一场旅行吧 🌤️';
    } else if (hasTravelJi) {
      suggestion = '黄历提示今日不宜远行，适合在家做行前攻略、整理装备 🎒';
    } else {
      suggestion = '择日不如撞日，有想去的风景就出发吧 ✨';
    }

    // 节假日名
    final holiday = HolidayData.getHolidayInfo(fmt(d));

    return LunarDayInfo(
      dateStr: fmt(d),
      weekDay: getWeekDay(d),
      holidayName: holiday?.name ?? '',
      lunarFull: '$yearText年$monthText月$dayText日',
      ganzhiYear: l.getYearInGanZhi(),
      ganzhiMonth: l.getMonthInGanZhi(),
      ganzhiDay: l.getDayInGanZhi(),
      zodiac: l.getYearShengXiao(),
      jieqi: jieqi,
      festivalsText: festivalsText,
      yiText: yi.join('、'),
      jiText: ji.join('、'),
      chongSha: chongSha,
      naYin: l.getDayNaYin(),
      pengZu: pengZu,
      xiu: l.getXiu(),
      xiuLuck: l.getXiuLuck(),
      zhiXing: l.getZhiXing(),
      constellation: Solar.fromDate(d).getXingZuo(),
      weekOfYear: weekOfYear,
      dayOfYear: dayOfYear,
      diffText: diffText,
      travelTip: hasTravelYi
          ? '宜出行'
          : (hasTravelJi ? '忌远行' : ''),
      suggestion: suggestion,
    );
  }

  /// 日历格子里的小标签（优先级：节气 > 节日 > 初一显示月份 > 农历日）
  static String getLunarDayLabel(DateTime date) {
    final l = Lunar.fromDate(date);

    final jieqi = l.getJieQi();
    if (jieqi.isNotEmpty) return jieqi;

    final festivals = l.getFestivals();
    if (festivals.isNotEmpty) return festivals.first;

    final otherFestivals = l.getOtherFestivals();
    if (otherFestivals.isNotEmpty) return otherFestivals.first;

    // 农历初一显示月份名（六月 / 闰六月）
    if (l.getDay() == 1) return '${l.getMonthInChinese()}月';

    return l.getDayInChinese();
  }

  /// 生成月历数据（上月补位 + 当月 + 下月补位，补满 35 或 42 格）
  static List<CalendarDayInfo> generateCalendar(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDay.weekday % 7; // 0=周日
    final prevMonthDays = DateTime(year, month, 0).day;
    final today = DateTime.now();

    final result = <CalendarDayInfo>[];

    // 上月补位
    for (var i = firstWeekday - 1; i >= 0; i--) {
      final day = prevMonthDays - i;
      final date = DateTime(year, month - 1, day);
      result.add(_day(date, isCurrentMonth: false, isPrev: true, today: today));
    }

    // 当月
    for (var i = 1; i <= daysInMonth; i++) {
      final date = DateTime(year, month, i);
      result.add(_day(date, isCurrentMonth: true, today: today));
    }

    // 下月补位（补满 35 或 42 格）
    final total = result.length;
    final target = total <= 35 ? 35 : 42;
    for (var i = 1; i <= target - total; i++) {
      final date = DateTime(year, month + 1, i);
      result.add(_day(date, isCurrentMonth: false, isNext: true, today: today));
    }
    return result;
  }

  static CalendarDayInfo _day(DateTime date,
      {required bool isCurrentMonth, bool isPrev = false, bool isNext = false, required DateTime today}) {
    final dateStr = fmt(date);
    final isToday = dateStr == fmt(today);
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    return CalendarDayInfo(
      day: date.day,
      dateStr: dateStr,
      isCurrentMonth: isCurrentMonth,
      isPrev: isPrev,
      isNext: isNext,
      isToday: isToday,
      isWeekend: isWeekend,
      holiday: HolidayData.getHolidayInfo(dateStr),
      lunarLabel: getLunarDayLabel(date),
    );
  }

  /// 年内第几天
  static int _dayOfYear(DateTime d) {
    final start = DateTime(d.year, 1, 1);
    return d.difference(start).inDays + 1;
  }
}
