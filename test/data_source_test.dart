import 'package:flutter_test/flutter_test.dart';

import 'package:micro_trip/models/scenery_item.dart';
import 'package:micro_trip/models/food_item.dart';
import 'package:micro_trip/services/scenery_service.dart';
import 'package:micro_trip/services/food_service.dart';

// 注：本文件为纯 Dart 测试（import flutter_test，其已 re-export package:test 的 test/expect/group 等），
// 仅覆盖「模型 fromJson + 列表处理」等
// 不依赖 Flutter 绑定的逻辑。涉及 DataConfig/AuthService（需 shared_preferences）的
// 双源拉取逻辑见 app_providers / widget 层，需 flutter test 联网运行。

/// 验证「服务端 JSON ↔ 客户端模型」契约，以及列表筛选/标签派生逻辑。
/// 纯 Dart 测试（不依赖 Flutter 绑定），可在离线环境用 `dart test` 运行。
void main() {
  group('SceneryItem.fromJson（服务端 → 客户端）', () {
    test('字段映射正确', () {
      final item = SceneryItem.fromJson(<String, dynamic>{
        'id': 3,
        'name': '山顶观景台',
        'image': '🏔️',
        'rating': 4.9,
        'ticket': '50元',
        'duration': '3-4小时',
        'openTime': '06:00 - 20:00',
        'tag': '日出',
        'tags': <String>['日出', '登高', '必打卡'],
        'desc': '登高望远',
        'address': '城郊山风景区山顶',
        'latitude': 30.58,
        'longitude': 104.08,
      });
      expect(item.id, 3);
      expect(item.name, '山顶观景台');
      expect(item.rating, 4.9);
      expect(item.ratingText, '4.9');
      expect(item.tags, <String>['日出', '登高', '必打卡']);
      expect(item.latitude, 30.58);
      expect(item.longitude, 104.08);
    });

    test('缺失字段有默认值', () {
      final item = SceneryItem.fromJson(<String, dynamic>{'id': 1, 'name': 'x'});
      expect(item.rating, 0);
      expect(item.tags, isEmpty);
      expect(item.image, '');
    });
  });

  group('FoodItem.fromJson（服务端 → 客户端）', () {
    test('字段映射正确', () {
      final item = FoodItem.fromJson(<String, dynamic>{
        'id': 6,
        'name': '成都麻辣火锅',
        'image': '🌶️',
        'rating': 4.8,
        'price': '80-180元',
        'tag': '必吃',
        'tags': <String>['必吃', '聚餐', '香辣'],
        'desc': '牛油锅底',
        'tips': '建议点半份拼盘',
      });
      expect(item.id, 6);
      expect(item.rating, 4.8);
      expect(item.tips, '建议点半份拼盘');
      expect(item.price, '80-180元');
    });
  });

  group('SceneryService 列表处理', () {
    final items = <SceneryItem>[
      SceneryItem(id: 1, name: '博物馆', tag: '文化', desc: '历史', rating: 4.7, image: '🏛️'),
      SceneryItem(id: 2, name: '公园', tag: '休闲', desc: '散步', rating: 4.6, image: '🌳'),
      SceneryItem(id: 3, name: '观景台', tag: '日出', desc: '登高望远', rating: 4.9, image: '🏔️'),
    ];

    test('deriveTags 前置「全部」且去重', () {
      final tags = SceneryService.deriveTags(items);
      expect(tags.first, '全部');
      expect(tags, contains('文化'));
      expect(tags.length, 4); // 全部 + 文化 + 休闲 + 日出
    });

    test('filterList 关键词', () {
      final r = SceneryService.filterList(items, keyword: '登');
      expect(r.length, 1);
      expect(r.first.name, '观景台');
    });

    test('filterList 标签', () {
      final r = SceneryService.filterList(items, tag: '文化');
      expect(r.length, 1);
      expect(r.first.id, 1);
    });

    test('filterList 全部返回全部', () {
      expect(SceneryService.filterList(items, tag: '全部').length, 3);
    });
  });

  group('FoodService 列表处理', () {
    final items = <FoodItem>[
      FoodItem(id: 1, name: '小面', tag: '必吃', desc: '早餐', rating: 4.8, image: '🍜', price: '15元'),
      FoodItem(id: 2, name: '砂锅', tag: '人气', desc: '正餐', rating: 4.7, image: '🥘', price: '40元'),
    ];

    test('deriveTags', () {
      expect(FoodService.deriveTags(items), <String>['全部', '必吃', '人气']);
    });

    test('filterList 关键词', () {
      final r = FoodService.filterList(items, keyword: '早');
      expect(r.first.id, 1);
    });

    test('filterList 标签', () {
      final r = FoodService.filterList(items, tag: '人气');
      expect(r.first.id, 2);
    });
  });

  group('NearbyScenery.fromJson（周边推荐）', () {
    test('字段映射正确', () {
      final nb = NearbyScenery.fromJson(<String, dynamic>{
        'id': 7,
        'name': '文创园·旧厂房',
        'image': '📚',
        'rating': 4.5,
        'distance': '1.2km',
      });
      expect(nb.id, 7);
      expect(nb.name, '文创园·旧厂房');
      expect(nb.rating, 4.5);
      expect(nb.distance, '1.2km');
      expect(nb.image, '📚');
    });

    test('缺失字段有默认值', () {
      final nb = NearbyScenery.fromJson(<String, dynamic>{'id': 1, 'name': 'x'});
      expect(nb.rating, 0);
      expect(nb.distance, '');
      expect(nb.image, '');
    });
  });

  group('FoodShop.fromJson（推荐店铺 /food/shops）', () {
    test('字段映射正确', () {
      final shop = FoodShop.fromJson(<String, dynamic>{
        'id': 2,
        'name': '巷子深处·小面专门店',
        'rating': 4.6,
        'distance': '1.2km',
        'avgPrice': '30元/人',
        'address': '文庙巷 12 号',
        'latitude': 30.569,
        'longitude': 104.073,
      });
      expect(shop.id, 2);
      expect(shop.name, '巷子深处·小面专门店');
      expect(shop.rating, 4.6);
      expect(shop.distance, '1.2km');
      expect(shop.avgPrice, '30元/人');
      expect(shop.address, '文庙巷 12 号');
      expect(shop.latitude, 30.569);
      expect(shop.longitude, 104.073);
    });

    test('缺失字段有默认值', () {
      final shop = FoodShop.fromJson(<String, dynamic>{'id': 1, 'name': '店'});
      expect(shop.rating, 0);
      expect(shop.distance, '');
      expect(shop.latitude, 0);
      expect(shop.longitude, 0);
    });

    test('与服务端 /food/shops 形状对齐（city 注入后字段稳定）', () {
      // 服务端 shops 接口返回 list 中每项字段：id,name,rating,distance,avgPrice,address,latitude,longitude
      final json = <String, dynamic>{
        'id': 3,
        'name': '深夜食堂·火锅',
        'rating': 4.5,
        'distance': '2.5km',
        'avgPrice': '22元/人',
        'address': '滨江夜市 A 区 08 号',
        'latitude': 30.58,
        'longitude': 104.061,
      };
      final shop = FoodShop.fromJson(json);
      // 校验所有字段都能稳定解析，避免接口字段变更导致崩溃（合同对齐）
      expect([
        shop.id, shop.name, shop.rating, shop.distance, shop.avgPrice,
        shop.address, shop.latitude, shop.longitude,
      ], <Object>[
        3, '深夜食堂·火锅', 4.5, '2.5km', '22元/人',
        '滨江夜市 A 区 08 号', 30.58, 104.061,
      ]);
    });
  });
}
