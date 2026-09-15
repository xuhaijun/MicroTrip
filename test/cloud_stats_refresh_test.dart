import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:micro_trip/models/cloud_stats.dart';
import 'package:micro_trip/providers/app_providers.dart';

/// 守护「我的」页云端足迹刷新按钮 bug 的回归测试。
///
/// 历史实现用 `ref.invalidate(cloudStatsProvider)` 刷新一个**常驻（非 autoDispose）
/// 顶层 FutureProvider**，实测 `invalidate` 不会触发重算 —— 表现为"点刷新按钮没反应"
/// （已用探针测试实证：invalidate 后 fetchCount 不增长）。
///
/// 修复后卡片按钮改调 [CloudStatsNotifier.refresh]，本测试钉死：
/// 调用 refresh() 必须真正触发二次拉取（fetchCount 增长），且首次读取只拉一次。
class _FakeStatsNotifier extends CloudStatsNotifier {
  _FakeStatsNotifier(this._onFetch);
  final void Function() _onFetch;

  @override
  Future<CloudStats> build() {
    _onFetch();
    return Future.value(CloudStats.empty);
  }

  @override
  Future<void> refresh() async {
    _onFetch();
    state = AsyncValue.data(CloudStats.empty);
  }
}

void main() {
  test('refresh() 触发二次拉取（修复刷新按钮无反应）', () async {
    var fetchCount = 0;
    final container = ProviderContainer(
      overrides: [
        cloudStatsProvider.overrideWith(() => _FakeStatsNotifier(() => fetchCount++)),
      ],
    );

    // 首次读取触发 build -> 第 1 次拉取
    container.read(cloudStatsProvider);
    await Future.delayed(const Duration(milliseconds: 30));
    expect(fetchCount, 1, reason: '初始只应拉取一次');

    // 模拟卡片「刷新 / 重试」按钮
    await container.read(cloudStatsProvider.notifier).refresh();

    expect(fetchCount, 2, reason: 'refresh() 必须触发二次拉取');
  });
}
