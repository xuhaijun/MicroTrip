import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// 各底部 Tab 分支的 Navigator key，由 app_router.dart 绑定到对应的
/// StatefulShellBranch，使 4 个 Tab 各自保有独立的导航栈
/// （go_router 14.x 的 StatefulNavigationShell 未暴露 navigatorKey /
/// branchNavigatorKeys，需要访问分支导航器时只能在此显式持有）。
final List<GlobalKey<NavigatorState>> shellBranchNavigatorKeys = [
  GlobalKey<NavigatorState>(),
  GlobalKey<NavigatorState>(),
  GlobalKey<NavigatorState>(),
  GlobalKey<NavigatorState>(),
];

/// ============================================================
/// 应用外壳：底部导航 + 渐变指示器
/// 迁移自小程序 custom-tab-bar（首页/发现/行程/我的 4 Tab）
///
/// 系统返回键交还给系统默认行为（2026-09-14 按需求移除「是否退出应用」确认框）：
/// - 当前 Tab 还有子页面（如从行程页 push 了万年历）→ 分支导航栈正常 pop 回上一页；
/// - 已在 Tab 根页面 → 由系统直接退出应用，不再弹二次确认。
/// ============================================================
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: AppShadows.card,
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: navigationShell.currentIndex,
            onTap: (i) => navigationShell.goBranch(
              i,
              initialLocation: i == navigationShell.currentIndex,
            ),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.tabInactive,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '首页',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.explore_outlined),
                activeIcon: Icon(Icons.explore),
                label: '发现',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: '行程',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: '我的',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
