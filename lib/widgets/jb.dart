/// Componentes partilhados no padrão visual Já Bazou.
///
/// Cada widget reproduz um elemento do referencial (web): `page-head`
/// com `h-display`, `h-sec` com contagem, `srow` (linha de loja),
/// `pcard` (cartão de produto), `favchip`, `pills` (categorias) e
/// `hero` (cabeçalho da página inicial). As cores, raios e tipografia
/// vêm do tema — os tokens já são idênticos aos do referencial.
library;

import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Título de página no padrão `page-head`: botão circular opcional,
/// título display grande (ExtraBold, tracking negativo) e subtítulo
/// suave por baixo.
class JbPageHeader extends StatelessWidget {
  const JbPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 6),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (onBack != null) ...[
            _IconBtnCircle(icon: Icons.arrow_back_rounded, onTap: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFontFamily,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    letterSpacing: -0.7,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedColor, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Botão circular de 44 px (`.icon-btn`): fundo `--s1`, hover `--s3`.
class _IconBtnCircle extends StatelessWidget {
  const _IconBtnCircle({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkCard,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 21, color: context.inkColor),
        ),
      ),
    );
  }
}

/// Cabeçalho de secção no padrão `h-sec`: título display bold, contagem
/// suave ao lado (`<small>`) e acção vermelha opcional à direita.
class JbSectionHeader extends StatelessWidget {
  const JbSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.margin = const EdgeInsets.only(top: 22, bottom: 10),
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Título com prioridade larga: ocupa o espaço livre e comprime-se
          // com reticências em vez de rebentar o `Row` em ecrãs estreitos.
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.displayFontFamily,
                fontSize: 18.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.2,
                color: Colors.white,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 7),
            Text(
              '$count',
              style: TextStyle(
                color: context.mutedColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primarySecondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 36),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Selo Aberto/Fechado no padrão `.badge`: fundo verde escuro ou cinza,
/// texto 11,5 px bold.
class OpenBadge extends StatelessWidget {
  const OpenBadge({super.key, required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFF0D2417) : AppColors.darkElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? 'Aberto' : 'Fechado',
        style: TextStyle(
          color: isOpen ? AppColors.success : AppColors.mutedLight,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Chip de avaliação no padrão `.rating-chip`: estrela e valor dourados
/// (`--gold`), com contagem suave; sem avaliações mostra "Novo" em cinza.
class RatingChip extends StatelessWidget {
  const RatingChip({
    super.key,
    required this.rating,
    this.count,
    this.size = 13,
  });

  final double rating;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNew = rating <= 0;
    final color = isNew ? context.mutedColor : AppColors.warning;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: color, size: size + 3),
        const SizedBox(width: 3),
        Text(
          isNew ? 'Novo' : formatRating(rating),
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: isNew ? FontWeight.w600 : FontWeight.w700,
          ),
        ),
        if (count != null && count! > 0)
          Text(
            ' ($count)',
            style: TextStyle(
              color: context.mutedColor,
              fontSize: size - 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

/// Linha de loja no padrão `.srow`: logo quadrado de 70 px (cinza quando
/// fechada), nome com selo e linha de meta (avaliação, categoria, tempo,
/// entrega) — o bloco principal do feed do referencial.
class StoreRow extends StatelessWidget {
  const StoreRow({
    super.key,
    required this.establishment,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  final Establishment establishment;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final e = establishment;
    final open = e.isOpen;
    final logo = NetworkThumb(
      imageUrl: e.imageUrl,
      icon: categoryIconFor(e.categorySlug),
      size: 70,
      radius: 14,
      categorySlug: e.categorySlug,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo dessaturado quando a loja está fechada (`.closed`).
            SizedBox(
              width: 70,
              height: 70,
              child: open
                  ? logo
                  : ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0, //
                        0, 0, 0, 1, 0, //
                      ]),
                      child: logo,
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OpenBadge(isOpen: open),
                      if (onFavoriteToggle != null) ...[
                        const SizedBox(width: 2),
                        FavoriteIconButton(
                          isFavorite: isFavorite,
                          onPressed: onFavoriteToggle!,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RatingChip(rating: e.rating, count: e.reviewCount),
                      _metaText(context, e.categoryName),
                      _metaText(context, '${e.prepMinutes} min'),
                      _metaText(
                        context,
                        'Entrega ${formatMoneyCompact(e.deliveryFeeCents)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaText(BuildContext context, String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: context.mutedColor,
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w500,
    ),
  );
}

/// Cartão de produto no padrão `.pcard`: imagem quadrada, nome em duas
/// linhas, loja em cinza e rodapé com preço + avaliação.
class ProductCardJB extends StatelessWidget {
  const ProductCardJB({
    super.key,
    required this.product,
    required this.onTap,
    this.width,
  });

  final Product product;
  final VoidCallback onTap;

  /// Largura fixa em filas horizontais; `null` ocupa a célula da grelha.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: AppColors.darkCard,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CoverImage(
                imageUrl: product.imageUrl,
                logicalWidth: width ?? 160,
                fallback: BrandedCover(
                  categorySlug: product.category,
                  iconSize: 30,
                  decorations: false,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.establishmentName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatMoney(product.priceCents),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (!product.isAvailable)
                        Text(
                          'Esgotado',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (width == null) return card;
    return SizedBox(width: width, child: card);
  }
}

/// Cartão de loja no padrão `.pcard`, adaptado às secções horizontais
/// ("Melhor avaliados"): capa, nome, categoria e rodapé com avaliação +
/// taxa de entrega.
class StoreCardJB extends StatelessWidget {
  const StoreCardJB({
    super.key,
    required this.establishment,
    required this.onTap,
    this.width = 158,
  });

  final Establishment establishment;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final e = establishment;
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                width: double.infinity,
                child: e.isOpen
                    ? CoverImage(
                        imageUrl: e.imageUrl,
                        logicalWidth: width,
                        fallback: BrandedCover(
                          categorySlug: e.categorySlug,
                          iconSize: 26,
                          decorations: false,
                        ),
                      )
                    : ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.33, 0.33, 0.33, 0, 0, //
                          0.33, 0.33, 0.33, 0, 0, //
                          0.33, 0.33, 0.33, 0, 0, //
                          0, 0, 0, 1, 0, //
                        ]),
                        child: CoverImage(
                          imageUrl: e.imageUrl,
                          logicalWidth: width,
                          fallback: BrandedCover(
                            categorySlug: e.categorySlug,
                            iconSize: 26,
                            decorations: false,
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      e.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RatingChip(rating: e.rating, size: 12),
                        const Spacer(),
                        Text(
                          formatMoneyCompact(e.deliveryFeeCents),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Favorita no padrão `.favchip`: logótipo circular de 64 px com anel
/// vermelho e nome em duas linhas centrado.
class FavChip extends StatelessWidget {
  const FavChip({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onTap,
    this.categorySlug,
    this.icon = Icons.storefront_rounded,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onTap;
  final String? categorySlug;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2.5),
              ),
              child: CoverImage(
                imageUrl: imageUrl,
                logicalWidth: 64,
                fallback: BrandedCover(
                  categorySlug: categorySlug,
                  iconSize: 24,
                  decorations: false,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pílulas de categoria no padrão `.pills`: rolagem horizontal, pílula
/// activa a vermelho com texto branco.
class CategoryPills extends StatelessWidget {
  const CategoryPills({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  /// Itens na ordem de exibição; o primeiro costuma ser "Tudo".
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = items[index];
          final on = label == selected;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: on ? AppColors.primary : AppColors.darkCard,
              borderRadius: BorderRadius.circular(999),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(label),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 9.5,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: on ? Colors.white : context.mutedColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Chip de filtro com ícone no padrão `.chip.near` ("Lojas perto de
/// mim", "Entrega grátis"): fundo cinza, activo a vermelho.
class FilterIconChip extends StatelessWidget {
  const FilterIconChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.darkElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : context.mutedColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : context.inkColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho da página inicial no padrão `.hero`: marca com logótipo e
/// wordmark, sino/notificações à direita, saudação display gigante e
/// pesquisa em cápsula.
class JbHeroHeader extends StatelessWidget {
  const JbHeroHeader({
    super.key,
    required this.greeting,
    required this.search,
    this.trailing,
    this.brand = 'Nacala Delivery',
  });

  final String greeting;
  final Widget search;
  final Widget? trailing;
  final String brand;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogo(size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFontFamily,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: Colors.white,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 22),          Text(
            greeting,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.displayFontFamily,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          search,
        ],
      ),
    );
  }
}
