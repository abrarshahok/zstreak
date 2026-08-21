import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/notification_orchestrator.dart';
import '../data/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final notificationOrchestratorProvider = Provider<NotificationOrchestrator>(
  (ref) => NotificationOrchestrator(
    notifications: ref.watch(notificationServiceProvider),
    ref: ref,
  ),
);
