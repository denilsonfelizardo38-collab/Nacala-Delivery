import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../data/api_service.dart';
import '../../models/models.dart';
import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/jb.dart';

class PartnerProductsScreen extends StatefulWidget {
  const PartnerProductsScreen({super.key});

  @override
  State<PartnerProductsScreen> createState() => _PartnerProductsScreenState();
}

class _PartnerProductsScreenState extends State<PartnerProductsScreen> {
  bool _initialized = false;
  Future<List<Product>>? _future;
  final _search = TextEditingController();
  String _query = '';
  String? _busyId;
  bool _savingProduct = false;

  /// Categoria do estabelecimento (ex.: `restaurantes`) — usada para
  /// sugerir as categorias de menu adequadas no formulário de produto.
  String? _categorySlug;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final api = AppScope.of(context).api;
    _future = api.partnerProducts();
    _loadCategory(api);
  }

  Future<void> _loadCategory(NacalaApi api) async {
    try {
      final establishment = await api.partnerEstablishment();
      if (mounted) setState(() => _categorySlug = establishment.categorySlug);
    } on ApiException {
      // Sem categoria conhecida o formulário mantém o campo livre.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).api.partnerProducts();
    });
  }

  Future<void> _openEditor([Product? product]) async {
    final api = AppScope.of(context).api;
    final input = await showDialog<_ProductInput>(
      context: context,
      builder: (_) => _ProductDialog(
        product: product,
        categorySlug: _categorySlug,
      ),
    );
    if (input == null || !mounted) return;
    setState(() => _savingProduct = true);
    try {
      final imageUrl = input.imageFile == null
          ? input.imageUrl
          : await api.uploadProductImage(input.imageFile!);
      await api.saveProduct(
        id: product?.id,
        name: input.name,
        description: input.description,
        priceCents: input.priceCents,
        category: input.category,
        isAvailable: input.isAvailable,
        stock: input.stock,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      showAppSnack(
        context,
        product == null ? 'Produto criado.' : 'Produto atualizado.',
      );
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _savingProduct = false);
    }
  }

  Future<void> _toggleAvailability(Product product) async {
    setState(() => _busyId = product.id);
    try {
      await AppScope.of(context).api.saveProduct(
        id: product.id,
        name: product.name,
        description: product.description,
        priceCents: product.priceCents,
        category: product.category,
        isAvailable: !product.isAvailable,
        stock: product.stock,
        imageUrl: product.imageUrl,
      );
      if (!mounted) return;
      showAppSnack(
        context,
        product.isAvailable
            ? 'Produto marcado como indisponível.'
            : 'Produto disponível para venda.',
      );
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(Product product) async {
    final api = AppScope.of(context).api;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar produto',
      message:
          'O produto "${product.name}" deixa de aparecer no menu. Se já '
          'foi usado em encomendas, fica apenas desativado para preservar '
          'o histórico.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busyId = product.id);
    try {
      // O servidor decide: apaga se nunca foi encomendado, caso contrário
      // apenas desativa (`deactivated: true`) — o aviso reflete o resultado.
      final deactivated = await api.deleteProduct(product.id);
      if (!mounted) return;
      showAppSnack(
        context,
        deactivated
            ? 'Produto desativado (já tinha encomendas).'
            : 'Produto eliminado.',
      );
      _reload();
    } on ApiException catch (error) {
      if (mounted) showAppSnack(context, error.message, error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            JbPageHeader(
              title: 'Produtos',
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).maybePop()
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Novo produto',
                    onPressed: _savingProduct ? null : () => _openEditor(),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    if (_savingProduct) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    SearchField(
                      controller: _search,
                      hintText: 'Pesquisar nos seus produtos',
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                    const SizedBox(height: 14),
                    AsyncSection<List<Product>>(
                      future: _future,
                      onRetry: _reload,
                      builder: (context, products) {
                        final filtered = _query.isEmpty
                            ? products
                            : products
                                  .where(
                                    (product) =>
                                        product.name.toLowerCase().contains(
                                          _query.toLowerCase(),
                                        ) ||
                                        product.category.toLowerCase().contains(
                                          _query.toLowerCase(),
                                        ),
                                  )
                                  .toList();
                        if (products.isEmpty) {
                          return EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Ainda sem produtos',
                            message:
                                'Crie o primeiro produto para começar a receber '
                                'pedidos.',
                            actionLabel: 'Criar produto',
                            onAction: () => _openEditor(),
                          );
                        }
                        if (filtered.isEmpty) {
                          return const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Sem resultados',
                            message: 'Nenhum produto corresponde à pesquisa.',
                            compact: true,
                          );
                        }
                        return Column(
                          children: [
                            for (final product in filtered)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ProductTile(
                                  product: product,
                                  busy: _busyId == product.id,
                                  onEdit: () => _openEditor(product),
                                  onToggle: () => _toggleAvailability(product),
                                  onDelete: () => _remove(product),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _savingProduct ? null : () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo produto'),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.busy,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final Product product;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NetworkThumb(
            imageUrl: product.imageUrl,
            icon: Icons.restaurant_rounded,
            size: 64,
            radius: 12,
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
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    StatusBadge(
                      status: product.isAvailable ? 'accepted' : 'cancelled',
                      label: product.isAvailable
                          ? 'Disponível'
                          : 'Indisponível',
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.category} · ${formatMoney(product.priceCents)}'
                  '${product.stock == null ? '' : ' · ${product.stock} em stock'}',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
                if (product.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    product.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.mutedColor, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 6),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Editar'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onToggle,
                        icon: Icon(
                          product.isAvailable
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 15,
                        ),
                        label: Text(
                          product.isAvailable ? 'Ocultar' : 'Mostrar',
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                        ),
                        label: const Text('Eliminar'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: context.dangerColor,
                        ),
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

class _ProductInput {
  const _ProductInput({
    required this.name,
    required this.description,
    required this.priceCents,
    required this.category,
    required this.isAvailable,
    required this.stock,
    required this.imageUrl,
    required this.imageFile,
  });

  final String name;
  final String description;
  final int priceCents;
  final String category;
  final bool isAvailable;
  final int? stock;
  final String? imageUrl;
  final XFile? imageFile;
}

/// Sugestões de "categoria do menu" por tipo de estabelecimento — o
/// formulário adaptativo mostra estas opções em vez de exigir texto livre.
const _menuCategorySuggestions = <String, List<String>>{
  'restaurantes': ['Pratos', 'Entradas', 'Bebidas', 'Sobremesas'],
  'mercados': ['Mercearia', 'Frescos', 'Bebidas', 'Higiene'],
  'farmacias': ['Medicamentos', 'Vitaminas', 'Higiene', 'Dermocosmética'],
  'lojas': ['Mercearia', 'Bebidas', 'Higiene', 'Diversos'],
  'padarias': ['Pão', 'Pastelaria', 'Bolos', 'Bebidas'],
  'bebidas': ['Refrigerantes', 'Sucos', 'Águas', 'Cervejas'],
  'talhos': ['Frescos', 'Congelados', 'Processados'],
  'peixarias': ['Frescos', 'Congelados', 'Processados'],
};

/// Valor sentinela do dropdown para escrever uma categoria própria.
const _otherCategory = '__outra__';

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({this.product, this.categorySlug});
  final Product? product;

  /// Categoria do estabelecimento (chave de [_menuCategorySuggestions]).
  final String? categorySlug;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late final TextEditingController _customCategory;
  late final TextEditingController _stock;
  final ImagePicker _imagePicker = ImagePicker();
  late String? _imageUrl;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  late bool _available;

  /// Categorias sugeridas para este estabelecimento (vazio → campo livre).
  late final List<String> _suggestions;

  /// Seleção actual do dropdown (`_otherCategory` → campo próprio).
  late String? _categoryChoice;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(
      text: product == null ? '' : formatMoneyPlain(product.priceCents),
    );
    _category = TextEditingController(text: product?.category ?? 'Geral');
    _customCategory = TextEditingController(text: product?.category ?? '');
    _stock = TextEditingController(text: product?.stock?.toString() ?? '');
    _imageUrl = product?.imageUrl;
    _available = product?.isAvailable ?? true;

    _suggestions =
        _menuCategorySuggestions[widget.categorySlug] ?? const <String>[];
    final current = product?.category ?? '';
    if (_suggestions.isEmpty) {
      _categoryChoice = null;
    } else if (current.isEmpty) {
      // Produto novo: começa já numa categoria típica do tipo de loja.
      _categoryChoice = _suggestions.first;
    } else {
      // Mantém a categoria actual (mesmo que seja própria/legada).
      _categoryChoice = current;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _category.dispose();
    _customCategory.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageFile = image;
        _imageBytes = bytes;
        _imageUrl = null;
      });
    } on PlatformException catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          error.message ?? 'Não foi possível abrir a galeria.',
          error: true,
        );
      }
    } on FileSystemException {
      if (mounted) {
        showAppSnack(
          context,
          'Não foi possível ler a imagem selecionada.',
          error: true,
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _imageUrl = null;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cents = parseMoneyToCents(_price.text);
    if (cents == null || cents <= 0) {
      showAppSnack(context, 'Indique um preço válido.', error: true);
      return;
    }
    // Resolução da categoria: modo sugestão (dropdown) vs. categoria
    // própria ("Outra categoria…") vs. campo livre (sem sugestões).
    String category;
    if (_suggestions.isEmpty) {
      category = _category.text.trim().isEmpty
          ? 'Geral'
          : _category.text.trim();
    } else if (_categoryChoice == _otherCategory) {
      category = _customCategory.text.trim();
    } else {
      category = _categoryChoice ?? _suggestions.first;
    }
    final stockText = _stock.text.trim();
    Navigator.of(context).pop(
      _ProductInput(
        name: _name.text.trim(),
        description: _description.text.trim(),
        priceCents: cents,
        category: category,
        isAvailable: _available,
        stock: stockText.isEmpty ? null : int.tryParse(stockText),
        imageUrl: _imageUrl,
        imageFile: _imageFile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Novo produto' : 'Editar produto'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) =>
                      (value == null || value.trim().length < 2)
                      ? 'Indique o nome do produto.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ingredientes, tamanho...',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _imageFile != null || _imageUrl != null
                              ? 'Alterar imagem'
                              : 'Escolher da galeria',
                        ),
                      ),
                      if (_imageFile != null || _imageUrl != null)
                        IconButton(
                          tooltip: 'Remover imagem',
                          onPressed: _removeImage,
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _imageBytes == null
                            ? NetworkThumb(
                                imageUrl: _imageUrl,
                                icon: Icons.restaurant_rounded,
                                size: 96,
                                radius: 14,
                              )
                            : Image.memory(
                                _imageBytes!,
                                width: 96,
                                height: 96,
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pré-visualização da imagem',
                        style: TextStyle(
                          color: context.mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Preço',
                          hintText: '0,00',
                          suffixText: 'MZN',
                        ),
                        validator: (value) {
                          final cents = parseMoneyToCents(value ?? '');
                          return cents == null || cents <= 0
                              ? 'Preço inválido.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          hintText: 'Opcional',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          final parsed = int.tryParse(text);
                          return parsed == null || parsed < 0
                              ? 'Número inválido.'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_suggestions.isEmpty)
                  TextFormField(
                    controller: _category,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Categoria do menu',
                      hintText: 'Ex.: Pratos, Bebidas',
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    // O valor é escolhido pelo utilizador (nunca muda por
                    // fora) — `initialValue` define apenas o ponto de partida.
                    initialValue: _categoryChoice,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoria do menu',
                    ),
                    items: [
                      for (final value in _suggestions)
                        DropdownMenuItem(
                          value: value,
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Categoria actual que não está nas sugestões
                      // (própria/legada) continua seleccionável.
                      if (_categoryChoice != null &&
                          _categoryChoice != _otherCategory &&
                          !_suggestions.contains(_categoryChoice))
                        DropdownMenuItem(
                          value: _categoryChoice,
                          child: Text(
                            _categoryChoice!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const DropdownMenuItem(
                        value: _otherCategory,
                        child: Text('Outra categoria…'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _categoryChoice = value;
                        if (value == _otherCategory &&
                            widget.product != null &&
                            _customCategory.text.trim().isEmpty) {
                          _customCategory.text = widget.product!.category;
                        }
                      });
                    },
                  ),
                  if (_categoryChoice == _otherCategory) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _customCategory,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nova categoria',
                        hintText: 'Ex.: Pratos do dia',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().length < 2)
                          ? 'Indique a categoria do menu.'
                          : null,
                    ),
                  ],
                ],
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Disponível para venda',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _available,
                  onChanged: (value) => setState(() => _available = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
