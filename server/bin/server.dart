import 'dart:io';

import 'package:nacala_server/src/api.dart';
import 'package:nacala_server/src/auth.dart';
import 'package:nacala_server/src/db.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dbPath = Platform.environment['DB_PATH'] ?? 'data';
  final secret = Platform.environment['JWT_SECRET'] ??
      'dev-only-secret-change-me-before-deploying';
  final allowDevSecret = Platform.environment['ALLOW_DEV_JWT_SECRET'] == '1';
  final seed = Platform.environment['SEED'] != '0';
  final demoSeed = Platform.environment['SEED_DEMO'] == '1';
  final allowedOrigin = Platform.environment['CORS_ORIGIN'] ?? '*';

  if (secret == 'dev-only-secret-change-me-before-deploying') {
    if (allowDevSecret) {
      stderr.writeln(
        'AVISO: JWT_SECRET não definido; ALLOW_DEV_JWT_SECRET=1 aceita o '
        'segredo de desenvolvimento. Não use em produção.',
      );
    } else {
      stderr.writeln(
        'ERRO: JWT_SECRET não definido. Defina o segredo (32+ caracteres '
        'aleatórios) ou, apenas em ambiente local, ALLOW_DEV_JWT_SECRET=1. '
        'O servidor não arrancará com o segredo de desenvolvimento.',
      );
      exit(2);
    }
  }

  final db = openDatabase(dbPath, seed: seed, demoSeed: demoSeed);
  final imageDirectory =
      Directory(Platform.environment['UPLOADS_DIR'] ?? 'data/uploads');
  final api = Api(
    db: db,
    jwt: JwtService(secret),
    imageDirectory: imageDirectory,
    allowedOrigin: allowedOrigin,
  );

  final server = await shelf_io.serve(
    api.handler,
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln('Nacala API em http://${server.address.host}:${server.port}');
  stdout.writeln('Base de dados: $dbPath');
  stdout.writeln('Imagens de produtos: ${imageDirectory.path}');
  if (allowedOrigin != '*') stdout.writeln('CORS restrito a: $allowedOrigin');

  Future<void> shutdown() async {
    await server.close(force: true);
    db.dispose();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  // O Docker `stop`, Render e systemd enviam SIGTERM para parar o processo;
  // sem tratamento, o encerramento é abrupto e perde o checkpoint do WAL.
  ProcessSignal.sigterm.watch().listen((_) => shutdown());
}
