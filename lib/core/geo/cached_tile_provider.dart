/// ============================================================
/// 带磁盘缓存的瓦片 Provider（零新依赖）
/// ============================================================
/// 基于 flutter_map 自带的 [NetworkTileProvider] / [MapNetworkImageProvider]
/// 逻辑改写：在原网络加载之外，增加「磁盘命中即本地解码、未命中则落盘」的分支。
///
/// 作用：
/// - 弱网/断网时，曾浏览过的区域瓦片直接读本地文件，地图仍可显示、且重复加载更快；
/// - 离线（无网看新区域）仍需预打包瓦片（MBTiles），本 Provider 不解决该场景。
///
/// 仅依赖项目已有依赖（flutter_map / http / path_provider / dart:io），
/// 不引入 flutter_map_cache 等额外包，避免 pub 依赖冲突。
///
/// 用法：
///   final p = CachedNetworkTileProvider(silenceExceptions: true);
///   // initState 里异步拿到缓存目录后：
///   p.setCacheDir('${(await getTemporaryDirectory()).path}/map_tiles');
///   TileLayer(urlTemplate: ..., tileProvider: p)
/// 未调用 setCacheDir 时自动降级为纯网络（与 NetworkTileProvider 行为一致）。
/// ============================================================
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart';
import 'package:http/retry.dart';

/// 带磁盘缓存的网络瓦片 Provider。
class CachedNetworkTileProvider extends TileProvider {
  CachedNetworkTileProvider({
    this.silenceExceptions = false,
    BaseClient? httpClient,
  }) : _httpClient = httpClient ?? RetryClient(Client());

  final bool silenceExceptions;
  final BaseClient _httpClient;

  /// 磁盘缓存根目录；为 null 时降级为纯网络（不读写磁盘）。
  String? cacheDir;

  /// 在拿到缓存目录（如 getTemporaryDirectory）后调用，开启磁盘缓存。
  void setCacheDir(String path) => cacheDir = path;

  final _tilesInProgress = HashMap<TileCoordinates, Completer<void>>();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedMapImageProvider(
        url: getTileUrl(coordinates, options),
        fallbackUrl: getTileFallbackUrl(coordinates, options),
        headers: headers,
        httpClient: _httpClient,
        silenceExceptions: silenceExceptions,
        cacheDir: cacheDir,
        startedLoading: () => _tilesInProgress[coordinates] = Completer(),
        finishedLoadingBytes: () {
          _tilesInProgress[coordinates]?.complete();
          _tilesInProgress.remove(coordinates);
        },
      );

  @override
  Future<void> dispose() async {
    if (_tilesInProgress.isNotEmpty) {
      await Future.wait(_tilesInProgress.values.map((c) => c.future));
    }
    _httpClient.close();
    super.dispose();
  }
}

/// 单张瓦片的 ImageProvider：优先磁盘缓存，未命中走网络并落盘。
@immutable
class CachedMapImageProvider extends ImageProvider<CachedMapImageProvider> {
  final String url;
  final String? fallbackUrl;
  final Map<String, String> headers;
  final BaseClient httpClient;
  final bool silenceExceptions;
  final String? cacheDir;
  final void Function() startedLoading;
  final void Function() finishedLoadingBytes;

  const CachedMapImageProvider({
    required this.url,
    required this.fallbackUrl,
    required this.headers,
    required this.httpClient,
    required this.silenceExceptions,
    required this.cacheDir,
    required this.startedLoading,
    required this.finishedLoadingBytes,
  });

  @override
  ImageStreamCompleter loadImage(
    CachedMapImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      MultiFrameImageStreamCompleter(
        codec: _load(key, decode),
        scale: 1,
        debugLabel: url,
        informationCollector: () => [
          DiagnosticsProperty('URL', url),
          DiagnosticsProperty('Fallback URL', fallbackUrl),
          DiagnosticsProperty('Current provider', key),
        ],
      );

  Future<Codec> _load(
    CachedMapImageProvider key,
    ImageDecoderCallback decode, {
    bool useFallback = false,
  }) async {
    startedLoading();
    final target = useFallback ? (fallbackUrl ?? '') : url;
    final file =
        cacheDir != null ? File('$cacheDir/${_cacheFileName(target)}') : null;

    // 1) 磁盘命中：直接本地解码，零网络（弱网/断网友好）
    if (file != null && file.existsSync()) {
      try {
        final bytes = file.readAsBytesSync();
        // 当前 Flutter 的 ImageDecoderCallback 接收 ImmutableBuffer，
        // 需用 ImmutableBuffer.fromUint8List（返回 Future）await 转换。
        final buffer = await ImmutableBuffer.fromUint8List(bytes);
        final codec = await decode(buffer);
        finishedLoadingBytes();
        return codec;
      } catch (_) {
        // 缓存文件损坏，继续走网络分支
      }
    }

    // 2) 网络拉取；成功后落盘（best-effort，不阻塞解码）
    try {
      final bytes =
          await httpClient.readBytes(Uri.parse(target), headers: headers);
      if (file != null) unawaited(_save(file, bytes));
      final buffer = await ImmutableBuffer.fromUint8List(bytes);
      final codec = await decode(buffer);
      finishedLoadingBytes();
      return codec;
    } on Exception {
      // 网络/解码失败：从缓存移除该 key，必要时回退 fallbackUrl 或透明图
      scheduleMicrotask(
          () => PaintingBinding.instance.imageCache.evict(key));
      if (useFallback || fallbackUrl == null) {
        if (!silenceExceptions) rethrow;
        final buffer =
            await ImmutableBuffer.fromUint8List(TileProvider.transparentImage);
        return decode(buffer);
      }
      return _load(key, decode, useFallback: true);
    }
  }

  Future<void> _save(File file, Uint8List bytes) async {
    try {
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
    } catch (_) {
      // 忽略缓存写入失败（磁盘满 / 权限等），不影响地图显示
    }
  }

  /// URL → 安全文件名（Dart VM hashCode 为 64 位，碰撞可忽略）
  String _cacheFileName(String u) => '${u.hashCode.abs()}.png';

  @override
  SynchronousFuture<CachedMapImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedMapImageProvider &&
          fallbackUrl == null &&
          url == other.url);

  @override
  int get hashCode => Object.hashAll([url, if (fallbackUrl != null) fallbackUrl]);
}
