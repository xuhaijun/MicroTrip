package com.xuhai.micro_trip

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    /// 关于页「去评分」：Dart 侧通过此通道请求原生唤起应用市场。
    /// market:// 会打开设备默认应用商店（渠道决定具体是哪家），未安装则抛异常回退提示。
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.xuhai.micro_trip/market",
        ).setMethodCallHandler { call, result ->
            if (call.method == "openMarket") {
                val uri = call.argument<String>("uri")
                if (uri.isNullOrEmpty()) {
                    result.error("INVALID_ARG", "uri is required", null)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(uri)))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
