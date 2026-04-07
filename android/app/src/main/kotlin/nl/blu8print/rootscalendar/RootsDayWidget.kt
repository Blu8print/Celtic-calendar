package nl.blu8print.rootscalendar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

class RootsDayWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    /** Re-render when the user resizes the widget. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    companion object {

        // ── Colour palettes ───────────────────────────────────────────────
        // Light — matches AppColors.light / roots_day_widget.html
        private val LIGHT_BG      = Color.parseColor("#FFF7F3EC")
        private val LIGHT_TEXT    = Color.parseColor("#FF111108")
        private val LIGHT_ACCENT  = Color.parseColor("#FF1A4018") // dark green
        private val LIGHT_SUB     = Color.parseColor("#FF5A5040")
        private val LIGHT_DIVIDER = Color.parseColor("#FFB8AE9E")
        private val LIGHT_EV_TEXT = Color.parseColor("#FF111108") // .ev-title
        private val LIGHT_EV_SUB  = Color.parseColor("#FF5A5040") // .ev-time
        private val LIGHT_AD_TEXT = Color.parseColor("#FF5A3800") // .ev-ad-title
        private val LIGHT_AD_SUB  = Color.parseColor("#FF8A6000") // .ev-ad-lbl

        // Dark — matches AppColors.dark
        private val DARK_BG      = Color.parseColor("#FF0F1A0E")
        private val DARK_TEXT    = Color.parseColor("#FFC0D8B8")
        private val DARK_ACCENT  = Color.parseColor("#FFC9A84C") // gold
        private val DARK_SUB     = Color.parseColor("#FF6A8A60")
        private val DARK_DIVIDER = Color.parseColor("#FF1E3019")
        private val DARK_EV_TEXT = Color.parseColor("#FFC0D8B8")
        private val DARK_EV_SUB  = Color.parseColor("#FF6A8A60")
        private val DARK_AD_TEXT = Color.parseColor("#FFE8CC88")
        private val DARK_AD_SUB  = Color.parseColor("#FFC9A84C")

        // Fallback bar colour when event colour is missing or unparseable
        private val FALLBACK_BAR  = Color.parseColor("#FFB07800")

        // Lookup tables indexed by slot number (1-based, index = n-1)
        private val CARD_IDS  = intArrayOf(
            R.id.widget_event_1, R.id.widget_event_2, R.id.widget_event_3,
            R.id.widget_event_4, R.id.widget_event_5,
        )
        private val BAR_IDS   = intArrayOf(
            R.id.widget_event_1_bar, R.id.widget_event_2_bar, R.id.widget_event_3_bar,
            R.id.widget_event_4_bar, R.id.widget_event_5_bar,
        )
        private val TITLE_IDS = intArrayOf(
            R.id.widget_event_1_title, R.id.widget_event_2_title, R.id.widget_event_3_title,
            R.id.widget_event_4_title, R.id.widget_event_5_title,
        )
        private val TIME_IDS  = intArrayOf(
            R.id.widget_event_1_time, R.id.widget_event_2_time, R.id.widget_event_3_time,
            R.id.widget_event_4_time, R.id.widget_event_5_time,
        )

        /**
         * How many event cards fit given the current widget height.
         * Overhead (header + divider): ~82 dp. Each card: ~55 dp.
         */
        private fun maxEventsForHeight(
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ): Int {
            val opts = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minHeightDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 190)
            return ((minHeightDp - 82) / 55).coerceIn(1, 5)
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            try {
                val prefs = context.getSharedPreferences(
                    "HomeWidgetPreferences", Context.MODE_PRIVATE
                )

                // Dart ints ≤ 2^31-1 arrive as Java Integer (putInt) via MethodChannel.
                val celticDay = prefs.getInt("celtic_day", 0)
                val monthName = prefs.getString("celtic_month_name", "") ?: ""
                val tree      = prefs.getString("celtic_tree", "") ?: ""
                val keyword   = prefs.getString("celtic_keyword", "") ?: ""
                val gregDate  = prefs.getString("greg_date", "") ?: ""
                val isLight   = prefs.getBoolean("is_light", true)

                // Read all 5 event slots
                data class EventSlot(val title: String, val time: String,
                                     val color: String, val allDay: Boolean)
                val slots = (1..5).map { n ->
                    EventSlot(
                        title  = prefs.getString("event_${n}_title",  "") ?: "",
                        time   = prefs.getString("event_${n}_time",   "") ?: "",
                        color  = prefs.getString("event_${n}_color",  "") ?: "",
                        allDay = prefs.getBoolean("event_${n}_allday", false),
                    )
                }

                // ── Pick colour palette ───────────────────────────────────
                val bg      = if (isLight) LIGHT_BG      else DARK_BG
                val text    = if (isLight) LIGHT_TEXT     else DARK_TEXT
                val accent  = if (isLight) LIGHT_ACCENT   else DARK_ACCENT
                val sub     = if (isLight) LIGHT_SUB      else DARK_SUB
                val divider = if (isLight) LIGHT_DIVIDER  else DARK_DIVIDER

                val views = RemoteViews(context.packageName, R.layout.roots_day_widget)

                // ── Widget background + structural colours ─────────────────
                views.setInt(R.id.widget_root,    "setBackgroundColor", bg)
                views.setInt(R.id.widget_divider, "setBackgroundColor", divider)
                views.setTextColor(R.id.widget_day_num,    accent)
                views.setTextColor(R.id.widget_month_name, text)
                views.setTextColor(R.id.widget_date_line,  sub)
                views.setTextColor(R.id.widget_clock,      accent)
                views.setTextColor(R.id.widget_no_events,  sub)

                // ── Header text ───────────────────────────────────────────
                views.setTextViewText(
                    R.id.widget_day_num,
                    if (celticDay > 0) "$celticDay" else "—",
                )
                views.setTextViewText(
                    R.id.widget_month_name,
                    when {
                        monthName.isNotEmpty() && tree.isNotEmpty() -> "$monthName · $tree"
                        monthName.isNotEmpty()                      -> monthName
                        else                                        -> "Roots Calendar"
                    },
                )
                views.setTextViewText(
                    R.id.widget_date_line,
                    when {
                        gregDate.isNotEmpty() && keyword.isNotEmpty() ->
                            "$gregDate · ${keyword.uppercase()}"
                        else -> gregDate
                    },
                )

                // ── Event cards — show as many as fit the current height ───
                val maxEvents = maxEventsForHeight(appWidgetManager, appWidgetId)
                var anyVisible = false

                for (i in 0 until 5) {
                    val slot   = slots[i]
                    val within = i < maxEvents && slot.title.isNotEmpty()
                    views.setViewVisibility(CARD_IDS[i], if (within) View.VISIBLE else View.GONE)
                    if (within) {
                        anyVisible = true
                        applyCard(views, isLight, slot.allDay,
                            CARD_IDS[i], BAR_IDS[i], TITLE_IDS[i], TIME_IDS[i],
                            slot.title, slot.time, slot.color)
                    }
                }

                views.setViewVisibility(
                    R.id.widget_no_events,
                    if (anyVisible) View.GONE else View.VISIBLE,
                )

                // ── Tap to open app ───────────────────────────────────────
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)

            } catch (e: Exception) {
                android.util.Log.e("RootsDayWidget", "updateWidget failed: ${e.message}", e)
            }
        }

        /** Applies card background, bar colour, and text to one event slot. */
        private fun applyCard(
            views: RemoteViews,
            isLight: Boolean,
            allDay: Boolean,
            cardId: Int,
            barId: Int,
            titleId: Int,
            timeId: Int,
            title: String,
            time: String,
            colorHex: String,
        ) {
            // Card background drawable — rounded border, themed fill
            val cardBg = when {
                allDay && isLight  -> R.drawable.widget_event_allday_light
                allDay && !isLight -> R.drawable.widget_event_allday_dark
                isLight            -> R.drawable.widget_event_card_light
                else               -> R.drawable.widget_event_card_dark
            }
            views.setInt(cardId, "setBackgroundResource", cardBg)

            // Left colour bar — use event's own colour, fall back to gold
            val barColor = try {
                Color.parseColor(colorHex.ifEmpty { "#B07800" })
            } catch (_: Exception) {
                FALLBACK_BAR
            }
            views.setInt(barId, "setBackgroundColor", barColor)

            // Text colours differ for all-day (amber palette) vs timed
            val titleColor = if (allDay) {
                if (isLight) LIGHT_AD_TEXT else DARK_AD_TEXT
            } else {
                if (isLight) LIGHT_EV_TEXT else DARK_EV_TEXT
            }
            val timeColor = if (allDay) {
                if (isLight) LIGHT_AD_SUB else DARK_AD_SUB
            } else {
                if (isLight) LIGHT_EV_SUB else DARK_EV_SUB
            }

            views.setTextColor(titleId, titleColor)
            views.setTextColor(timeId,  timeColor)
            views.setTextViewText(titleId, title)
            views.setTextViewText(timeId,  time)
        }
    }
}
