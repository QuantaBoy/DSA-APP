package com.memorystack.memory_stack

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home screen widget: reviews due today and the streak. The app writes the numbers (see lib/data/home_widget.dart). */
class ReviewWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val due = widgetData.getInt("due", 0)
        val streak = widgetData.getInt("streak", 0)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.review_widget).apply {
                setTextViewText(R.id.widget_due, due.toString())
                setTextViewText(R.id.widget_due_label, if (due == 1) "review due" else "reviews due")
                setTextViewText(R.id.widget_streak, "🔥 $streak day streak")
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
