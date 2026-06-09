package nl.blu8print.rootscalendar

import android.content.Context
import android.content.SharedPreferences

object SolarTimeHelper {

    private const val PREFS_FILE   = "roots_widget_prefs"
    private const val KEY_OFFSET   = "solar_offset_ms"
    private const val KEY_CALC_AT  = "offset_calculated_at"
    private const val SIX_HOURS_MS = 6 * 3_600_000L

    fun prefsFile(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

    fun shouldRecalculate(cachePrefs: SharedPreferences): Boolean {
        val calculatedAt = cachePrefs.getLong(KEY_CALC_AT, 0L)
        return calculatedAt == 0L ||
            System.currentTimeMillis() - calculatedAt > SIX_HOURS_MS
    }

    /**
     * Spencer (1971) equation of time — accurate to ~1 minute.
     * Returns correction in milliseconds.
     */
    fun equationOfTimeMs(date: java.util.Date): Long {
        val cal = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
        cal.time = date
        val dayOfYear = cal.get(java.util.Calendar.DAY_OF_YEAR)
        val B = Math.toRadians((360.0 / 365.0) * (dayOfYear - 81))
        val eotMinutes = 9.87 * Math.sin(2 * B) - 7.53 * Math.cos(B) - 1.5 * Math.sin(B)
        return (eotMinutes * 60_000).toLong()
    }

    /**
     * Computes solar_time_ms − system_time_ms and stores it in [cachePrefs].
     * Call on first run and whenever [shouldRecalculate] returns true.
     */
    fun recalculateSolarOffset(longitude: Double, cachePrefs: SharedPreferences) {
        val now               = System.currentTimeMillis()
        val longitudeOffsetMs = (longitude / 15.0 * 3_600_000).toLong()
        val eotMs             = equationOfTimeMs(java.util.Date(now))
        cachePrefs.edit()
            .putLong(KEY_OFFSET,  longitudeOffsetMs + eotMs)
            .putLong(KEY_CALC_AT, now)
            .apply()
    }

    /**
     * Formats an epoch-ms value as "HH:mm".
     *
     * - System time  → useDeviceTimezone = true  (matches the status bar)
     * - Solar time   → useDeviceTimezone = false  (offset already encodes the
     *   geographic correction; UTC arithmetic avoids DST corruption)
     */
    fun formatUtcAsHHmm(epochMs: Long, useDeviceTimezone: Boolean): String {
        val sdf = java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault())
        sdf.timeZone = if (useDeviceTimezone)
            java.util.TimeZone.getDefault()
        else
            java.util.TimeZone.getTimeZone("UTC")
        return sdf.format(java.util.Date(epochMs))
    }
}
