import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Disponibilidade de rede detectada em tempo real (com fallback para
/// "online" quando a plataforma não responde — ex.: testes).
class NetworkBanner extends StatefulWidget {
  const NetworkBanner({super.key, required this.child});

  final Widget child;

  @override
  State<NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<NetworkBanner> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final connectivity = Connectivity();
    // Estado inicial: sem suporte de plataforma (testes) mantém "online"
    // e não subscreve o stream — a ativação do EventChannel também
    // falharia e o erro seria reportado ao FlutterError do teste.
    final List<ConnectivityResult> initial;
    try {
      initial = await connectivity.checkConnectivity();
    } catch (_) {
      // Ambiente sem canal de plataforma — seguir em frente.
      return;
    }
    _apply(initial);
    try {
      _subscription = connectivity.onConnectivityChanged.listen(
        _apply,
        onError: (_) {},
      );
    } catch (_) {
      // Sem eventos de conectividade disponíveis.
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    if (!mounted || offline == _offline) return;
    setState(() => _offline = offline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return widget.child;
    final top = MediaQuery.maybePaddingOf(context)?.top ?? 0;
    return Column(
      children: [
        Material(
          color: AppColors.primary,
          child: Padding(
            padding: EdgeInsets.only(top: top, left: 16, right: 16, bottom: 8),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Sem ligação à internet — a reconectar…',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
