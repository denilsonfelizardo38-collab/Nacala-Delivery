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
    required String email,
    required String phone,
    required String password,
  }) async {
    final result = registerResult;
    if (result == null) {
      throw const ApiException('Sem registo de teste.', status: 400);
    }
    return result;
  }

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
  Future<List<Category>> categories() async => const [];

  @override
  Future<List<Establishment>> establishments({
    String? category,
    String? query,
    String? sort,
    bool openOnly = false,
  }) async => const [];

  @override
  Future<List<Order>> orders({String? status}) async => const [];

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

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakeApi: ${invocation.memberName} não foi configurado.',
  );
}
