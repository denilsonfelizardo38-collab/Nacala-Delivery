import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_service.dart';
import '../models/models.dart';

/// Notificações no próprio telemóvel (barra de estado) com **som próprio por
/// evento**: cada kind da API tem um canal Android dedicado em
/// `android/app/src/main/res/raw`.
///
/// O servidor guarda as notificações em `notifications`; este serviço faz
/// polling a `/api/notifications` e mostra no ecrã as que ainda não foram
/// vistas (o último id visto fica em SharedPreferences).
class NotificationService {
  NotificationService._(this._plugin, this._prefs);

  static const _lastSeenKey = 'nacala.notifications.lastSeen.v1';
  static const _pollInterval = Duration(seconds: 20);

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _prefs;

  Timer? _timer;
  NacalaApi? _api;
  bool _busy = false;

  /// Um canal por som, para o Android tocar o som certo em cada evento.
  static const _channels = <String, (String, String, String)>{
    'nacala_order_confirmed': (
      'Pedidos aceites',
      'O estabelecimento aceitou o teu pedido',
      'snd_order_confirmed',
    ),
    'nacala_order_preparing': (
      'Em preparação',
      'O teu pedido está a ser preparado',
      'snd_order_preparing',
    ),
    'nacala_order_ready': (
      'Pedidos prontos',
      'O teu pedido está pronto para sair',
      'snd_order_ready',
    ),
    'nacala_order_on_the_way': (
      'A caminho',
      'O estafeta está a caminho',
      'snd_order_on_the_way',
    ),
    'nacala_order_delivered': (
      'Entregues',
      'O teu pedido foi entregue',
      'snd_order_delivered',
    ),
    'nacala_order_alert': (
      'Pedidos recusados/cancelados',
      'Houve um problema com o teu pedido',
      'snd_order_rejected',
    ),
    'nacala_new_order': (
      'Novos pedidos (parceiro)',
      'Chegou um novo pedido à tua loja',
      'snd_new_order',
    ),
    'nacala_default': (
      'Nacala Entrega',
      'Atualizações da plataforma',
      'snd_default',
    ),
  };

  /// Mapeia o `kind` da notificação da API para o id do canal (e som).
  static String channelFor(String kind) => switch (kind) {
    'order_confirmed' => 'nacala_order_confirmed',
    'order_preparing' => 'nacala_order_preparing',
    'order_ready' => 'nacala_order_ready',
    'order_on_the_way' => 'nacala_order_on_the_way',
    'order_delivered' => 'nacala_order_delivered',
    'order_rejected' || 'order_cancelled' => 'nacala_order_alert',
    'new_order' => 'nacala_new_order',
    _ => 'nacala_default',
  };

  static Future<NotificationService> create() async {
    final plugin = FlutterLocalNotificationsPlugin();
    final prefs = await SharedPreferences.getInstance();
    final service = NotificationService._(plugin, prefs);
    await service._init();
    return service;
  }

  Future<void> _init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onTap,
    );
    if (!Platform.isAndroid) return;
    // Cria os canais com o som de cada evento (Android 8+; o som vive no canal).
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final entry in _channels.entries) {
      final (name, description, sound) = entry.value;
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          entry.key,
          name,
          description: description,
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound(sound),
          playSound: true,
        ),
      );
    }
    // Android 13+: pedir a permissão de notificações em runtime.
    await androidPlugin?.requestNotificationsPermission();
  }

  void _onTap(NotificationResponse response) {
    // A navegação por payload fica para o ecrã de notificações; aqui só
    // garantimos que o toque não passa despercebido.
    debugPrint('Notificação tocada: ${response.payload}');
  }

  /// Liga o polling enquanto houver sessão iniciada.
  ///
  /// Corre uma primeira vez de imediato (para apanhar o que chegou com a
  /// app fechada) e depois a cada [_pollInterval].
  void start(NacalaApi api) {
    stop();
    _api = api;
    _timer = Timer.periodic(_pollInterval, (_) => poll());
    unawaited(poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _api = null;
  }

  /// Vai buscar as notificações novas e mostra-as no ecrã com o som do evento.
  ///
  /// Só mostra o que é mais recente que o último id visto (guardado em
  /// SharedPreferences): a lista do servidor vem da mais recente para a mais
  /// antiga, por isso percorre-a até encontrar a referência — sem isto, cada
  /// ciclo voltava a tocar as ~30 notificações antigas.
  Future<void> poll() async {
    final api = _api;
    if (api == null || _busy) return;
    _busy = true;
    try {
      final items = await api.notifications(limit: 30);
      if (items.isEmpty) return;
      final lastSeen = _prefs.getString(_lastSeenKey);
      if (lastSeen == null) {
        // Primeira consulta desta conta: regista o mais recente sem
        // re-exibir o histórico todo de uma vez.
        await _prefs.setString(_lastSeenKey, items.first.id);
        return;
      }
      for (final item in items) {
        if (item.id == lastSeen) break;
        await show(item);
      }
      // Itens vêm por ordem cronológica desc; o primeiro é o mais recente.
      if (items.first.id != lastSeen) {
        await _prefs.setString(_lastSeenKey, items.first.id);
      }
    } catch (_) {
      // Sem rede ou sem sessão: o próximo ciclo tenta de novo.
    } finally {
      _busy = false;
    }
  }

  /// Mostra uma notificação no telemóvel com o canal (som) do seu evento.
  Future<void> show(AppNotification notification) async {
    final channelId = channelFor(notification.kind);
    final sound = _channels[channelId]?.$3 ?? 'snd_default';
    await _plugin.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _channels[channelId]?.$1 ?? 'Nacala Entrega',
          channelDescription: _channels[channelId]?.$2,
          importance: Importance.high,
          priority: Priority.high,
          sound: RawResourceAndroidNotificationSound(sound),
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: notification.data['order_id'] as String?,
    );
  }
}
