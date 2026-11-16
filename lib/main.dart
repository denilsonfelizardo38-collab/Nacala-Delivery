import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Canais Android com som próprio por evento + permissão de notificações.
  final notifications = await NotificationService.create();
  runApp(NacalaDeliveryApp(state: AppState(prefs, notifications: notifications)));
}
