package com.memorystack.memory_stack

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home screen widget: the streak on a flame tile, and this week's days.
 * The app writes the numbers (see lib/data/home_widget.dart); "week" is 7 letters, Monday first:
 * d = done, m = missed, t = today (not yet), f = ahead.
 */
class ReviewWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val due = widgetData.getInt("due", 0)
        val streak = widgetData.getInt("streak", 0)
        val level = widgetData.getString("level", "") ?: ""
        val week = (widgetData.getString("week", "") ?: "").padEnd(7, 'f')
        val names = arrayOf("M", "T", "W", "T", "F", "S", "S")
        val dayIds = intArrayOf(R.id.day0, R.id.day1, R.id.day2, R.id.day3, R.id.day4, R.id.day5, R.id.day6)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.review_widget).apply {
                setTextViewText(R.id.widget_streak, streak.toString())
                setTextViewText(R.id.widget_title, if (level.isEmpty()) "Daily goal" else level)
                setTextViewText(R.id.widget_due, if (due == 0) "Nothing due. Nice!" else "$due ${if (due == 1) "review" else "reviews"} due")
                dayIds.forEachIndexed { i, dayId ->
                    val (mark, bg, color) = when (week[i]) {
                        'd' -> Triple("✓", R.drawable.widget_day_done, "#16A34A")
                        'm' -> Triple("!", R.drawable.widget_day_missed, "#DC2626")
                        't' -> Triple("◔", R.drawable.widget_day_today, "#2563EB")
                        else -> Triple("○", R.drawable.widget_day_future, "#9CA3AF")
                    }
                    setTextViewText(dayId, "$mark\n${names[i]}")
                    setInt(dayId, "setBackgroundResource", bg)
                    setTextColor(dayId, Color.parseColor(color))
                }
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
