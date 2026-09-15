import 'package:flutter_test/flutter_test.dart';
import 'package:micro_trip/services/holiday_data.dart';

/// 节假日 / 调休数据正确性契约测试。
///
/// 数据依据《国务院办公厅关于2026年部分节假日安排的通知》(2025-11-04) 核对。
/// 这些日期直接决定万年历「休 / 班」角标，一旦错标用户会误判哪天要上班，
/// 因此把关键日期钉成断言，避免再次被「迁移自小程序」的脏数据悄悄改回去。
void main() {
  group('2026 放假 / 调休（对照国务院通知）', () {
    test('9-19 是普通周六，不该标「班」（用户反馈点）', () {
      // 2026-09-19 既不是法定放假也不是调休补班，不应出现角标。
      expect(HolidayData.getHolidayInfo('2026-09-19'), isNull,
          reason: '9-19 是普通周六，曾被误标为国庆调休补班；'
              '官方国庆补班是 9-20(周日)、10-10(周六');
    });

    test('国庆调休补班应为 9-20 与 10-10', () {
      final a = HolidayData.getHolidayInfo('2026-09-20')!;
      expect(a.isWorkday, isTrue);
      expect(a.label, '班');
      expect(a.name, '国庆调休');

      final b = HolidayData.getHolidayInfo('2026-10-10')!;
      expect(b.isWorkday, isTrue);
      expect(b.label, '班');
      expect(b.name, '国庆调休');
    });

    test('国庆节放假 10-1 ~ 10-7，10-8 不是放假', () {
      for (var d = 1; d <= 7; d++) {
        final info = HolidayData.getHolidayInfo('2026-10-${d.toString().padLeft(2, '0')}')!;
        expect(info.isHoliday, isTrue, reason: '10-$d 应放假');
        expect(info.label, '休');
      }
      // 10-8 是国庆后首个工作日，不应标「休」
      expect(HolidayData.getHolidayInfo('2026-10-08'), isNull,
          reason: '国庆放假 10-1~7 共7天，10-8 是普通工作日，曾被多标为休');
    });

    test('春节放假 2-15 ~ 2-23，补班 2-14 与 2-28', () {
      // 2-15 / 2-16 是最早被错标成「班」的两天，必须放假
      for (final d in ['2026-02-15', '2026-02-16', '2026-02-17', '2026-02-23']) {
        final info = HolidayData.getHolidayInfo(d)!;
        expect(info.isHoliday, isTrue, reason: '$d 应为春节放假');
        expect(info.label, '休');
      }
      final makeup1 = HolidayData.getHolidayInfo('2026-02-14')!;
      expect(makeup1.isWorkday, isTrue, reason: '2-14(六) 是春节调休补班');
      final makeup2 = HolidayData.getHolidayInfo('2026-02-28')!;
      expect(makeup2.isWorkday, isTrue, reason: '2-28(六) 是春节调休补班');
    });

    test('劳动节放假 5-1 ~ 5-5，补班 5-9（不是 4-26）', () {
      for (var d = 1; d <= 5; d++) {
        final info = HolidayData.getHolidayInfo('2026-05-${d.toString().padLeft(2, '0')}')!;
        expect(info.isHoliday, isTrue, reason: '5-$d 应放假');
      }
      expect(HolidayData.getHolidayInfo('2026-04-26'), isNull,
          reason: '4-26 曾被误标为劳动节调休；官方补班是 5-9');
      final makeup = HolidayData.getHolidayInfo('2026-05-09')!;
      expect(makeup.isWorkday, isTrue);
      expect(makeup.label, '班');
    });

    test('元旦放假 1-1 ~ 1-3，补班 1-4', () {
      for (var d = 1; d <= 3; d++) {
        final info = HolidayData.getHolidayInfo('2026-01-${d.toString().padLeft(2, '0')}')!;
        expect(info.isHoliday, isTrue);
      }
      final makeup = HolidayData.getHolidayInfo('2026-01-04')!;
      expect(makeup.isWorkday, isTrue, reason: '1-4(日) 是元旦调休补班，曾被漏标');
    });

    test('清明 4-4~6、端午 6-19~21、中秋 9-25~27 放假且无补班', () {
      for (final d in [
        '2026-04-04', '2026-04-05', '2026-04-06',
        '2026-06-19', '2026-06-20', '2026-06-21',
        '2026-09-25', '2026-09-26', '2026-09-27',
      ]) {
        final info = HolidayData.getHolidayInfo(d)!;
        expect(info.isHoliday, isTrue, reason: '$d 应放假');
      }
    });
  });

  group('数据自洽性', () {
    test('arrangements 中 holiday 标「休」、workday 标「班」，且类型互斥', () {
      for (final entry in HolidayData.arrangements.entries) {
        final info = HolidayData.getHolidayInfo(entry.key)!;
        if (info.isHoliday) {
          expect(info.label, '休', reason: '${entry.key} 放假应标「休」');
          expect(info.isWorkday, isFalse);
        } else if (info.isWorkday) {
          expect(info.label, '班', reason: '${entry.key} 补班应标「班」');
          expect(info.isHoliday, isFalse);
        }
      }
    });
  });
}
