package com.parentalcare.parentalCareApp

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "critical_alerts"
    private var pendingRoute: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRinging" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        val intent = Intent(this, CriticalAlertRingingService::class.java).apply {
                            action = CriticalAlertRingingService.ACTION_START
                            putExtra(CriticalAlertRingingService.EXTRA_ALERT_ID, args["alertId"]?.toString())
                            putExtra(CriticalAlertRingingService.EXTRA_TITLE, args["title"]?.toString())
                            putExtra(CriticalAlertRingingService.EXTRA_BODY, args["body"]?.toString())
                            putExtra(CriticalAlertRingingService.EXTRA_ROUTE, args["route"]?.toString())
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }
                    "stopRinging" -> {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        val intent = Intent(this, CriticalAlertRingingService::class.java).apply {
                            action = CriticalAlertRingingService.ACTION_STOP
                            putExtra(CriticalAlertRingingService.EXTRA_ALERT_ID, args["alertId"]?.toString())
                        }
                        startService(intent)
                        result.success(null)
                    }
                    "getInitialRoute" -> {
                        val route = pendingRoute ?: intent?.getStringExtra("critical_route")
                        pendingRoute = null
                        result.success(route)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingRoute = intent.getStringExtra("critical_route")
    }
}
