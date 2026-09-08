import 'package:flutter/material.dart';

/// ============================================================
/// 设计令牌（Design Tokens）
/// 迁移自微信小程序 app.wxss 中的 CSS 变量体系，
/// 全 APP 的颜色 / 圆角 / 阴影 / 间距统一从这里引用，禁止页面硬编码。
/// ============================================================
class AppColors {
  AppColors._();

  /// 主色：科技蓝（品牌色）
  static const Color primary = Color(0xFF0077B6);

  /// 主色渐变终点：浅湖蓝
  static const Color primaryLight = Color(0xFF00B4D8);

  /// 主色渐变（导航栏 / 卡片 / 按钮统一渐变）
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  /// 带透明度的主色渐变（浅色背景占位等场景）
  static LinearGradient primaryGradientWith(double alpha) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primary.withValues(alpha: alpha),
          primaryLight.withValues(alpha: alpha),
        ],
      );

  /// 强调色：暖橙（活力点缀，如「不宜出行」提示）
  static const Color accent = Color(0xFFFF9F43);

  /// 页面背景
  static const Color background = Color(0xFFF7F8FA);

  /// 卡片背景
  static const Color card = Color(0xFFFFFFFF);

  /// 主文字
  static const Color textPrimary = Color(0xFF1A1A2E);

  /// 次文字
  static const Color textSecondary = Color(0xFF6B7280);

  /// 辅助文字（提示 / 占位）
  static const Color textHint = Color(0xFF9CA3AF);

  /// 第三级文字（占位 / 空状态图标色）
  static const Color textTertiary = Color(0xFFB0B4BC);

  /// 深色文字（等同 textPrimary，语义化别名）
  static const Color textDark = textPrimary;

  /// 分隔线
  static const Color divider = Color(0xFFEEEEF2);

  /// 边框（等同 divider，语义化别名）
  static const Color border = divider;

  /// 卡片表面（等同 card，语义化别名）
  static const Color surface = card;

  /// Tab 未选中
  static const Color tabInactive = Color(0xFF9A9AAB);

  /// 成功 / 安全
  static const Color success = Color(0xFF2ECC71);

  /// 警告
  static const Color warning = Color(0xFFFF9F43);

  /// 危险 / 删除
  static const Color danger = Color(0xFFE74C3C);
}

/// 圆角体系
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double round = 999;
}

/// 阴影体系（卡片统一浅阴影）
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x140077B6), // 主色 8% 透明度
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

/// 间距体系（8 的倍数栅格）
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// ============================================================
/// 全局主题
/// ============================================================
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        dividerColor: AppColors.divider,
        // 中文界面字体回退链由系统处理，无需强制 fontFamily
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          bodyLarge: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          bodySmall: TextStyle(fontSize: 12, color: AppColors.textHint),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      );
}
