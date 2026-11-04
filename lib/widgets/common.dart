import 'package:flutter/material.dart';

import '../state/app_scope.dart';
import '../core/api_client.dart';
import '../core/formatters.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

const pagePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

IconData categoryIconFor(String icon) => switch (icon) {
  'restaurant' || 'restaurantes' => Icons.restaurant_rounded,
  'basket' || 'mercados' || 'supermercados' => Icons.shopping_basket_rounded,
  'pharmacy' || 'farmacias' => Icons.local_pharmacy_rounded,
  'store' || 'lojas' => Icons.storefront_rounded,
  'bakery' || 'padarias' => Icons.bakery_dining_rounded,
  'drinks' || 'bebidas' => Icons.local_bar_rounded,
  'butchery' || 'talhos' => Icons.kebab_dining_rounded,
  'fish' || 'peixarias' => Icons.set_meal_rounded,
  _ => Icons.category_rounded,
};

/// Cartão base do sistema de design.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Material(
        color: color ?? context.cardColor,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: borderColor ?? context.lineColor),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Continuar com Google',
  });

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Constrói conteúdo assíncrono com estados de carregamento, erro e vazio.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.loadingHeight = 180,
    this.emptyMessage,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;
  final double loadingHeight;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingBlock(height: loadingHeight);
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: messageForError(snapshot.error),
            onRetry: onRetry,
          );
        }
        if (!snapshot.hasData) {
          return EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sem dados',
            message: emptyMessage ?? 'Ainda não há informação para mostrar.',
            actionLabel: onRetry == null ? null : 'Tentar novamente',
            onAction: onRetry,
          );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

String messageForError(Object? error) {
  if (error is ApiException) return error.message;
  return 'Não foi possível carregar a informação. Tente novamente.';
}

/// Bloco de skeleton animado para estados de carregamento. Substitui
/// indicadores vazios: pulsa suavemente e respeita o tema (claro/escuro).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});

  /// `null` ocupa toda a largura disponível.
  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.isDarkMode
        ? AppColors.darkElevated
        : const Color(0xFFE9E9ED);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          Opacity(opacity: 0.55 + (_controller.value * 0.35), child: child),
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Linha de skeleton com ícone/avatar + duas linhas de texto.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
      child: Row(
        children: [
          const Skeleton(width: 64, height: 64, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(width: compact ? 120 : 170, height: 13, radius: 6),
                const SizedBox(height: 8),
                const Skeleton(height: 11, radius: 6),
                if (!compact) ...[
                  const SizedBox(height: 6),
                  const Skeleton(width: 220, height: 11, radius: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.height = 160});
  final double height;

  @override
  Widget build(BuildContext context) {
    // Skeleton em vez de spinner: silencioso e consistente com o tema.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height * 0.55, maxHeight: height),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [SkeletonListTile(), SkeletonListTile()],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 24 : 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.mutedColor),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.danger,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Algo não correu bem',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.mutedColor),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Imagem remota com substituto gráfico quando não existe ou falha.
class NetworkThumb extends StatelessWidget {
  const NetworkThumb({
    super.key,
    required this.imageUrl,
    this.icon = Icons.storefront_rounded,
    this.size = 64,
    this.radius = 16,
    this.color,
  });

  final String? imageUrl;
  final IconData icon;
  final double size;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? AppColors.primarySoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: AppColors.primary, size: size * 0.42),
    );
    final url = imageUrl;
    if (url == null || url.trim().isEmpty) return fallback;
    // Decodifica o ficheiro à dimensão real de apresentação (com margem
    // para o devicePixelRatio): essencial em telemóveis de gama baixa,
    // onde fotografias originais (1200+ px) estouram a memória.
    final cacheWidth =
        (size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1) * 1.35)
            .round()
            .clamp(96, 1024);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback;
        },
      ),
    );
  }
}

/// Largura de cache para imagens grandes (capas de estabelecimento).
/// As fotos dos parceiros podem ter até ~1600 px; decodificá-las na
/// dimensão apresentada reduz o uso de memória em Android Android de
/// gama baixa sem perda visual.
int imageCacheWidthFor(BuildContext context, double logicalWidth) =>
    (logicalWidth * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1) * 1.15)
        .round()
        .clamp(320, 1280);

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final String status;
  final String? label;

  static (Color, Color) colorsFor(String status, BuildContext context) {
    switch (status) {
      case 'delivered':
      case 'completed':
      case 'accepted':
        return (
          context.successColor.withValues(alpha: 0.12),
          context.successColor,
        );
      case 'cancelled':
      case 'rejected':
      case 'declined':
        return (AppColors.danger.withValues(alpha: 0.10), context.dangerColor);
      case 'pending':
      case 'preparing':
      case 'available':
        return (
          AppColors.warning.withValues(alpha: 0.16),
          context.warningColor,
        );
      default:
        return (AppColors.primary.withValues(alpha: 0.10), context.accentColor);
    }
  }

  static String labelFor(String status) => switch (status) {
    'pending' => 'Pendente',
    'confirmed' => 'Confirmado',
    'preparing' => 'A preparar',
    'ready' => 'Pronto',
    'on_the_way' => 'Em entrega',
    'delivered' => 'Entregue',
    'cancelled' => 'Cancelado',
    'rejected' => 'Rejeitado',
    'available' => 'Disponível',
    'accepted' => 'Aceite',
    'completed' => 'Concluída',
    'declined' => 'Recusada',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = colorsFor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? labelFor(status),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.min = 1,
    this.max = 99,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppColors.darkElevated : AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.lineColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            tooltip: 'Diminuir quantidade',
            onPressed: quantity <= min ? null : onDecrement,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 30),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            tooltip: 'Aumentar quantidade',
            onPressed: quantity >= max ? null : onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: context.inkColor,
        disabledForegroundColor: context.mutedColor.withValues(alpha: 0.4),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = MetricTone.primary,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final MetricTone tone;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      MetricTone.primary => context.accentColor,
      MetricTone.success => context.successColor,
      MetricTone.warning => context.warningColor,
      MetricTone.danger => context.dangerColor,
    };
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.mutedColor),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

enum MetricTone { primary, success, warning, danger }

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Pesquisar',
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: AppColors.bg,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Limpar pesquisa',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                  onClear?.call();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              );
            },
          ),
        ),
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.count,
    this.size = 14,
  });

  final double rating;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: context.warningColor, size: size + 2),
        const SizedBox(width: 3),
        Text(
          rating <= 0 ? 'Novo' : formatRating(rating),
          style: TextStyle(
            color: context.inkColor,
            fontSize: size - 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($count)',
            style: TextStyle(color: context.mutedColor, fontSize: size - 2),
          ),
        ],
      ],
    );
  }
}

class PriceLine extends StatelessWidget {
  const PriceLine({
    super.key,
    required this.label,
    required this.cents,
    this.strong = false,
    this.color,
  });

  final String label;
  final int cents;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.mutedColor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            formatMoney(cents),
            style: style?.copyWith(
              color: color ?? (strong ? context.inkColor : null),
              fontWeight: strong ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color ?? context.mutedColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color ?? context.mutedColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de estabelecimento usada na home e nas categorias.
class EstablishmentTile extends StatelessWidget {
  const EstablishmentTile({
    super.key,
    required this.establishment,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  final Establishment establishment;
  final VoidCallback onTap;
  final bool isFavorite;

  /// Quando definido, mostra um botão de favorito (coração).
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final open = establishment.isOpen;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkThumb(
            imageUrl: establishment.imageUrl,
            icon: categoryIconFor(establishment.categorySlug),
            size: 72,
            radius: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        establishment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      status: open ? 'accepted' : 'cancelled',
                      label: open ? 'Aberto' : 'Fechado',
                    ),
                    if (onFavoriteToggle != null) ...[
                      const SizedBox(width: 4),
                      FavoriteIconButton(
                        isFavorite: isFavorite,
                        onPressed: onFavoriteToggle!,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  establishment.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.mutedColor),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StarRating(
                      rating: establishment.rating,
                      count: establishment.reviewCount,
                    ),
                    _Meta(
                      icon: Icons.delivery_dining_rounded,
                      text: formatMoney(establishment.deliveryFeeCents),
                    ),
                    _Meta(
                      icon: Icons.schedule_rounded,
                      text: '${establishment.prepMinutes} min',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão de favorito em forma de coração. [onDark] usa fundo branco
/// translúcido para pousar sobre fotografias.
class FavoriteIconButton extends StatelessWidget {
  const FavoriteIconButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.onDark = false,
  });

  final bool isFavorite;
  final VoidCallback onPressed;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final heart = Icon(
      isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      color: isFavorite
          ? AppColors.primary
          : onDark
          ? AppColors.ink
          : context.mutedColor,
      size: onDark ? 17 : 21,
    );
    if (!onDark) {
      return IconButton(
        tooltip: isFavorite ? 'Remover dos favoritos' : 'Guardar nos favoritos',
        onPressed: onPressed,
        icon: heart,
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return Material(
      shape: const CircleBorder(),
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 2,
      child: IconButton(
        tooltip: isFavorite ? 'Remover dos favoritos' : 'Guardar nos favoritos',
        onPressed: onPressed,
        icon: heart,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: const Size(34, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.mutedColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: context.mutedColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onDark ? Colors.white : AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: Icon(
        Icons.delivery_dining_rounded,
        color: onDark
            ? AppColors.primary
            : Theme.of(context).colorScheme.onPrimary,
        size: size * 0.5,
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.avatarUrl,
  });

  final String name;
  final double size;

  /// URL absoluto (`/uploads/...`) ou completo. Se definido e a imagem
  /// carregar, mostra a fotografia; caso contrário as iniciais.
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    final fallback = _InitialsAvatar(name: name, size: size);
    if (url == null || url.trim().isEmpty) return fallback;
    // Resolve URLs relativas ao host da API corrente.
    final resolved = url.startsWith('http')
        ? url
        : Uri.parse(AppScope.of(context).apiBaseUrl).resolve(url).toString();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.32),
      child: Image.network(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Alterna um estabelecimento nos favoritos com feedback de snackbar.
/// Convidados são convidados a iniciar sessão.
Future<void> toggleFavorite(BuildContext context, String id) async {
  final state = AppScope.of(context);
  if (state.isGuest || !state.isSignedIn) {
    showAppSnack(context, 'Entra ou cria uma conta para guardar favoritos.');
    return;
  }
  try {
    final added = await state.toggleFavoriteEstablishment(id);
    if (context.mounted) {
      showAppSnack(
        context,
        added ? 'Adicionado aos favoritos.' : 'Removido dos favoritos.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnack(
        context,
        'Não foi possível atualizar os favoritos.',
        error: true,
      );
    }
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size(0, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  String? initialValue,
  String hint = '',
  int maxLines = 1,
  String confirmLabel = 'Guardar',
  bool allowEmpty = false,
}) async {
  final controller = TextEditingController(text: initialValue);
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? (allowEmpty ? null : 'Preencha este campo.')
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(controller.text.trim());
            }
          },
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
