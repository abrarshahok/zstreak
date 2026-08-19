package com.zstreak.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Single-habit widget (spec Section 2/12) — a separate process from the
 * Flutter app, so it only ever reads the last snapshot [WidgetSyncService]
 * (Dart side) wrote here. Renders one of three states per instance:
 * zero-habit empty state, lapsed-subscriber lock, or the live habit.
 */
class HabitWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.habit_widget)
      val habitId = widgetData.getString("widget_habit_$widgetId", null)

      if (habitId == null) {
        showEmptyState(context, views)
      } else {
        val isPremium = widgetData.getString("premium_active", "false") == "true"
        if (!isPremium) {
          showLockedState(context, views)
        } else {
          showHabit(context, views, widgetData, habitId)
        }
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  private fun showEmptyState(context: Context, views: RemoteViews) {
    views.setViewVisibility(R.id.widget_content, View.GONE)
    views.setViewVisibility(R.id.widget_locked, View.GONE)
    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
    val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
    views.setOnClickPendingIntent(R.id.widget_container, openApp)
  }

  private fun showLockedState(context: Context, views: RemoteViews) {
    views.setViewVisibility(R.id.widget_content, View.GONE)
    views.setViewVisibility(R.id.widget_empty, View.GONE)
    views.setViewVisibility(R.id.widget_locked, View.VISIBLE)
    val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
    views.setOnClickPendingIntent(R.id.widget_container, openApp)
  }

  private fun showHabit(
      context: Context,
      views: RemoteViews,
      widgetData: SharedPreferences,
      habitId: String,
  ) {
    views.setViewVisibility(R.id.widget_empty, View.GONE)
    views.setViewVisibility(R.id.widget_locked, View.GONE)
    views.setViewVisibility(R.id.widget_content, View.VISIBLE)

    val name = widgetData.getString("habit_${habitId}_name", null) ?: "Habit"
    val emoji = widgetData.getString("habit_${habitId}_emoji", null) ?: "⭐"
    val streak = widgetData.getString("habit_${habitId}_streak", null) ?: "0"
    val completedToday =
        widgetData.getString("habit_${habitId}_completed_today", "false") == "true"

    views.setTextViewText(R.id.widget_emoji, emoji)
    views.setTextViewText(R.id.widget_name, name)
    views.setTextViewText(R.id.widget_streak, "$streak day streak")
    views.setInt(
        R.id.widget_checkin_button,
        "setImageResource",
        if (completedToday) android.R.drawable.checkbox_on_background
        else android.R.drawable.checkbox_off_background,
    )

    // Tappable without opening the app (spec Section 2) — runs the
    // registered Dart background callback in a headless isolate.
    val checkinIntent =
        HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("zstreakwidget://checkin?habitId=$habitId"),
        )
    views.setOnClickPendingIntent(R.id.widget_checkin_button, checkinIntent)

    val openApp = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
    views.setOnClickPendingIntent(R.id.widget_container, openApp)
  }
}
