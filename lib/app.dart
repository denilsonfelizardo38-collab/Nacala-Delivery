import 'package:flutter/material.dart';

import 'screens/root_shell.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class NacalaDeliveryApp extends StatelessWidget {
  const NacalaDeliveryApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Nacala Entrega',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const RootShell(),
      ),
    );
  }
}
