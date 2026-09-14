package com.minatoapps.mate

import android.content.Context

/**
 * A small, native-only durable cache of the same guard state [MonitorState] holds in memory —
 * written every time Flutter syncs it via [MainActivity]'s method channel, read back only by
 * [BootCompletedReceiver].
 *
 * This exists because [MonitorState] is a plain in-memory singleton: it starts empty on every
 * fresh process, and is normally only repopulated once Flutter boots and calls the `syncXxx`
 * methods. On a device reboot, nothing restarts Flutter (or this app at all) until the user
 * manually reopens it — so without some persisted copy of "what was guarded," a
 * `BOOT_COMPLETED` receiver would have no way to decide whether the watcher should resume.
 *
 * Deliberately a plain native `SharedPreferences` file (not the one the `shared_preferences`
 * Flutter plugin uses) rather than trying to read Flutter's own storage from Kotlin — that
 * plugin's on-disk format is an internal implementation detail (and has changed backends
 * across versions), so parsing it directly here would be fragile. This file only needs to
 * round-trip the handful of primitives below, written in the same native code that already
 * updates [MonitorState].
 */
object NativeStateStore {
    private const val PREFS_NAME = "mate_native_state"
    private const val KEY_GUARDED_PACKAGES = "guarded_packages"
    private const val KEY_SCHEDULE_ENABLED = "schedule_enabled"
    private const val KEY_SCHEDULE_START = "schedule_start"
    private const val KEY_SCHEDULE_END = "schedule_end"
    private const val KEY_SCHEDULE_WEEKDAYS = "schedule_weekdays"
    private const val KEY_ALWAYS_GUARD_PACKAGES = "always_guard_packages"

    fun saveGuardedPackages(context: Context, packages: Set<String>) {
        prefs(context).edit().putStringSet(KEY_GUARDED_PACKAGES, packages).apply()
    }

    fun saveSchedule(context: Context, enabled: Boolean, startMinutes: Int, endMinutes: Int, weekdays: Set<Int>) {
        prefs(context).edit()
            .putBoolean(KEY_SCHEDULE_ENABLED, enabled)
            .putInt(KEY_SCHEDULE_START, startMinutes)
            .putInt(KEY_SCHEDULE_END, endMinutes)
            .putStringSet(KEY_SCHEDULE_WEEKDAYS, weekdays.map { it.toString() }.toSet())
            .apply()
    }

    fun saveAlwaysGuardPackages(context: Context, packages: Set<String>) {
        prefs(context).edit().putStringSet(KEY_ALWAYS_GUARD_PACKAGES, packages).apply()
    }

    /** Loads the last-saved state directly into [MonitorState] (used on boot). */
    fun restoreIntoMonitorState(context: Context) {
        val p = prefs(context)
        MonitorState.guardedPackages = p.getStringSet(KEY_GUARDED_PACKAGES, emptySet()) ?: emptySet()
        MonitorState.scheduleEnabled = p.getBoolean(KEY_SCHEDULE_ENABLED, false)
        MonitorState.scheduleStartMinutes = p.getInt(KEY_SCHEDULE_START, 0)
        MonitorState.scheduleEndMinutes = p.getInt(KEY_SCHEDULE_END, 0)
        MonitorState.scheduleWeekdays =
            (p.getStringSet(KEY_SCHEDULE_WEEKDAYS, emptySet()) ?: emptySet()).mapNotNull { it.toIntOrNull() }.toSet()
        MonitorState.alwaysGuardPackages = p.getStringSet(KEY_ALWAYS_GUARD_PACKAGES, emptySet()) ?: emptySet()
        // Pause is deliberately NOT restored across a reboot — pause is a short, session-scoped
        // "leave me alone for a bit" that the user would not expect to silently survive a
        // restart, and restoring a stale timestamp here could re-pause guarding indefinitely if
        // the millis were ever malformed. A reboot starts guarding fresh (unpaused).
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
