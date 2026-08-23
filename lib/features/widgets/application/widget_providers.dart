import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/widget_sync_service.dart';

final widgetSyncServiceProvider = Provider<WidgetSyncService>(
  (ref) => WidgetSyncService(),
);
