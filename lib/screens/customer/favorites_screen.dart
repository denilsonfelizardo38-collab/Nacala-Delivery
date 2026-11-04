import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'store_screen.dart';

/// Restaurantes e parceiros guardados pelo utilizador (dados reais do
/// servidor). Convidados são convidados a iniciar sessão.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Establishment>? _favorites;
  Object? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_favorites == null && _loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final favorites = await AppScope.of(context).api.favorites();
      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _loading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final favorites = await AppScope.of(context).api.favorites();
    if (mounted) setState(() => _favorites = favorites);
  }

  Future<void> _toggleFavorite(Establishment establishment) async {
    final state = AppScope.of(context);
    try {
      await state.toggleFavoriteEstablishment(establishment.id);
      if (!mounted) return;
      if (!state.isFavoriteEstablishment(establishment.id)) {
        setState(
          () => _favorites = _favorites
              ?.where((item) => item.id != establishment.id)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Não foi possível atualizar os favoritos.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    if (state.isGuest || !state.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favoritos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Os teus favoritos são da tua conta',
              message:
                  'Entra ou cria uma conta para guardar os teus locais '
                  'preferidos.',
              actionLabel: 'Entrar ou criar conta',
              onAction: state.exitGuestMode,
            ),
          ),
        ),
      );
    }

    final favorites = _favorites;

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: _loading
              ? const LoadingBlock(height: 320)
              : _error != null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ErrorState(
                      message: messageForError(_error),
                      onRetry: _load,
                    ),
                  ],
                )
              : favorites == null || favorites.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Ainda sem favoritos',
                      message:
                          'Toca no coração num estabelecimento para o '
                          'guardares aqui.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final establishment = favorites[index];
                    return EstablishmentTile(
                      establishment: establishment,
                      isFavorite: state.isFavoriteEstablishment(
                        establishment.id,
                      ),
                      onFavoriteToggle: () => _toggleFavorite(establishment),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              StoreScreen(establishmentId: establishment.id),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
