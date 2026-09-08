import '../core/storage/app_storage.dart';
import '../models/memo_item.dart';

/// ============================================================
/// 备忘仓库
/// 对应小程序 travel_memoList 的 CRUD 操作。
/// 存储即数据源（无后端阶段），Phase 4 可替换为远程 API。
/// ============================================================
class MemoRepository {
  MemoRepository._();

  static List<MemoItem> _decode(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => MemoItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// 全部备忘（新的在前）
  static Future<List<MemoItem>> loadAll() async =>
      _decode(AppStorage.getObject(AppStorage.kMemoList, defaultValue: []));

  static Future<void> save(MemoItem item) async {
    await AppStorage.appendToList(AppStorage.kMemoList, item.toMap());
  }

  static Future<void> remove(String id) async {
    await AppStorage.removeFromList(AppStorage.kMemoList, id);
  }

  static Future<void> toggleComplete(String id, bool completed) async {
    await AppStorage.updateListItem(
        AppStorage.kMemoList, id, {'completed': completed});
  }
}
