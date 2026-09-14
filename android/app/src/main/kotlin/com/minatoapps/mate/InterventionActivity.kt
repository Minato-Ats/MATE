package com.minatoapps.mate

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodChannel

/**
 * Full-screen "pause and reflect" activity shown on top of whatever the user was doing
 * the instant a guarded app is detected. Runs a *separate* Flutter Dart entrypoint
 * (`interventionMain`, in `lib/intervention_main.dart`) from MainActivity's — it's a
 * different Flutter engine instance with its own minimal widget tree, not a route
 * inside the main app's navigator, since it must be launchable directly from a
 * background Service with no dependency on MainActivity being alive.
 */
class InterventionActivity : FlutterActivity() {
    companion object {
        const val EXTRA_PACKAGE_NAME = "packageName"
        private const val CHANNEL = "app.mate/intervention"
    }

    private var methodChannel: MethodChannel? = null

    override fun getDartEntrypointFunctionName(): String = "interventionMain"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getArgs" -> result.success(currentArgs())
                "resolveOpen" -> {
                    resolveOpen(call.argument<String>("packageName"))
                    result.success(null)
                }
                "resolveGiveUp" -> {
                    resolveGiveUp()
                    result.success(null)
                }
                "readyToShow" -> {
                    // Redundant with the renderer listener below (belt and suspenders;
                    // hideTransitionCoverIfShowing() is idempotent either way) — kept as
                    // a second path in case a future refactor changes how the engine is
                    // attached.
                    ForegroundWatcherService.instance?.hideTransitionCoverIfShowing()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // The authoritative signal: this fires when the Flutter *renderer* has actually
        // composited and displayed a frame — a native, engine-level callback with no
        // Dart code or platform-channel round trip in the way. This is deliberately not
        // the only path (see "readyToShow" above and the fallback timer in
        // ForegroundWatcherService) but it's the fastest and most reliable one, since it
        // can't be delayed by Dart isolate scheduling the way a MethodChannel call from
        // Dart could be under heavy system load — precisely the scenario (slow engine
        // boot on a loaded device) this whole mechanism exists to survive.
        flutterEngine.renderer.addIsDisplayingFlutterUiListener(object : FlutterUiDisplayListener {
            override fun onFlutterUiDisplayed() {
                ForegroundWatcherService.instance?.hideTransitionCoverIfShowing()
            }

            override fun onFlutterUiNoLongerDisplayed() {}
        })
        // Cover the (normally impossible, but cheap to guard) case where a frame was
        // already displayed by the time this listener was registered.
        if (flutterEngine.renderer.isDisplayingFlutterUi) {
            ForegroundWatcherService.instance?.hideTransitionCoverIfShowing()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Existing singleTask instance reused for a different guarded app: tell Flutter
        // to re-fetch args instead of showing stale info.
        methodChannel?.invokeMethod("argsChanged", null)
    }

    private fun currentArgs(): Map<String, Any?> {
        val pkg = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: return mapOf("packageName" to null)
        return try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(pkg, 0)
            val label = pm.getApplicationLabel(appInfo).toString()
            val icon = IconUtil.toPngBytes(pm.getApplicationIcon(pkg), size = 128)
            mapOf("packageName" to pkg, "appName" to label, "icon" to icon)
        } catch (e: Exception) {
            mapOf("packageName" to pkg, "appName" to pkg, "icon" to null)
        }
    }

    private fun resolveOpen(packageArg: String?) {
        val pkg = packageArg ?: intent.getStringExtra(EXTRA_PACKAGE_NAME)
        if (pkg != null) {
            // Mark bypassed *before* launching so the watcher's next poll (which will see
            // this same package come back to the foreground) doesn't re-trigger.
            MonitorState.bypassedPackages.add(pkg)
            MonitorState.activeInterventionPackage = null
            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
            }
        }
        finish()
    }

    private fun resolveGiveUp() {
        MonitorState.activeInterventionPackage = null
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(homeIntent)
        finish()
    }
}
