package com.zstreak.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Settings' "Add home screen widget" button calls AppWidgetManager's
 * requestPinAppWidget() (via the channel below) instead of relying on the
 * user manually dragging the widget from the OS's long-press widget tray.
 * That API is documented to invoke the provider's configure Activity the
 * same as a manual add, but on this launcher (confirmed via logcat: Pixel/
 * Nexus Launcher) it doesn't — the widget gets bound directly with no
 * chance to pick a habit. requestPinAppWidget()'s successCallback
 * PendingIntent is the one hook it does honor, so this drives the
 * "choose a habit" step itself from there instead of depending on the
 * launcher to do it.
 */
class MainActivity : FlutterActivity() {
  private var pinChannel: MethodChannel? = null

  // Android 15 (API 35) makes edge-to-edge the default for apps
  // targeting it and Play Console's pre-launch report wants explicit
  // evidence of handling it — styles.xml's transparent system bar colors
  // and main.dart's SystemChrome.setEnabledSystemUIMode already draw
  // Flutter's content behind the bars, but the recommended
  // androidx.activity.enableEdgeToEdge() helper isn't callable here:
  // it's an extension on androidx.activity.ComponentActivity, and
  // FlutterActivity extends the plain platform android.app.Activity, not
  // that. setDecorFitsSystemWindows(false) is the actual mechanism
  // enableEdgeToEdge() calls under the hood and works on any Activity's
  // Window directly, so it's the correct manual equivalent here.
  override fun onCreate(savedInstanceState: Bundle?) {
    WindowCompat.setDecorFitsSystemWindows(window, false)
    super.onCreate(savedInstanceState)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    channel.setMethodCallHandler { call, result ->
      if (call.method == "requestPinWidget") {
        requestPinWidget()
        result.success(null)
      } else {
        result.notImplemented()
      }
    }
    pinChannel = channel
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    handlePinConfirmedIntent(intent)
  }

  private fun handlePinConfirmedIntent(intent: Intent?) {
    if (intent?.action != ACTION_WIDGET_PIN_CONFIRMED) return
    val id =
        intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
    if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
      pinChannel?.invokeMethod("onWidgetPinned", id)
    }
  }

  private fun requestPinWidget() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val appWidgetManager = AppWidgetManager.getInstance(this)
    if (!appWidgetManager.isRequestPinAppWidgetSupported) return

    val provider = ComponentName(this, HabitWidgetProvider::class.java)
    val callbackIntent =
        Intent(this, MainActivity::class.java).apply {
          action = ACTION_WIDGET_PIN_CONFIRMED
          flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
    // FLAG_MUTABLE is required — the system fills EXTRA_APPWIDGET_ID into
    // this intent once the user confirms the pin, and can't do that to an
    // immutable PendingIntent.
    val successCallback =
        PendingIntent.getActivity(
            this,
            0,
            callbackIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
    appWidgetManager.requestPinAppWidget(provider, null, successCallback)
  }

  companion object {
    private const val CHANNEL = "com.zstreak.app/widget_pin"
    private const val ACTION_WIDGET_PIN_CONFIRMED = "com.zstreak.app.ACTION_WIDGET_PIN_CONFIRMED"
  }
}
