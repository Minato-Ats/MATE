package com.example.mate

import android.Manifest
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge exposing three things to Flutter's main engine:
 *  - installed launchable apps (Phase 1)
 *  - a screen-scoped foreground-app watcher used only by the debug "検知テスト" screen
 *    (Phase 1; independent of the always-on [ForegroundWatcherService] added in Phase 2)
 *  - control of the Phase 2 always-on watcher service and the guarded-package list it uses
 *
 * Foreground detection uses [UsageStatsManager], gated by the `PACKAGE_USAGE_STATS`
 * special app-op permission the user grants manually in system settings. This is
 * deliberately not an AccessibilityService — see ForegroundWatcherService's doc comment
 * for why that trade-off was made for Phase 2's real-time intervention, too.
 */
class MainActivity : FlutterActivity() {
    private val installedAppsChannelName = "app.mate/installed_apps"
    private val foregroundEventsChannelName = "app.mate/foreground_events"

    private var watcherThread: HandlerThread? = null
    private var watcherHandler: Handler? = null
    private var lastQueriedUntil: Long = 0L
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, installedAppsChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> result.success(getInstalledApps())
                    "hasUsageAccessPermission" -> result.success(UsageAccess.hasPermission(this))
                    "openUsageAccessSettings" -> {
                        openUsageAccessSettings()
                        result.success(null)
                    }
                    "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                    "openOverlaySettings" -> {
                        openOverlaySettings()
                        result.success(null)
                    }
                    "syncGuardedPackages" -> {
                        @Suppress("UNCHECKED_CAST")
                        val packages = (call.arguments as? List<String>)?.toSet() ?: emptySet()
                        MonitorState.guardedPackages = packages
                        result.success(null)
                    }
                    "syncScheduleRule" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        MonitorState.scheduleEnabled = args["enabled"] as? Boolean ?: false
                        MonitorState.scheduleStartMinutes = (args["startMinutes"] as? Int) ?: 0
                        MonitorState.scheduleEndMinutes = (args["endMinutes"] as? Int) ?: 0
                        @Suppress("UNCHECKED_CAST")
                        val weekdays = (args["weekdays"] as? List<Int>)?.toSet() ?: emptySet()
                        MonitorState.scheduleWeekdays = weekdays
                        result.success(null)
                    }
                    "syncAlwaysGuardPackages" -> {
                        @Suppress("UNCHECKED_CAST")
                        val packages = (call.arguments as? List<String>)?.toSet() ?: emptySet()
                        MonitorState.alwaysGuardPackages = packages
                        result.success(null)
                    }
                    "syncPausedUntil" -> {
                        val millis = (call.arguments as? Number)?.toLong() ?: 0L
                        MonitorState.pausedUntilMillis = millis
                        result.success(null)
                    }
                    "startWatcherService" -> {
                        requestNotificationPermissionIfNeeded()
                        startWatcherService()
                        result.success(null)
                    }
                    "stopWatcherService" -> {
                        stopService(Intent(this, ForegroundWatcherService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, foregroundEventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    startForegroundWatch(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopForegroundWatch()
                }
            })
    }

    private fun startWatcherService() {
        val intent = Intent(this, ForegroundWatcherService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: IllegalStateException) {
            // Android refuses a *new* foreground-service start while the app has no
            // qualifying visible/foreground state (e.g. this call landed just as the
            // user backgrounded MATE right after opening it) — thrown on API 31+ as
            // ForegroundServiceStartNotAllowedException, a subclass of this. Harmless
            // to skip: the next evaluate() call (next toggle, next resume) runs while
            // MATE is actually visible again and will start it successfully then.
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        // Asked at most once per process run: startWatcherService() (and so
        // this) is re-invoked on every guarded-app toggle and every permission
        // refresh, and re-showing the system dialog every single time — which
        // is what a naive "not granted yet" check does, since a denial doesn't
        // change checkSelfPermission()'s answer — was visibly spamming the
        // user during testing.
        if (MonitorState.notificationPermissionRequested) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            MonitorState.notificationPermissionRequested = true
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
        }
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        // ACTION_MAIN/CATEGORY_LAUNCHER is one of the intent signatures Android
        // exempts from package-visibility filtering, so this works on Android 11+
        // without the broad QUERY_ALL_PACKAGES permission.
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(launcherIntent, 0)

        return resolved
            .asSequence()
            .map { it.activityInfo.packageName }
            .distinct()
            .filter { it != packageName }
            .mapNotNull { pkg ->
                try {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    val label = pm.getApplicationLabel(appInfo).toString()
                    val icon = IconUtil.toPngBytes(pm.getApplicationIcon(pkg))
                    mapOf(
                        "packageName" to pkg,
                        "appName" to label,
                        "icon" to icon,
                    )
                } catch (e: PackageManager.NameNotFoundException) {
                    null
                }
            }
            .sortedBy { (it["appName"] as String).lowercase() }
            .toList()
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun openOverlaySettings() {
        val intent = Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            android.net.Uri.parse("package:$packageName"),
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun startForegroundWatch(events: EventChannel.EventSink) {
        stopForegroundWatch()
        // Start from "now": we report new foreground transitions going forward,
        // not the device's entire usage history.
        lastQueriedUntil = System.currentTimeMillis()
        val thread = HandlerThread("mate-foreground-watch")
        thread.start()
        watcherThread = thread
        val handler = Handler(thread.looper)
        watcherHandler = handler

        val poll = object : Runnable {
            override fun run() {
                for (foregroundEvent in newForegroundEvents()) {
                    mainHandler.post { events.success(foregroundEvent) }
                }
                handler.postDelayed(this, 1000)
            }
        }
        handler.post(poll)
    }

    private fun stopForegroundWatch() {
        watcherThread?.quitSafely()
        watcherThread = null
        watcherHandler = null
    }

    /**
     * All MOVE_TO_FOREGROUND transitions since the last poll, oldest first, as
     * `{"packageName": ..., "timestamp": ...}` maps. Advances [lastQueriedUntil]
     * so each transition is reported exactly once.
     */
    private fun newForegroundEvents(): List<Map<String, Any?>> {
        if (!UsageAccess.hasPermission(this)) return emptyList()
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val begin = lastQueriedUntil
        lastQueriedUntil = end
        if (begin >= end) return emptyList()

        val usageEvents = usm.queryEvents(begin, end)
        val results = mutableListOf<Map<String, Any?>>()
        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                results.add(mapOf("packageName" to event.packageName, "timestamp" to event.timeStamp))
            }
        }
        return results
    }

    override fun onDestroy() {
        stopForegroundWatch()
        super.onDestroy()
    }
}
