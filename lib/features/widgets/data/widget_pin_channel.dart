import 'package:flutter/services.dart';

/// Bridges to MainActivity.kt's own requestPinAppWidget() call — deliberately
/// separate from the `home_widget` plugin's own `requestPinWidget()`, which
/// passes no successCallback and so has no way to know a pin actually
/// completed. See MainActivity.kt's class doc for why that matters: on at
/// least one real launcher, requestPinAppWidget() binds the widget without
/// ever running its configure activity, unlike a manual drag-and-drop add.
const _channel = MethodChannel('com.zstreak.app/widget_pin');

/// Requests the OS pin a habit widget instance to the home screen.
Future<void> requestPinHabitWidget() =>
    _channel.invokeMethod('requestPinWidget');

/// Calls [onPinned] with the newly-bound widget's id once the user confirms
/// placing it — the app's own substitute for the configure step the
/// launcher doesn't invoke on its own for this flow. Register once, for
/// the app's lifetime.
void listenForPinnedHabitWidget(void Function(int widgetId) onPinned) {
  _channel.setMethodCallHandler((call) async {
    if (call.method == 'onWidgetPinned') {
      onPinned(call.arguments as int);
    }
  });
}
