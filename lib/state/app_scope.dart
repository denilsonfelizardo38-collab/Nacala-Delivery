import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Disponibiliza o [AppState] a toda a árvore de widgets.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope não encontrado no contexto.');
    return scope!.notifier!;
  }
}
