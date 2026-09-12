package com.example.mate

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.View
import android.view.WindowManager

/**
 * Keeps watching for a guarded app coming to the foreground even while MATE's own UI
 * isn't open — this is what makes Phase 2's intervention possible at all, since by
 * definition MATE isn't in the foreground when the moment we care about happens.
 *
 * Polls [UsageStatsManager] every 500ms (only while the screen is on — see
 * [screenReceiver], which is the main lever for keeping battery impact low) on a
 * background thread. Runs as a genuine foreground service (with an ongoing, minimum-
 * importance notification) specifically so Android's Doze/App Standby background
 * execution limits don't throttle or kill it — that exemption is the entire reason to
 * use a foreground service here instead of a plain background service or WorkManager.
 */
class ForegroundWatcherService : Service() {
    companion object {
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "mate_watch_channel"
        private const val POLL_INTERVAL_MS = 500L

        /**
         * Safety-net only, and deliberately generous. [InterventionActivity] normally
         * calls [hideTransitionCoverIfShowing] itself — via the engine-level
         * `FlutterUiDisplayListener` (fires the instant a frame is actually composited,
         * with no Dart/platform-channel round trip in the way) — the moment content is
         * genuinely on screen, which in practice is at most a second or two even on a
         * slow first boot. This upper bound only matters if that never fires at all
         * (e.g. the engine crashes before producing a frame); reaching it means
         * something is actually broken, not just slow, so it's set long enough that a
         * struggling-but-working device is never cut off mid-boot.
         */
        private const val TRANSITION_COVER_MAX_MS = 8000L

        /** Same-process handle so [InterventionActivity] can report "I'm drawn now". */
        @Volatile
        var instance: ForegroundWatcherService? = null
    }

    private var thread: HandlerThread? = null
    private var handler: Handler? = null
    private var lastQueriedUntil: Long = 0L
    private val mainHandler = Handler(Looper.getMainLooper())
    private var transitionCoverView: View? = null

    @Volatile
    private var screenOn: Boolean = true

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_ON -> screenOn = true
                Intent.ACTION_SCREEN_OFF -> screenOn = false
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        registerReceiver(
            screenReceiver,
            IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
            },
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        startPollingIfNeeded()
        return START_STICKY
    }

    private fun startAsForeground() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "MATE 見守り", NotificationManager.IMPORTANCE_MIN)
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("MATEが見守り中です")
            .setContentText("対象アプリを開くと、ひと呼吸おいてお知らせします")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startPollingIfNeeded() {
        if (thread != null) return
        // Start from "now" — we only care about transitions from this point forward.
        lastQueriedUntil = System.currentTimeMillis()
        val newThread = HandlerThread("mate-watcher")
        newThread.start()
        thread = newThread
        val newHandler = Handler(newThread.looper)
        handler = newHandler
        newHandler.post(pollRunnable)
    }

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (screenOn) {
                checkForeground()
            }
            handler?.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    private fun checkForeground() {
        if (MonitorState.guardedPackages.isEmpty()) return
        if (!UsageAccess.hasPermission(this)) return

        val usm = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val begin = lastQueriedUntil
        lastQueriedUntil = end
        if (begin >= end) return

        // Process every transition in order, not just the newest one in this window.
        // Keeping only the last event was a real bug: if two switches happened within
        // one 500ms poll (e.g. guarded app -> Home -> guarded app again, all inside one
        // window under load), the intermediate "left the app" transition was discarded,
        // MonitorState.lastForegroundPackage never updated away from the guarded app,
        // and the next genuine open of it was then wrongly treated as "no change" and
        // silently skipped. Replaying every event keeps the bypass/re-arm state machine
        // in handleForegroundChange() correct regardless of how many switches happened
        // between polls.
        //
        // While paused (Phase 4's "一時休止"), we deliberately keep advancing
        // lastForegroundPackage without ever calling handleForegroundChange(), so: (a)
        // nothing intervenes, but (b) there's no backlog of stale transitions to
        // suddenly replay — each still fully intervening — the instant the pause ends.
        val isPaused = System.currentTimeMillis() < MonitorState.pausedUntilMillis
        val usageEvents = usm.queryEvents(begin, end)
        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                if (isPaused) {
                    MonitorState.lastForegroundPackage = event.packageName
                } else {
                    handleForegroundChange(event.packageName)
                }
            }
        }
    }

    private fun handleForegroundChange(pkg: String) {
        val previous = MonitorState.lastForegroundPackage
        if (pkg == previous) return

        // The user left a previously-bypassed app: re-arm it for next time.
        if (previous != null && MonitorState.bypassedPackages.contains(previous)) {
            MonitorState.bypassedPackages.remove(previous)
        }
        // The user navigated away without deciding (e.g. pressed Home): clear the stale lock.
        if (MonitorState.activeInterventionPackage != null && pkg != MonitorState.activeInterventionPackage) {
            MonitorState.activeInterventionPackage = null
        }
        MonitorState.lastForegroundPackage = pkg

        val shouldIntervene = pkg != packageName &&
            MonitorState.guardedPackages.contains(pkg) &&
            !MonitorState.bypassedPackages.contains(pkg) &&
            MonitorState.activeInterventionPackage != pkg &&
            ScheduleCheck.isGuardingActiveNow(pkg)
        if (shouldIntervene) {
            MonitorState.activeInterventionPackage = pkg
            launchIntervention(pkg)
        }
    }

    private fun launchIntervention(pkg: String) {
        mainHandler.post {
            // Android blocks a background process from starting a new Activity unless
            // it currently has a visible window. A foreground service alone doesn't
            // count, so without this cover, startActivity() below is silently blocked
            // ("Background activity launch blocked") on Android 10+ and the
            // intervention screen never appears — confirmed via real device testing.
            showTransitionCover()
            val intent = Intent(this, InterventionActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra(InterventionActivity.EXTRA_PACKAGE_NAME, pkg)
            }
            startActivity(intent)
            // Fallback only — see hideTransitionCoverIfShowing() for the normal path.
            mainHandler.postDelayed({ hideTransitionCover() }, TRANSITION_COVER_MAX_MS)
        }
    }

    /**
     * Called from [InterventionActivity] once its Flutter content has actually drawn a
     * frame. This — not a fixed timer — is what should normally remove the cover:
     * a fixed delay was tried first and confirmed (via testing) to be a real race, since
     * Flutter engine boot time varies with device load and isn't bounded tightly enough
     * to hard-code. Removing the cover before Flutter has drawn anything reveals the
     * plain native window background instead of the intervention UI — a blank white (or
     * black in dark mode) screen with no text or buttons, which is exactly the bug this
     * fixes.
     */
    fun hideTransitionCoverIfShowing() {
        mainHandler.post { hideTransitionCover() }
    }

    /**
     * Briefly shows a plain, full-screen overlay so this service counts as "having a
     * visible window" for Android's background-activity-start check, and so the
     * target app's UI doesn't flash on screen while the intervention Activity boots.
     * Requires the "Display over other apps" special permission; if it's not granted,
     * this is a no-op and [launchIntervention]'s startActivity call may then be
     * blocked by the OS — surfaced to the user as a permission requirement in Settings.
     */
    private fun showTransitionCover() {
        if (!Settings.canDrawOverlays(this) || transitionCoverView != null) return
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val view = View(this).apply { setBackgroundColor(Color.parseColor("#F3F8F6")) }
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.OPAQUE,
        )
        try {
            windowManager.addView(view, params)
            transitionCoverView = view
        } catch (e: Exception) {
            // Best-effort: if the overlay can't be shown, we still attempt startActivity.
            transitionCoverView = null
        }
    }

    private fun hideTransitionCover() {
        val view = transitionCoverView ?: return
        transitionCoverView = null
        try {
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            windowManager.removeView(view)
        } catch (e: Exception) {
            // Already removed (e.g. service torn down); safe to ignore.
        }
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        thread?.quitSafely()
        thread = null
        handler = null
        hideTransitionCover()
        try {
            unregisterReceiver(screenReceiver)
        } catch (e: IllegalArgumentException) {
            // Already unregistered; safe to ignore.
        }
        super.onDestroy()
    }
}
