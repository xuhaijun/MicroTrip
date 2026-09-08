import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// ============================================================
/// 开发期溢出定位器（仅 debug 生效，release 自动跳过，零开销）。
///
/// 痛点：设备端出现黄色/黑色溢出条时，控制台虽有 file:line，但常被日志淹没；
/// 而且某些溢出（如 IndexedStack 中 offstage 分支、交互态浮层、长文案态）
/// 难以定位到具体 widget。本工具在捕获到 overflow 类 FlutterError 时，
/// 主动遍历整棵渲染树，找出【所有真正发生溢出的 RenderFlex】，
/// 并打印其对应 widget 的祖先链，让你一眼看到「是哪个页面 / 哪个 Row/Column 溢出了」。
///
/// 用法：在 main() 中、runApp 之前调用一次 installOverflowLocator() 即可。
/// ============================================================

void installOverflowLocator() {
  if (!kDebugMode) return; // release 构建完全不安装，无任何副作用
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      _dumpOverflowWidgetChains();
    }
    original?.call(details);
  };
}

DateTime? _lastDump;

void _dumpOverflowWidgetChains() {
  // 节流：同一类溢出在短时间内可能反复触发，避免刷屏
  final now = DateTime.now();
  if (_lastDump != null && now.difference(_lastDump!).inMilliseconds < 1500) {
    return;
  }
  _lastDump = now;

  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return;

  final chains = <String>[];
  _collectOverflow(root, <String>[], chains);
  if (chains.isEmpty) return;

  final buffer = StringBuffer();
  buffer.writeln('\n═══════════ 🔍 OVERFLOW LOCATOR（开发期溢出定位器）═══════════');
  buffer.writeln('检测到 ${chains.length} 处 RenderFlex 溢出，widget 祖先链如下：');
  for (final c in chains) {
    buffer.writeln(c);
  }
  buffer.writeln('════════════════════════════════════════════════════════════');
  debugPrint(buffer.toString());
}

/// 递归遍历整棵 widget 树：向下传递「从根到当前」的祖先链（避免访问 @protected 的 parent），
/// 当某个元素的 renderObject 是真正溢出的 RenderFlex 时，记录其祖先链。
void _collectOverflow(Element element, List<String> path, List<String> chains) {
  final next = <String>[...path, _widgetLabel(element.widget)];

  final renderObject = element.findRenderObject();
  if (renderObject is RenderFlex && renderObject.hasSize) {
    if (_isOverflowing(renderObject)) {
      chains.add('  ↳ ${next.reversed.join(' → ')}');
    }
  }

  element.visitChildElements((child) => _collectOverflow(child, next, chains));
}

/// 通过 RenderFlex 子节点的 offset + size 是否超出父尺寸，判定是否真溢出
/// （RenderFlex 的 _overflow 是私有字段，这里用几何关系等价判定，稳定可靠）。
bool _isOverflowing(RenderFlex flex) {
  final size = flex.size;
  RenderBox? child = flex.firstChild;
  while (child != null) {
    final pd = child.parentData;
    if (pd is FlexParentData) {
      if (flex.direction == Axis.horizontal) {
        if (pd.offset.dx + child.size.width > size.width + 0.5) return true;
        if (pd.offset.dy < -0.5 ||
            pd.offset.dy + child.size.height > size.height + 0.5) {
          return true;
        }
      } else {
        if (pd.offset.dy + child.size.height > size.height + 0.5) return true;
        if (pd.offset.dx < -0.5 ||
            pd.offset.dx + child.size.width > size.width + 0.5) {
          return true;
        }
      }
    }
    child = flex.childAfter(child);
  }
  return false;
}

String _widgetLabel(Widget widget) {
  final key = widget.key?.toString() ?? '';
  return key.isEmpty ? '${widget.runtimeType}' : '${widget.runtimeType}($key)';
}
