package com.zstreak.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.DrawableCompat
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
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
          showHabit(context, views, widgetData, habitId, appWidgetManager, widgetId)
        }
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  /**
   * Dragging a widget's resize handles fires this, not [onUpdate] — the
   * base [HomeWidgetProvider]/`AppWidgetProvider` classes don't override
   * it, so without this, nothing re-renders when the widget is resized;
   * the host just stretches or pads whatever was last drawn at the old
   * size into the new bounds, instead of us re-measuring the layout (and
   * recomputing the grid's column count) at the size it's actually being
   * shown at now. Google's own guidance for widgets that don't provide
   * per-size responsive layouts is to react to this callback and push a
   * fresh render — see "Provide flexible widget layouts" ("exact
   * layouts") in the Android widgets docs.
   */
  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) {
    super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    onUpdate(
        context,
        appWidgetManager,
        intArrayOf(appWidgetId),
        HomeWidgetPlugin.getData(context),
    )
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
      appWidgetManager: AppWidgetManager,
      widgetId: Int,
  ) {
    // deleteHabit() clears habit_${id}_* but never clears this widget
    // instance's widget_habit_$widgetId mapping (there's no cheap way
    // from Dart to know which widget ids pointed at the deleted habit).
    // A missing name means the mapped habit no longer exists — fall back
    // to the empty state instead of rendering fabricated placeholder
    // text ("⭐ Habit · 0 day streak") forever.
    val name = widgetData.getString("habit_${habitId}_name", null)
    if (name == null) {
      showEmptyState(context, views)
      return
    }

    views.setViewVisibility(R.id.widget_empty, View.GONE)
    views.setViewVisibility(R.id.widget_locked, View.GONE)
    views.setViewVisibility(R.id.widget_content, View.VISIBLE)

    val emoji = widgetData.getString("habit_${habitId}_emoji", null) ?: "⭐"
    val streak = widgetData.getString("habit_${habitId}_streak", null) ?: "0"
    val completedToday =
        widgetData.getString("habit_${habitId}_completed_today", "false") == "true"
    val colorHex = widgetData.getString("habit_${habitId}_color", null)
    val accentColor =
        try {
          if (colorHex != null) Color.parseColor(colorHex) else null
        } catch (e: IllegalArgumentException) {
          null
        } ?: ContextCompat.getColor(context, R.color.widget_accent)
    // Mirrors HabitTile's isOnFire (>= 7-day streak) badge.
    val isOnFire = (streak.toIntOrNull() ?: 0) >= 7

    views.setTextViewText(R.id.widget_emoji, emoji)
    views.setTextViewText(R.id.widget_name, name)
    views.setTextViewText(R.id.widget_streak, "$streak day streak")
    views.setViewVisibility(
        R.id.widget_fire_badge,
        if (isOnFire) View.VISIBLE else View.GONE,
    )
    views.setViewVisibility(
        R.id.widget_on_fire,
        if (isOnFire) View.VISIBLE else View.GONE,
    )
    // Rendered as a bitmap, not a static background+src drawable pair —
    // a habit's own accent color (like HabitTile's filled-circle-when-
    // done look) is only known at render time.
    views.setImageViewBitmap(
        R.id.widget_checkin_button,
        renderCheckInBitmap(context, completedToday, accentColor),
    )

    // Mini contribution grid — same completed/missed/not-applicable
    // language as HabitTile's grid, rendered as a plain bitmap here since
    // RemoteViews can't do custom Canvas drawing the way the in-app
    // version's CustomPaint does.
    val gridData = widgetData.getString("habit_${habitId}_grid", null)
    if (gridData.isNullOrEmpty()) {
      views.setViewVisibility(R.id.widget_grid, View.GONE)
    } else {
      views.setViewVisibility(R.id.widget_grid, View.VISIBLE)
      views.setImageViewBitmap(
          R.id.widget_grid,
          renderGridBitmap(context, gridData, colorHex, appWidgetManager, widgetId),
      )
    }

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

  /**
   * Draws [gridData] (one char per day, oldest first — see
   * WidgetSyncService._buildGridString: '1' completed, '0' missed, '.'
   * not scheduled) as a bitmap using the exact same fixed 8dp cell / 2dp
   * gap / 2dp corner radius as HabitTile's own CustomPaint grid
   * (_TileMiniGridPainter in habit_tile.dart) — cell size never changes.
   * Both the column count and the row count are computed from the
   * widget's actual current width/height, the same way the in-app grid's
   * LayoutBuilder picks how many weeks fit, instead of a fixed
   * count-of-cells stretched to fill (which is what was distorting cells
   * into pills whenever a widget got resized off its original aspect
   * ratio — scaling cell *size* to fill leftover height has the same
   * problem, just along the other axis). The row count grows from 7 up
   * to MAX_ROWS=9 with the widget's actual granted height, so a modestly
   * taller placement fills with more rows instead of leftover space;
   * beyond that cap, habit_widget.xml's spacer pair takes over and
   * centers the whole (header + grid) block instead of growing the grid
   * further. A plain bitmap is the only practical way to get this visual
   * in a RemoteViews widget, which has no custom-drawing view of its
   * own.
   */
  private fun renderGridBitmap(
      context: Context,
      gridData: String,
      colorHex: String?,
      appWidgetManager: AppWidgetManager,
      widgetId: Int,
  ): Bitmap {
    val density = context.resources.displayMetrics.density
    val cellPx = GRID_CELL_DP * density
    val gapPx = GRID_GAP_DP * density
    val stepPx = cellPx + gapPx
    val stepDp = GRID_CELL_DP + GRID_GAP_DP

    val options = appWidgetManager.getAppWidgetOptions(widgetId)

    val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
    val availableWidthDp = widthDp - CONTENT_PADDING_DP * 2
    val cols = (availableWidthDp / stepDp).toInt().coerceIn(MIN_COLS, MAX_COLS)

    // widget_grid fills the leftover vertical room in the widget cell
    // (layout_height="0dp" + weight="1" in habit_widget.xml) after the
    // fixed-height header — so the row count fills that room with more
    // same-size cells instead of a fixed row count leaving a fitCenter
    // letterbox gap above/below.
    //
    // OPTION_APPWIDGET_MAX_HEIGHT, not MIN_HEIGHT, is the widget's
    // portrait-mode height — AppWidgetOptions naming pairs portrait
    // width with MIN_WIDTH (used above) but portrait height with
    // MAX_HEIGHT; MIN_HEIGHT is actually the (shorter) landscape height.
    val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 250)
    val availableHeightDp = heightDp - CONTENT_PADDING_DP * 2 - HEADER_HEIGHT_DP - GRID_MARGIN_TOP_DP
    val rows = (availableHeightDp / stepDp).toInt().coerceIn(MIN_ROWS, MAX_ROWS)

    val widthPx = (cols * stepPx - gapPx).toInt().coerceAtLeast(1)
    val heightPx = (rows * stepPx - gapPx).toInt().coerceAtLeast(1)

    val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint().apply { isAntiAlias = true }

    val accentColor =
        try {
          if (colorHex != null) Color.parseColor(colorHex) else null
        } catch (e: IllegalArgumentException) {
          null
        } ?: ContextCompat.getColor(context, R.color.widget_accent)
    val accentR = Color.red(accentColor)
    val accentG = Color.green(accentColor)
    val accentB = Color.blue(accentColor)
    val emptyColor = ContextCompat.getColor(context, R.color.widget_grid_empty)
    val missedColor = ContextCompat.getColor(context, R.color.widget_grid_missed)

    // Only the most recent cols*rows days render — gridData is written
    // with plenty of headroom (WidgetSyncService.gridDays) so there's
    // always enough history for however many columns/rows fit.
    val totalCells = cols * rows
    val statuses =
        if (gridData.length > totalCells) gridData.takeLast(totalCells) else gridData
    val radius = GRID_RADIUS_DP * density

    for (i in statuses.indices) {
      val col = i / rows
      val row = i % rows
      val c = statuses[i]
      paint.color =
          when {
            c == '0' -> missedColor
            c in '1'..'9' ->
                // Bucket 1..9 mirrors _TileMiniGridPainter's
                // `(runLength / 7).clamp(0.4, 1.0)` alpha ramp — drawn as
                // a translucent accent color over the card's own
                // surface, same as the in-app CustomPaint does, rather
                // than a flattened solid color.
                Color.argb(intensityAlpha(c - '0'), accentR, accentG, accentB)
            else -> emptyColor
          }
      val x = col * stepPx
      val y = row * stepPx
      canvas.drawRoundRect(RectF(x, y, x + cellPx, y + cellPx), radius, radius, paint)
    }

    return bitmap
  }

  private fun intensityAlpha(bucket: Int): Int {
    val intensity = 0.4 + (bucket - 1) / 8.0 * 0.6
    return (intensity * 255).toInt().coerceIn(0, 255)
  }

  /**
   * Draws the check-in toggle exactly like HabitTile's `_CheckInToggle`:
   * done → a filled circle in the habit's own accent color with a
   * contrasting checkmark; not done → a transparent circle with a faint
   * themed border and a faint "+". A per-habit accent color is only
   * known at render time, so — like the grid — this has to be a bitmap
   * rather than a static background+src drawable pair.
   */
  private fun renderCheckInBitmap(
      context: Context,
      completedToday: Boolean,
      accentColor: Int,
  ): Bitmap {
    val density = context.resources.displayMetrics.density
    val sizePx = (CHECKIN_SIZE_DP * density).toInt().coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val paint = Paint().apply { isAntiAlias = true }
    val cx = sizePx / 2f
    val cy = sizePx / 2f
    val isDark = isDarkTheme(context)

    if (completedToday) {
      paint.style = Paint.Style.FILL
      paint.color = accentColor
      canvas.drawCircle(cx, cy, sizePx / 2f, paint)
      drawTintedIcon(
          canvas,
          context,
          R.drawable.ic_widget_check,
          contrastForeground(accentColor),
          cx,
          cy,
          (CHECKIN_ICON_DONE_DP * density).toInt(),
      )
    } else {
      paint.style = Paint.Style.STROKE
      paint.strokeWidth = CHECKIN_BORDER_DP * density
      paint.color =
          if (isDark) Color.argb(51, 255, 255, 255) else Color.argb(38, 0, 0, 0)
      val strokeInset = paint.strokeWidth / 2f
      canvas.drawCircle(cx, cy, sizePx / 2f - strokeInset, paint)
      drawTintedIcon(
          canvas,
          context,
          R.drawable.ic_widget_add,
          if (isDark) Color.argb(77, 255, 255, 255) else Color.argb(64, 0, 0, 0),
          cx,
          cy,
          (CHECKIN_ICON_UNDONE_DP * density).toInt(),
      )
    }

    return bitmap
  }

  private fun drawTintedIcon(
      canvas: Canvas,
      context: Context,
      resId: Int,
      tint: Int,
      cx: Float,
      cy: Float,
      sizePx: Int,
  ) {
    val drawable = ContextCompat.getDrawable(context, resId)?.mutate() ?: return
    DrawableCompat.setTint(drawable, tint)
    val half = sizePx / 2
    drawable.setBounds(
        (cx - half).toInt(),
        (cy - half).toInt(),
        (cx + half).toInt(),
        (cy + half).toInt(),
    )
    drawable.draw(canvas)
  }

  private fun isDarkTheme(context: Context): Boolean {
    val mode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
    return mode == Configuration.UI_MODE_NIGHT_YES
  }

  /** Mirrors color_hex.dart's `contrastForeground` (WCAG relative luminance). */
  private fun contrastForeground(background: Int): Int =
      if (relativeLuminance(background) > 0.179) Color.BLACK else Color.WHITE

  private fun relativeLuminance(color: Int): Double {
    fun linearize(channel: Int): Double {
      val v = channel / 255.0
      return if (v <= 0.03928) v / 12.92 else Math.pow((v + 0.055) / 1.055, 2.4)
    }
    val r = linearize(Color.red(color))
    val g = linearize(Color.green(color))
    val b = linearize(Color.blue(color))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
  }

  companion object {
    private const val GRID_CELL_DP = 8f
    private const val GRID_GAP_DP = 2f
    private const val GRID_RADIUS_DP = 2f
    private const val CONTENT_PADDING_DP = 12
    // habit_widget.xml's fixed-height header row (44dp emoji badge, the
    // tallest element in it) and the grid's own layout_marginTop — the
    // portion of widget height that isn't available to the grid itself.
    private const val HEADER_HEIGHT_DP = 44
    private const val GRID_MARGIN_TOP_DP = 10
    // Same bounds as HabitTile's own `cols = (availableWidth /
    // _step).floor().clamp(4, 52)` in habit_tile.dart.
    private const val MIN_COLS = 4
    private const val MAX_COLS = 52
    // HabitTile itself always shows 7 rows (fixed-height in-app tile);
    // the widget's rows instead scale with whatever height it's placed
    // at, floored at 7 so it never shows less than a full week, capped
    // at 9 so a very tall placement doesn't grow the grid indefinitely —
    // habit_widget.xml's spacer pair around widget_content absorbs
    // anything beyond that, centering the (header + up-to-9-row grid)
    // block instead.
    private const val MIN_ROWS = 7
    private const val MAX_ROWS = 9
    private const val CHECKIN_SIZE_DP = 40f
    private const val CHECKIN_BORDER_DP = 1.5f
    private const val CHECKIN_ICON_DONE_DP = 20f
    private const val CHECKIN_ICON_UNDONE_DP = 18f
  }
}
