import 'package:image_picker/image_picker.dart';
import 'package:nacala_derivery/core/api_client.dart';
import 'package:nacala_derivery/data/api_service.dart';
import 'package:nacala_derivery/models/models.dart';

/// API falsa usada apenas nos testes de widget e de estado.
///
/// Os métodos não configurados falham explicitamente, para que nenhum teste
/// dependa de respostas inventadas sem intenção.
class FakeApi implements NacalaApi {
  FakeApi({this.user, this.addressList = const []});

  final UserAccount? user;
  final List<Address> addressList;

  AuthResult? loginResult;
  AuthResult? registerResult;
  AdminSummary? adminSummaryResult;
  Order? orderResult;
  EstablishmentDetail? establishmentDetail;
  Object? loginError;
  Object? meError;
  Object? favoritesError;
  List<Establishment> favoritesResult = const [];
  List<Order> ordersResult = const [];

  @override
  final ApiClient client = ApiClient();

  @override
  Future<AuthResult> login(String identifier, String password) async {
    final error = loginError;
    if (error != null) throw error;
    final result = loginResult;
    if (result == null) {
      throw const ApiException('Sem sessão de teste.', status: 401);
    }
    return result;
  }

  @override
  Future<AuthResult> register({
    required String name,
    String? email,
    required String phone,
    String? whatsapp,
    required String password,
  }) async {
    final result = registerResult;
    if (result == null) {
      throw const ApiException('Sem registo de teste.', status: 400);
    }
    return result;
  }

  /// Resultado de [recoverPassword] (o campo `recoveryCode` do [AuthResult]
  /// representa o código rotacionado devolvido pelo servidor).
  AuthResult? recoverResult;

  /// Código devolvido por [regenerateRecoveryCode].
  String recoveryCodeResult = '';

  @override
  Future<AuthResult> recoverPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {
    final result = recoverResult;
    if (result == null) {
      throw const ApiException('Sem recuperação de teste.', status: 422);
    }
    return result;
  }

  @override
  Future<String> regenerateRecoveryCode() async => recoveryCodeResult;

  @override
  Future<MeData> me() async {
    final error = meError;
    if (error != null) throw error;
    final current = user;
    if (current == null) {
      throw const ApiException('Sessão expirada.', status: 401);
    }
    return MeData(user: current, addresses: addressList);
  }

  @override
  Future<List<Address>> addresses() async => addressList;

  @override
  Future<void> logout() async {}

  @override
  Future<List<Category>> categories() async => categoriesResult;

  // ----------------------------------------------------------- candidaturas

  /// Categorias devolvidas por [categories] (formulário de estabelecimento).
  List<Category> categoriesResult = const [];

  /// Resultado de [submitApplication].
  Application? applicationResult;

  /// Grava os últimos argumentos de [submitApplication] para asserções.
  Map<String, dynamic>? lastApplicationSubmission;

  /// Resultado de [myApplication]; `status: 404` simula conta sem
  /// candidatura.
  Application? myApplicationResult;
  ApiException? myApplicationError;

  @override
  Future<Application> submitApplication({
    required String kind,
    required String name,
    required String phone,
    required String password,
    String? email,
    String? whatsapp,
    Map<String, dynamic> payload = const {},
  }) async {
    lastApplicationSubmission = {
      'kind': kind,
      'name': name,
      'phone': phone,
      'password': password,
      'email': email,
      'whatsapp': whatsapp,
      'payload': payload,
    };
    final result = applicationResult;
    if (result == null) {
      throw const ApiException('Sem candidatura de teste.', status: 422);
    }
    return result;
  }

  // ------------------------------------------------- gestão de registos

  /// Resultado de [adminApplications] (lista + contagens por estado).
  ({List<Application> applications, Map<String, int> counts})?
  adminApplicationsResult;

  /// Resultado das decisões (aprovar/recusar/pedir correções).
  Application? applicationReviewResult;

  /// Última decisão tomada, para asserções: `approve:<id>:<nota>`.
  String? lastApplicationReview;

  /// Últimos filtros usados em [adminApplications]: `status|kind`.
  String? lastAdminApplicationsFilter;

  @override
  Future<({List<Application> applications, Map<String, int> counts})>
  adminApplications({String? status, String? kind}) async {
    lastAdminApplicationsFilter = '${status ?? ''}|${kind ?? ''}';
    final result = adminApplicationsResult;
    if (result == null) {
      throw const ApiException('Sem registos de teste.', status: 500);
    }
    return result;
  }

  Future<Application> _review(String action, String id, String? note) async {
    lastApplicationReview = '$action:$id:${note ?? ''}';
    final result = applicationReviewResult;
    if (result == null) {
      throw const ApiException('Sem decisão de teste.', status: 500);
    }
    return result;
  }

  @override
  Future<Application> adminApproveApplication(String id, {String? note}) =>
      _review('approve', id, note);

  @override
  Future<Application> adminRejectApplication(String id, {String? note}) =>
      _review('reject', id, note);

  @override
  Future<Application> adminRequestApplicationChanges(
    String id, {
    required String note,
  }) => _review('changes', id, note);

  @override
  Future<Application> myApplication() async {
    final error = myApplicationError;
    if (error != null) throw error;
    final result = myApplicationResult;
    if (result == null) {
      throw const ApiException('Sem candidatura de teste.', status: 404);
    }
    return result;
  }

  @override
  Future<List<Establishment>> establishments({
    String? category,
    String? query,
    String? sort,
    bool openOnly = false,
  }) async => const [];

  @override
  Future<List<Order>> orders({String? status}) async => ordersResult;

  /// Resultado de [notifications] (notificações persistentes FASE 12).
  List<AppNotification> notificationsResult = const [];

  /// Ids marcados como lidas pelo ecrã de notificações (para os testes
  /// verificarem que a marcação acontece de facto).
  List<List<String>?> markNotificationsReadCalls = const [];

  @override
  Future<List<AppNotification>> notifications({int limit = 50}) async =>
      notificationsResult;

  @override
  Future<void> markNotificationsRead({List<String>? ids}) async {
    markNotificationsReadCalls = [...markNotificationsReadCalls, ids];
    notificationsResult = [
      for (final item in notificationsResult)
        item.isRead || (ids != null && !ids.contains(item.id))
            ? item
            : AppNotification(
                id: item.id,
                kind: item.kind,
                title: item.title,
                body: item.body,
                data: item.data,
                isRead: true,
                createdAt: item.createdAt,
              ),
    ];
  }

  /// Resultado de [adminOrders] (painel admin/funcionário de encomendas).
  List<Order> adminOrdersResult = const [];

  @override
  Future<List<Order>> adminOrders({String? status}) async => adminOrdersResult;

  @override
  Future<List<Product>> products({
    String? query,
    String? establishment,
    String? category,
  }) async => const [];

  @override
  Future<SearchResult> search(String query) async => const SearchResult(
    establishments: [],
    products: [],
    categories: [],
  );

  @override
  Future<List<Establishment>> favorites() async {
    final error = favoritesError;
    if (error != null) throw error;
    return [...favoritesResult];
  }

  @override
  Future<void> addFavorite(String establishmentId) async {
    if (!favoritesResult.any((item) => item.id == establishmentId)) {
      final found = const Establishment(
        id: 'favorite-new',
        name: 'Favorito',
        slug: 'favorito',
        description: '',
        address: 'Nacala-Porto',
        phone: '840000000',
        deliveryFeeCents: 0,
        prepMinutes: 30,
        opensAt: '08:00',
        closesAt: '22:00',
        isOpen: true,
        rating: 0,
        reviewCount: 0,
        productCount: 0,
        categoryId: 'cat',
        categoryName: 'Testes',
        categorySlug: 'lojas',
      );
      favoritesResult = [...favoritesResult, found];
    }
  }

  @override
  Future<void> removeFavorite(String establishmentId) async {
    favoritesResult = favoritesResult
        .where((item) => item.id != establishmentId)
        .toList();
  }

  @override
  Future<AdminSummary> adminSummary() async {
    final summary = adminSummaryResult;
    if (summary == null) {
      throw const ApiException('Sem resumo de teste.', status: 500);
    }
    return summary;
  }

  @override
  Future<Order> order(String id) async {
    final order = orderResult;
    if (order == null) {
      throw const ApiException('Sem pedido de teste.', status: 404);
    }
    return order;
  }

  @override
  Future<EstablishmentDetail> establishment(String id) async {
    final detail = establishmentDetail;
    if (detail == null) {
      throw const ApiException('Sem estabelecimento de teste.', status: 404);
    }
    return detail;
  }

  // ------------------------------------------------------ painel de produtos

  /// Estabelecimento devolvido por [partnerEstablishment] (define a
  /// categoria usada nas sugestões do formulário de produto).
  Establishment? partnerEstablishmentResult;

  /// Produtos devolvidos por [partnerProducts].
  List<Product> partnerProductsResult = const [];

  /// Dados do painel parceiro (`/api/partner/summary`).
  PartnerDashboardData? partnerDashboardResult;

  /// Último produto gravado e se foi criação (`lastSavedProductId == null`).
  Product? lastSavedProduct;
  String? lastSavedProductId;

  /// Resultado de [deleteProduct]: `true` → apenas desativado.
  bool deleteProductResult = false;
  String? lastDeletedProductId;

  @override
  Future<PartnerDashboardData> partnerDashboard() async {
    final result = partnerDashboardResult;
    if (result == null) {
      throw const ApiException('Sem painel de teste.', status: 500);
    }
    return result;
  }

  @override
  Future<List<Product>> partnerProducts() async => [...partnerProductsResult];

  @override
  Future<Establishment> partnerEstablishment() async {
    final result = partnerEstablishmentResult;
    if (result == null) {
      throw const ApiException('Sem estabelecimento de teste.', status: 404);
    }
    return result;
  }

  @override
  Future<Product> saveProduct({
    String? id,
    required String name,
    required String description,
    required int priceCents,
    required String category,
    required bool isAvailable,
    int? stock,
    String? imageUrl,
  }) async {
    final product = Product(
      id: id ?? 'prd_novo',
      establishmentId: partnerEstablishmentResult?.id ?? 'est_teste',
      name: name,
      description: description,
      priceCents: priceCents,
      category: category,
      isAvailable: isAvailable,
      stock: stock,
      imageUrl: imageUrl,
    );
    lastSavedProduct = product;
    lastSavedProductId = id;
    partnerProductsResult = id == null
        ? [...partnerProductsResult, product]
        : [
            for (final existing in partnerProductsResult)
              existing.id == id ? product : existing,
          ];
    return product;
  }

  @override
  Future<bool> deleteProduct(String id) async {
    lastDeletedProductId = id;
    partnerProductsResult = partnerProductsResult
        .where((product) => product.id != id)
        .toList();
    return deleteProductResult;
  }

  @override
  Future<String> uploadProductImage(XFile file) async =>
      'https://teste.nacala.delivery/uploads/produto.png';

  // ------------------------------------------------------- FASE 13: uploads

  /// Parceiros devolvidos por [adminPartners] (painel da administração).
  List<Establishment> adminPartnersResult = const [];

  @override
  Future<List<Establishment>> adminPartners() async => adminPartnersResult;

  /// Gera caminhos `/uploads/…` realistas (32 hex + extensão).
  int _uploadCount = 0;

  String _nextUpload() {
    _uploadCount++;
    return '/uploads/${_uploadCount.toRadixString(16).padLeft(32, '0')}.png';
  }

  /// Imagens de candidatura carregadas (selfie/B.I/condução do entregador).
  int applicationImageUploads = 0;

  @override
  Future<String> uploadApplicationImage(XFile file) async {
    applicationImageUploads++;
    return 'https://teste.nacala.delivery${_nextUpload()}';
  }

  @override
  Future<String> adminUploadPartnerImage(XFile file) async =>
      'https://teste.nacala.delivery${_nextUpload()}';

  /// Últimos argumentos de [adminCreatePartner] para asserções.
  Map<String, dynamic>? lastAdminPartner;

  @override
  Future<Establishment> adminCreatePartner({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String nuit,
    required String establishmentName,
    required String categoryId,
    String? description,
    String? address,
    String? establishmentPhone,
    required int deliveryFeeCents,
    required int prepMinutes,
    required String opensAt,
    required String closesAt,
    String? imageUrl,
  }) async {
    lastAdminPartner = {
      'name': name,
      'email': email,
      'phone': phone,
      'nuit': nuit,
      'establishment_name': establishmentName,
      'category_id': categoryId,
      'image_url': imageUrl,
    };
    return Establishment(
      id: 'est_novo',
      name: establishmentName,
      slug: establishmentName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      description: description ?? '',
      address: address ?? '',
      phone: establishmentPhone ?? phone,
      deliveryFeeCents: deliveryFeeCents,
      prepMinutes: prepMinutes,
      opensAt: opensAt,
      closesAt: closesAt,
      isOpen: true,
      rating: 0,
      reviewCount: 0,
      productCount: 0,
      categoryId: categoryId,
      categoryName: '',
      categorySlug: '',
      imageUrl: imageUrl,
      nuit: nuit,
    );
  }

  // ------------------------------------------------- funcionários (FASE 10)

  /// Resultado de [adminEmployees]. Criação/edição/eliminação operam sobre
  /// esta lista, para os testes verem o efeito no ecrã.
  List<AdminEmployee> adminEmployeesResult = const [];

  /// Erro a devolver nas operações de funcionário (opcional).
  Object? employeesError;

  Future<T> _employeesOp<T>(T Function() body) async {
    final error = employeesError;
    if (error != null) throw error;
    return body();
  }

  @override
  Future<List<AdminEmployee>> adminEmployees() =>
      _employeesOp(() => adminEmployeesResult);

  @override
  Future<AdminEmployee> adminCreateEmployee({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String level,
    List<String> permissions = const [],
  }) => _employeesOp(() {
    final employee = AdminEmployee(
      id: 'emp_teste_${adminEmployeesResult.length + 1}',
      userId: 'usr_teste_${adminEmployeesResult.length + 1}',
      name: name,
      email: email,
      phone: phone,
      level: level,
      permissions: permissions,
    );
    adminEmployeesResult = [...adminEmployeesResult, employee];
    return employee;
  });

  @override
  Future<AdminEmployee> adminUpdateEmployee(
    String id, {
    String? level,
    List<String>? permissions,
    bool? isActive,
  }) => _employeesOp(() {
    final index = adminEmployeesResult.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const ApiException('Funcionário não encontrado.', status: 404);
    }
    final current = adminEmployeesResult[index];
    final updated = AdminEmployee(
      id: current.id,
      userId: current.userId,
      name: current.name,
      email: current.email,
      phone: current.phone,
      level: level ?? current.level,
      permissions: permissions ?? current.permissions,
      isActive: isActive ?? current.isActive,
      establishmentId: current.establishmentId,
      createdAt: current.createdAt,
    );
    adminEmployeesResult = [
      for (final item in adminEmployeesResult)
        if (item.id == id) updated else item,
    ];
    return updated;
  });

  @override
  Future<void> adminDeleteEmployee(String id) => _employeesOp(() {
    adminEmployeesResult = [
      for (final item in adminEmployeesResult)
        if (item.id != id) item,
    ];
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeApi: ${invocation.memberName} não foi configurado.',
  );
}
