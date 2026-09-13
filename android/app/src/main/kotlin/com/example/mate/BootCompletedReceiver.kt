package com.example.mate

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings

/**
 * Resumes guarding after a device reboot.
 *
 * Without this, MATE's watcher — a plain [ForegroundWatcherService] with no
 * restart-on-boot hook — simply never comes back after the device restarts:
 * nothing runs until the user happens to reopen the app, so guarding would
 * silently stop working for however long that takes. This receiver restores
 * the last-synced state from [NativeStateStore] straight into [MonitorState]
 * and starts the service itself, with no Flutter engine involved (nothing
 * else has booted yet at this point).
 *
 * Deliberately does nothing if either required permission has since been
 * revoked (matches [com.example.mate].WatcherCoordinator's own
 * guardedPackages-not-empty && hasUsageAccess && hasOverlayAccess condition
 * on the Dart side) — starting a service that would immediately be unable to
 * do anything useful isn't worth doing.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        NativeStateStore.restoreIntoMonitorState(context)
        if (MonitorState.guardedPackages.isEmpty()) return
        if (!UsageAccess.hasPermission(context)) return
        if (!Settings.canDrawOverlays(context)) return

        val serviceIntent = Intent(context, ForegroundWatcherService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } catch (e: IllegalStateException) {
            // Same defensive catch as MainActivity.startWatcherService(): on API 31+ this can
            // be a ForegroundServiceStartNotAllowedException if the system's post-boot
            // temporary background-start allowance has already lapsed (e.g. a very slow boot).
            // Nothing to recover into here — the user opening MATE themselves will start it
            // normally via the usual evaluate() path.
        }
    }
}
