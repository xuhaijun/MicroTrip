import 'package:flutter/material.dart';

/// ============================================================
/// 动效组件库（Phase 5 UI 动效升级）
///
/// 三个轻量通用动效组件，全部基于隐式动画（无需 AnimationController）：
///  - FadeSlideIn   渐隐 + 上滑进场（支持延迟，用于交错排列）
///  - AnimatedCounter 数字滚动（数值变化时平滑过渡）
///  - PressableScale 按压缩放反馈（卡片/按钮触摸微缩）
///
/// 设计原则：
///  - 动效时长 240~420ms，符合 Material motion 规范的"自然节奏"
///  - Curves.easeOutCubic：快速起步、缓慢停稳，观感干脆不拖沓
///  - 零侵入：包一层即可生效，不影响原有布局与逻辑
/// ============================================================

/// 动效默认曲线（快速起步、缓慢停稳）
const Curve kEaseOutCubic = Cubic(0.22, 1, 0.36, 1);

/// ------------------------------------------------------------
/// 渐隐 + 位移进场动画
///
/// [delay] 用于交错（staggered）排列：列表中每项依次延迟 ~60ms，
/// 形成从上到下的波浪式进场效果。
///
/// ```dart
/// FadeSlideIn(child: WeatherCard(...))                       // 单个
/// FadeSlideIn(delay: 60 * i, child: Item(...))               // 交错
/// ```
/// ------------------------------------------------------------
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = 0,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 24),
    this.curve = kEaseOutCubic,
  });

  /// 要包裹的子组件
  final Widget child;

  /// 延迟进场时间（毫秒）；交错动画时逐项递增
  final int delay;

  /// 动画总时长
  final Duration duration;

  /// 起始位移偏移（默认从下方 24 逻辑像素滑入）
  final Offset offset;

  /// 动画曲线
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    // TweenChain：先等延迟，再执行曲线动画
    _animation = CurvedAnimation(parent: _ctrl, curve: widget.curve);
    // 延迟后触发（首帧渲染完成，避免动画被首帧构建吞掉）
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // 当前位移量：动画开始 = offset，结束 = Offset.zero
        final slide = widget.offset * (1 - _animation.value);
        final transformed = Opacity(
          opacity: _animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: slide,
            child: child,
          ),
        );
        // 【越界黄条修复】Transform.translate 不会扩展自身边界，进场位移期间
        // 子组件底部会画到盒子外，Debug 模式触发 "overflowed by X pixels"。
        // 仅在“仍有位移”（动画进行中 / 延迟未启动）时 ClipRect 裁掉越界部分；
        // 位移归零（动画结束）后立即移除裁剪，确保卡片阴影外延不被切掉。
        if (slide.dx.abs() < 0.01 && slide.dy.abs() < 0.01) {
          return transformed;
        }
        return ClipRect(child: transformed);
      },
      child: widget.child,
    );
  }
}

/// ------------------------------------------------------------
/// 数字滚动动画
///
/// 数值变化时从旧值平滑滚到新值（TweenAnimationBuilder 实现，
/// 自动感知 [value] 变化并重放动画，无需手动管理 Controller）。
///
/// [formatter] 自定义显示格式（保留小数、单位等）。
///
/// ```dart
/// AnimatedCounter(value: distance, formatter: (v) => v.toStringAsFixed(1))
/// ```
/// ------------------------------------------------------------
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = const Duration(milliseconds: 480),
    this.style,
    this.maxLines,
    this.overflow,
    this.curve = kEaseOutCubic,
  });

  /// 目标数值（int / double 均可）
  final num value;

  /// 显示格式化函数
  final String Function(num) formatter;

  /// 动画时长
  final Duration duration;

  /// 文本样式
  final TextStyle? style;

  /// 最大行数（默认不限制，可能撑破父级 Row，需配合 overflow）
  final int? maxLines;

  /// 超出处理（如 TextOverflow.ellipsis）
  final TextOverflow? overflow;

  /// 动画曲线
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<num>(
      tween: Tween(end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(
        formatter(v),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}

/// ------------------------------------------------------------
/// 按压缩放反馈
///
/// 手指按下时轻微缩小（默认 0.97），松开回弹——
/// 给可点击卡片/宫格项一个"按得下去"的物理感。
/// 用 Listener 直接监听 Pointer 事件，不抢占点击手势。
/// ------------------------------------------------------------
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;

  /// 按下时的缩放比例
  final double pressedScale;

  /// 过渡时长
  final Duration duration;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      // PointerDown/Up 不参与手势竞技场，与 onTap 互不干扰
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
