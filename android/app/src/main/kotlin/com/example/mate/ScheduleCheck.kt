package com.example.mate

import java.util.Calendar

/**
 * Native mirror of `ScheduleRule.isActiveAt()` on the Dart side (see
 * `lib/data/models/schedule_rule.dart`) — the watcher service runs independently of
 * Flutter, so it needs its own copy of this logic rather than calling into Dart for
 * every poll. Keep the two in sync if the rule's semantics ever change.
 *
 * Uses [Calendar] rather than `java.time` since this project's minSdk (24) predates
 * `java.time` availability without extra desugaring setup.
 */
object ScheduleCheck {
    fun isGuardingActiveNow(pkg: String): Boolean {
        if (MonitorState.alwaysGuardPackages.contains(pkg)) return true
        if (!MonitorState.scheduleEnabled) return true

        val now = Calendar.getInstance()
        val isoWeekday = toIsoWeekday(now.get(Calendar.DAY_OF_WEEK))
        if (!MonitorState.scheduleWeekdays.contains(isoWeekday)) return false

        val minutesOfDay = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val start = MonitorState.scheduleStartMinutes
        val end = MonitorState.scheduleEndMinutes
        return if (start <= end) {
            minutesOfDay in start until end
        } else {
            // Overnight window (e.g. 22:00-02:00).
            minutesOfDay >= start || minutesOfDay < end
        }
    }

    /** Converts Calendar.DAY_OF_WEEK (Sunday=1..Saturday=7) to ISO (Monday=1..Sunday=7). */
    private fun toIsoWeekday(calendarDayOfWeek: Int): Int {
        return if (calendarDayOfWeek == Calendar.SUNDAY) 7 else calendarDayOfWeek - 1
    }
}
