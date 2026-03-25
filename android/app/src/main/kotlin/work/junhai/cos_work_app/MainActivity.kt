package work.junhai.cos_work_app

import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "work.junhai.cos_work_app/webview_cookies",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setCookie" -> {
                    val url = call.argument<String>("url")
                    val value = call.argument<String>("value")
                    if (url == null || value == null) {
                        result.error("bad_args", "需要 url 与 value", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val cm = CookieManager.getInstance()
                        cm.setAcceptCookie(true)
                        cm.setCookie(url, value)
                        cm.flush()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("set_cookie_failed", e.message, null)
                    }
                }
                "clearAllCookies" -> {
                    try {
                        val cm = CookieManager.getInstance()
                        cm.removeAllCookies { _ ->
                            cm.flush()
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("clear_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
