/// ============================================================
/// 坐标系转换工具（仅用于 GCJ-02 瓦片源）
/// ============================================================
/// 背景：国内在线瓦片里，**高德 / 腾讯** 使用的是
/// **GCJ-02（国测局火星坐标）** 坐标系；而本 App 所有坐标（GPS 定位、
/// POI、城市、轨迹点）都是 **WGS-84（GPS 原生经纬度）**。
///
/// 若直接用 WGS-84 坐标去叠加 GCJ-02 瓦片，国内会整体偏移几百米
/// （轨迹线、定位点"飘"到马路外）。因此当瓦片源为**高德 / 腾讯**时，
/// 所有「喂给地图显示」的坐标都必须先经 [wgs84ToGcj02] 转换；而
/// 「真实世界距离计算」仍用原始 WGS-84（GCJ-02 非线性，转了距离会偏），切勿混用。
///
/// ⚠️ 当前瓦片源为**天地图（CGCS2000≈WGS-84）**，与 WGS-84 基本重合，
/// 地图层**不调用**本工具（调用反而会反向偏移几百米）。本文件保留，
/// 供切回高德 / 腾讯源时直接复用。天地图无需任何坐标偏移。
///
/// 算法为公开实现的 WGS-84 → GCJ-02（与高德 / 腾讯官方一致）。
/// 来源：公开「火星坐标」转换公式（eviltransform 等），已进入公共领域。
/// ============================================================
library;

import 'dart:math';

import 'package:latlong2/latlong.dart';

const double _kA = 6378245.0; // 长半轴
const double _kEe = 0.00669342162296594323; // 第一偏心率平方

/// WGS-84 经纬度 → GCJ-02 经纬度。
/// [p] 为 WGS-84 坐标，返回可直接喂给高德 / 腾讯瓦片地图的 GCJ-02 坐标。
/// 中国境外不做转换（直接返回原值）。
LatLng wgs84ToGcj02(LatLng p) {
  if (_outOfChina(p.latitude, p.longitude)) return p;
  final dLat = _transformLat(p.longitude - 105.0, p.latitude - 35.0);
  final dLng = _transformLng(p.longitude - 105.0, p.latitude - 35.0);
  final radLat = p.latitude / 180.0 * pi;
  var magic = sin(radLat);
  magic = 1 - _kEe * magic * magic;
  final sqrtMagic = sqrt(magic);
  final latOffset =
      (dLat * 180.0) / ((_kA * (1 - _kEe)) / (magic * sqrtMagic) * pi);
  final lngOffset =
      (dLng * 180.0) / (_kA / sqrtMagic * cos(radLat) * pi);
  return LatLng(p.latitude + latOffset, p.longitude + lngOffset);
}

/// 批量转换（轨迹点等场景）。
List<LatLng> wgs84ToGcj02List(List<LatLng> points) =>
    points.map(wgs84ToGcj02).toList();

bool _outOfChina(double lat, double lng) {
  if (lng < 72.004 || lng > 137.8347) return true;
  if (lat < 0.8293 || lat > 55.8271) return true;
  return false;
}

double _transformLat(double x, double y) {
  var ret = -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
  ret +=
      (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
  return ret;
}

double _transformLng(double x, double y) {
  var ret = 300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * sqrt(x.abs());
  ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
  ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
  ret +=
      (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
  return ret;
}
