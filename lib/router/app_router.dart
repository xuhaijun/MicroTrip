import 'package:go_router/go_router.dart';

import '../models/trajectory.dart';
import '../pages/ai/ai_chat_page.dart';
import '../pages/calendar/calendar_page.dart';
import '../pages/city/city_list_page.dart';
import '../pages/discover/discover_page.dart';
import '../pages/food/food_detail_page.dart';
import '../pages/food/food_list_page.dart';
import '../pages/home/home_page.dart';
import '../pages/home/altitude_detail_page.dart';
import '../pages/home/step_detail_page.dart';
import '../pages/map/nearby_map_page.dart';
import '../pages/oneday/oneday_page.dart';
import '../pages/photo/photo_recognition_page.dart';
import '../pages/profile/about_page.dart';
import '../pages/profile/privacy_policy_page.dart';
import '../pages/profile/user_agreement_page.dart';
import '../pages/profile/permission_manage_page.dart';
import '../pages/profile/favorites_page.dart';
import '../pages/profile/login_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/shared/guide_page.dart';
import '../pages/shared/splash_page.dart';
import '../pages/profile/settings_page.dart';
import '../pages/scenery/scenery_detail_page.dart';
import '../pages/scenery/scenery_list_page.dart';
import '../pages/shared/memo_edit_page.dart';
import '../pages/shared/memo_list_page.dart';
import '../pages/shared/weather_detail_page.dart';
import '../pages/trajectory/cloud_trajectory_page.dart';
import '../pages/trajectory/trajectory_detail_page.dart';
import '../pages/trajectory/trajectory_page.dart';
import '../pages/trajectory/trajectory_record_page.dart';
import '../pages/trip/trip_page.dart';
import 'app_shell.dart';

/// ============================================================
/// 路由表（go_router）
/// - initialLocation: /splash（启动加载页，按「是否看过引导 / 登录态」分流）
/// - StatefulShellRoute.indexedStack：底部 4 Tab 独立保活
/// - 启动链路：/splash →（首装）/guide → /home；否则 → /home
/// ============================================================
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/trip',
            builder: (context, state) => const TripPage(),
            routes: [
              GoRoute(
                path: 'memo',
                builder: (context, state) => const MemoListPage(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final extra = state.extra;
                      return MemoEditPage(
                        editId: extra is String ? extra : null,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'trajectory',
                builder: (context, state) => const TrajectoryPage(),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsPage(),
              ),
              GoRoute(
                path: 'cloud-trajectories',
                builder: (context, state) => const CloudTrajectoryPage(),
              ),
              GoRoute(
                path: 'favorites',
                builder: (context, state) => const FavoritesPage(),
              ),
              GoRoute(
                path: 'about',
                builder: (context, state) => const AboutPage(),
              ),
              GoRoute(
                path: 'permissions',
                builder: (context, state) => const PermissionManagePage(),
              ),
            ],
          ),
        ]),
      ],
    ),
    // ============ 法律协议页（顶层全屏，支持从登录/启动页跨导航器作用域跳转） ============
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: '/user-agreement',
      builder: (context, state) => const UserAgreementPage(),
    ),
    // ============ 顶层页面（对应小程序分包页） ============
    GoRoute(
      path: '/city-list',
      builder: (context, state) => const CityListPage(),
    ),
    GoRoute(
      path: '/ai-chat',
      builder: (context, state) => const AiChatPage(),
    ),
    GoRoute(
      path: '/weather-detail',
      builder: (context, state) => const WeatherDetailPage(),
    ),
    // ============ 首页概览卡片详情页 ============
    GoRoute(
      path: '/altitude-detail',
      builder: (context, state) => const AltitudeDetailPage(),
    ),
    GoRoute(
      path: '/step-detail',
      builder: (context, state) => const StepDetailPage(),
    ),
    // ============ Phase 2 新增 ============
    GoRoute(
      path: '/trajectory-record',
      builder: (context, state) => const TrajectoryRecordPage(),
    ),
    GoRoute(
      path: '/trajectory-detail/:id',
      builder: (context, state) {
        // Phase 5：云端历史页通过 extra 传入完整 TrajectoryRecord，
        // 详情页直接渲染（fromCloud 模式），否则按 id 从本地仓库加载
        final extra = state.extra;
        final fromCloud = extra is TrajectoryRecord;
        return TrajectoryDetailPage(
          trajectoryId: state.pathParameters['id']!,
          externalRecord: fromCloud ? extra : null,
          fromCloud: fromCloud,
        );
      },
    ),
    GoRoute(
      path: '/photo-recognition',
      builder: (context, state) => const PhotoRecognitionPage(),
    ),
    // ============ Phase 3 新增 ============
    GoRoute(
      path: '/food',
      builder: (context, state) => const FoodListPage(),
    ),
    GoRoute(
      path: '/food-detail/:id',
      builder: (context, state) => FoodDetailPage(
        foodId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/scenery',
      builder: (context, state) => const SceneryListPage(),
    ),
    GoRoute(
      path: '/scenery-detail/:id',
      builder: (context, state) => SceneryDetailPage(
        sceneryId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/oneday',
      builder: (context, state) => const OneDayPage(),
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) =>
          CalendarPage(initialDate: state.extra as String?),
    ),
    // ============ Phase 4 新增 ============
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginPage(extra: state.extra),
    ),
    // ============ Phase 5 新增：附近探索地图 ============
    GoRoute(
      path: '/nearby',
      builder: (context, state) {
        // 美食/景点详情页「在附近查看 / 导航」通过 extra 带入聚焦坐标
        final extra = state.extra;
        final focus = extra is NearbyFocus ? extra : null;
        return NearbyMapPage(initialFocus: focus);
      },
    ),
    // ============ 启动门控（先于 Tab 壳，独立全屏） ============
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/guide',
      builder: (context, state) => const GuidePage(),
    ),
  ],
);
