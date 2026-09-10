import 'package:flutter/material.dart';

import '../shared/widgets/common_widgets.dart';

/// ============================================================
/// 轨迹页（对应小程序 subpackages/travel/pages/trajectory）
/// Phase 1 为历史列表 + 能力预告；Phase 2 上线 GPS 实时录制、
/// 停留点检测、距离/时长统计与截图分享。
/// ============================================================
class TrajectoryPage extends StatelessWidget {
  const TrajectoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('出行轨迹')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rocket_launch_outlined,
                        size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('轨迹录制即将上线',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Phase 2 将基于 geolocator 实现：\n'
                  '· GPS 实时轨迹记录（后台保活）\n'
                  '· 停留点自动检测（半径 100m / 时长 10min）\n'
                  '· 距离 / 时长 / 爬升统计\n'
                  '· 轨迹地图绘制与截图分享',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.9), height: 1.8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AppCard(
            child: EmptyState(
              icon: Icons.route_outlined,
              text: '暂无历史轨迹',
              hint: '录制功能上线后这里会展示你的行程',
            ),
          ),
        ],
      ),
    );
  }
}
