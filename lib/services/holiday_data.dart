import '../models/calendar_models.dart';

/// ============================================================
/// 中国法定节假日 & 调休数据（迁移自小程序 utils/holidays.js）
/// 包含 2024-2026 年数据，可按需扩展。
/// 数据格式：date 'YYYY-MM-DD' -> HolidayInfo
///  - holiday: 放假
///  - workday: 调休补班
///  - festival: 普通节日（不放假）
/// ============================================================
class HolidayData {
  HolidayData._();

  /// 固定日期节日（每年循环）
  static const List<({int month, int day, String name, String emoji, bool isLegal})>
      fixedFestivals = [
    (month: 1, day: 1, name: '元旦', emoji: '🎉', isLegal: true),
    (month: 2, day: 14, name: '情人节', emoji: '💝', isLegal: false),
    (month: 3, day: 8, name: '妇女节', emoji: '🌸', isLegal: false),
    (month: 3, day: 12, name: '植树节', emoji: '🌳', isLegal: false),
    (month: 4, day: 1, name: '愚人节', emoji: '😜', isLegal: false),
    (month: 5, day: 1, name: '劳动节', emoji: '✊', isLegal: true),
    (month: 5, day: 4, name: '青年节', emoji: '🌟', isLegal: false),
    (month: 6, day: 1, name: '儿童节', emoji: '🧸', isLegal: false),
    (month: 7, day: 1, name: '建党节', emoji: '🔴', isLegal: false),
    (month: 8, day: 1, name: '建军节', emoji: '🎖️', isLegal: false),
    (month: 9, day: 10, name: '教师节', emoji: '🍎', isLegal: false),
    (month: 10, day: 1, name: '国庆节', emoji: '🇨🇳', isLegal: true),
    (month: 11, day: 11, name: '光棍节', emoji: '🎒', isLegal: false),
    (month: 12, day: 25, name: '圣诞节', emoji: '🎄', isLegal: false),
  ];

  /// 2024-2026 放假与调休安排（与小程序 holidays.js 数据一致）
  static const Map<String, ({String type, String name})> arrangements = {
    // ---- 2024 年 ----
    '2024-01-01': (type: 'holiday', name: '元旦'),
    '2024-02-04': (type: 'workday', name: '春节调休'),
    '2024-02-10': (type: 'holiday', name: '春节'),
    '2024-02-11': (type: 'holiday', name: '春节'),
    '2024-02-12': (type: 'holiday', name: '春节'),
    '2024-02-13': (type: 'holiday', name: '春节'),
    '2024-02-14': (type: 'holiday', name: '春节'),
    '2024-02-15': (type: 'holiday', name: '春节'),
    '2024-02-16': (type: 'holiday', name: '春节'),
    '2024-02-17': (type: 'holiday', name: '春节'),
    '2024-02-18': (type: 'workday', name: '春节调休'),
    '2024-04-04': (type: 'holiday', name: '清明节'),
    '2024-04-05': (type: 'holiday', name: '清明节'),
    '2024-04-06': (type: 'holiday', name: '清明节'),
    '2024-04-07': (type: 'workday', name: '清明调休'),
    '2024-04-28': (type: 'workday', name: '劳动节调休'),
    '2024-05-01': (type: 'holiday', name: '劳动节'),
    '2024-05-02': (type: 'holiday', name: '劳动节'),
    '2024-05-03': (type: 'holiday', name: '劳动节'),
    '2024-05-04': (type: 'holiday', name: '劳动节'),
    '2024-05-05': (type: 'holiday', name: '劳动节'),
    '2024-05-11': (type: 'workday', name: '劳动节调休'),
    '2024-06-08': (type: 'holiday', name: '端午节'),
    '2024-06-09': (type: 'holiday', name: '端午节'),
    '2024-06-10': (type: 'holiday', name: '端午节'),
    '2024-09-14': (type: 'workday', name: '中秋调休'),
    '2024-09-15': (type: 'holiday', name: '中秋节'),
    '2024-09-16': (type: 'holiday', name: '中秋节'),
    '2024-09-17': (type: 'holiday', name: '中秋节'),
    '2024-09-29': (type: 'workday', name: '国庆调休'),
    '2024-10-01': (type: 'holiday', name: '国庆节'),
    '2024-10-02': (type: 'holiday', name: '国庆节'),
    '2024-10-03': (type: 'holiday', name: '国庆节'),
    '2024-10-04': (type: 'holiday', name: '国庆节'),
    '2024-10-05': (type: 'holiday', name: '国庆节'),
    '2024-10-06': (type: 'holiday', name: '国庆节'),
    '2024-10-07': (type: 'holiday', name: '国庆节'),
    '2024-10-12': (type: 'workday', name: '国庆调休'),
    // ---- 2025 年 ----
    '2025-01-01': (type: 'holiday', name: '元旦'),
    '2025-01-26': (type: 'workday', name: '春节调休'),
    '2025-01-28': (type: 'holiday', name: '春节'),
    '2025-01-29': (type: 'holiday', name: '春节'),
    '2025-01-30': (type: 'holiday', name: '春节'),
    '2025-01-31': (type: 'holiday', name: '春节'),
    '2025-02-01': (type: 'holiday', name: '春节'),
    '2025-02-02': (type: 'holiday', name: '春节'),
    '2025-02-03': (type: 'holiday', name: '春节'),
    '2025-02-04': (type: 'holiday', name: '春节'),
    '2025-02-08': (type: 'workday', name: '春节调休'),
    '2025-04-04': (type: 'holiday', name: '清明节'),
    '2025-04-05': (type: 'holiday', name: '清明节'),
    '2025-04-06': (type: 'holiday', name: '清明节'),
    '2025-04-27': (type: 'workday', name: '劳动节调休'),
    '2025-05-01': (type: 'holiday', name: '劳动节'),
    '2025-05-02': (type: 'holiday', name: '劳动节'),
    '2025-05-03': (type: 'holiday', name: '劳动节'),
    '2025-05-04': (type: 'holiday', name: '劳动节'),
    '2025-05-05': (type: 'holiday', name: '劳动节'),
    '2025-05-31': (type: 'holiday', name: '端午节'),
    '2025-06-01': (type: 'holiday', name: '端午节'),
    '2025-06-02': (type: 'holiday', name: '端午节'),
    '2025-09-28': (type: 'workday', name: '国庆调休'),
    '2025-10-01': (type: 'holiday', name: '国庆节'),
    '2025-10-02': (type: 'holiday', name: '国庆节'),
    '2025-10-03': (type: 'holiday', name: '国庆节'),
    '2025-10-04': (type: 'holiday', name: '中秋节'),
    '2025-10-05': (type: 'holiday', name: '国庆节'),
    '2025-10-06': (type: 'holiday', name: '国庆节'),
    '2025-10-07': (type: 'holiday', name: '国庆节'),
    '2025-10-08': (type: 'holiday', name: '国庆节'),
    '2025-10-11': (type: 'workday', name: '国庆调休'),
    // ---- 2026 年 ----
    '2026-01-01': (type: 'holiday', name: '元旦'),
    '2026-01-02': (type: 'holiday', name: '元旦'),
    '2026-01-03': (type: 'holiday', name: '元旦'),
    '2026-02-15': (type: 'workday', name: '春节调休'),
    '2026-02-16': (type: 'workday', name: '春节调休'),
    '2026-02-17': (type: 'holiday', name: '春节'),
    '2026-02-18': (type: 'holiday', name: '春节'),
    '2026-02-19': (type: 'holiday', name: '春节'),
    '2026-02-20': (type: 'holiday', name: '春节'),
    '2026-02-21': (type: 'holiday', name: '春节'),
    '2026-02-22': (type: 'holiday', name: '春节'),
    '2026-02-23': (type: 'holiday', name: '春节'),
    '2026-02-28': (type: 'workday', name: '春节调休'),
    '2026-04-04': (type: 'holiday', name: '清明节'),
    '2026-04-05': (type: 'holiday', name: '清明节'),
    '2026-04-06': (type: 'holiday', name: '清明节'),
    '2026-04-26': (type: 'workday', name: '劳动节调休'),
    '2026-05-01': (type: 'holiday', name: '劳动节'),
    '2026-05-02': (type: 'holiday', name: '劳动节'),
    '2026-05-03': (type: 'holiday', name: '劳动节'),
    '2026-05-04': (type: 'holiday', name: '劳动节'),
    '2026-05-05': (type: 'holiday', name: '劳动节'),
    '2026-06-19': (type: 'holiday', name: '端午节'),
    '2026-06-20': (type: 'holiday', name: '端午节'),
    '2026-06-21': (type: 'holiday', name: '端午节'),
    '2026-09-19': (type: 'workday', name: '国庆调休'),
    '2026-09-25': (type: 'holiday', name: '中秋节'),
    '2026-09-26': (type: 'holiday', name: '中秋节'),
    '2026-09-27': (type: 'holiday', name: '中秋节'),
    '2026-10-01': (type: 'holiday', name: '国庆节'),
    '2026-10-02': (type: 'holiday', name: '国庆节'),
    '2026-10-03': (type: 'holiday', name: '国庆节'),
    '2026-10-04': (type: 'holiday', name: '国庆节'),
    '2026-10-05': (type: 'holiday', name: '国庆节'),
    '2026-10-06': (type: 'holiday', name: '国庆节'),
    '2026-10-07': (type: 'holiday', name: '国庆节'),
    '2026-10-08': (type: 'holiday', name: '国庆节'),
    '2026-10-10': (type: 'workday', name: '国庆调休'),
  };

  /// YYYY-MM-DD 格式化
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 获取某日期的节假日信息（'YYYY-MM-DD'），无则 null
  static HolidayInfo? getHolidayInfo(String dateStr) {
    final arrangement = arrangements[dateStr];
    if (arrangement != null) {
      final isHoliday = arrangement.type == 'holiday';
      return HolidayInfo(
        type: arrangement.type,
        name: arrangement.name,
        isHoliday: isHoliday,
        isWorkday: arrangement.type == 'workday',
        label: isHoliday ? '休' : '班',
      );
    }
    // 固定日期节日
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final month = int.tryParse(parts[1]) ?? 0;
      final day = int.tryParse(parts[2]) ?? 0;
      for (final f in fixedFestivals) {
        if (f.month == month && f.day == day) {
          return HolidayInfo(
            type: 'festival',
            name: f.name,
            emoji: f.emoji,
            isHoliday: false,
            isWorkday: false,
            label: f.name,
          );
        }
      }
    }
    return null;
  }

  /// 获取即将到来的假期（按名称去重）
  static List<({String date, String name, int daysFromNow})> getUpcomingHolidays(
      int count) {
    final today = DateTime.now();
    final todayStr = _fmt(today);
    final upcoming = <({String date, String name, int daysFromNow})>[];

    final entries = arrangements.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      final dateStr = entry.key;
      final info = entry.value;
      if (info.type != 'holiday' || dateStr.compareTo(todayStr) < 0) continue;
      // 假期第一天：前一天不是 holiday
      final prev = DateTime.parse(dateStr).subtract(const Duration(days: 1));
      final prevStr = _fmt(prev);
      final prevInfo = arrangements[prevStr];
      if (prevInfo != null && prevInfo.type == 'holiday') continue;
      final daysFromNow =
          DateTime.parse(dateStr).difference(today).inDays.ceil();
      upcoming.add((date: dateStr, name: info.name, daysFromNow: daysFromNow));
    }

    // 排序 + 名称去重
    upcoming.sort((a, b) => a.daysFromNow.compareTo(b.daysFromNow));
    final seen = <String>{};
    final unique = <({String date, String name, int daysFromNow})>[];
    for (final item in upcoming) {
      if (seen.add(item.name)) unique.add(item);
      if (unique.length >= count) break;
    }
    return unique;
  }
}
