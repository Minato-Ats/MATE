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
        val minutesOfDay = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val start = MonitorState.scheduleStartMinutes
        val end = MonitorState.scheduleEndMinutes

        return if (start <= end) {
            MonitorState.scheduleWeekdays.contains(isoWeekday) &&
                minutesOfDay in start until end
        } else {
            // Overnight window: weekdays identify the day on which the window
            // starts. Therefore Tue 01:00 belongs to Monday's 22:00-02:00 rule.
            when {
                minutesOfDay >= start -> MonitorState.scheduleWeekdays.contains(isoWeekday)
                minutesOfDay < end -> MonitorState.scheduleWeekdays.contains(previousIsoWeekday(isoWeekday))
                else -> false
            }
        }
    }

    /** Converts Calendar.DAY_OF_WEEK (Sunday=1..Saturday=7) to ISO (Monday=1..Sunday=7). */
    private fun toIsoWeekday(calendarDayOfWeek: Int): Int {
        return if (calendarDayOfWeek == Calendar.SUNDAY) 7 else calendarDayOfWeek - 1
    }

    private fun previousIsoWeekday(weekday: Int): Int = if (weekday == 1) 7 else weekday - 1
}
