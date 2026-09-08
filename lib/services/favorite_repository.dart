import '../core/storage/app_storage.dart';
import '../models/favorite_item.dart';

/// ============================================================
/// 收藏仓库（美食 / 景点）
/// 对应小程序 travel_favoriteFood / travel_favoriteScenery。
/// ============================================================
class FavoriteRepository {
  FavoriteRepository._();

  static String _key(FavoriteType type) =>
      type == FavoriteType.food ? AppStorage.kFavoriteFood : AppStorage.kFavoriteScenery;

  static List<FavoriteItem> _decode(dynamic raw, FavoriteType type) {
    if (raw is List) {
      return raw
          .map((e) => FavoriteItem.fromMap(Map<String, dynamic>.from(e as Map),
              type: type))
          .toList();
    }
    return [];
  }

  static Future<List<FavoriteItem>> loadAll(FavoriteType type) async =>
      _decode(AppStorage.getObject(_key(type), defaultValue: []), type);

  static Future<void> save(FavoriteItem item) async {
    await AppStorage.appendToList(_key(item.type), item.toMap());
  }

  static Future<void> remove(FavoriteType type, String id) async {
    await AppStorage.removeFromList(_key(type), id);
  }

  static Future<bool> isFavorite(FavoriteType type, String id) async {
    final list = await loadAll(type);
    return list.any((e) => e.id == id);
  }
}
