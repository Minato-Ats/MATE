package com.example.mate

/**
 * In-process, in-memory state shared between [MainActivity], [ForegroundWatcherService]
 * and [InterventionActivity]. All three run in the same app process (no `android:process`
 * override anywhere), so a plain singleton is sufficient — no IPC needed.
 *
 * This is intentionally NOT persisted: [guardedPackages] is re-synced from Flutter every
 * time it changes (see `syncGuardedPackages` in MainActivity.kt) and on process start, and
 * the bypass/active-intervention state only makes sense for the lifetime of one process run.
 */
object MonitorState {
    @Volatile
    var guardedPackages: Set<String> = emptySet()

    @Volatile
    var lastForegroundPackage: String? = null

    /**
     * Packages the user just chose "開く" for. Removed once the user leaves that app
     * (foreground moves to something else), so re-opening it later re-triggers the
     * intervention — this is what prevents both an infinite intervene-loop on open and
     * the app going permanently unguarded after one "開く".
     */
    val bypassedPackages: MutableSet<String> = mutableSetOf()

    /** The package currently showing [InterventionActivity], if any. */
    @Volatile
    var activeInterventionPackage: String? = null

    /** Whether MainActivity has already asked for POST_NOTIFICATIONS this process run. */
    @Volatile
    var notificationPermissionRequested: Boolean = false

    // --- Phase 4: schedule, pause, per-app overrides -------------------------------
    // All re-synced from Flutter's persisted settings on every evaluate() call (see
    // WatcherCoordinator.dart), the same pattern guardedPackages already uses — this
    // service only ever needs a snapshot fresh enough for the next poll, not a
    // permanently-correct copy.

    @Volatile
    var scheduleEnabled: Boolean = false

    @Volatile
    var scheduleStartMinutes: Int = 0

    @Volatile
    var scheduleEndMinutes: Int = 0

    @Volatile
    var scheduleWeekdays: Set<Int> = emptySet()

    /** Packages that stay guarded around the clock even when [scheduleEnabled] is true. */
    @Volatile
    var alwaysGuardPackages: Set<String> = emptySet()

    /** Epoch millis until which MATE shouldn't intervene for anything; 0 = not paused. */
    @Volatile
    var pausedUntilMillis: Long = 0L
}
