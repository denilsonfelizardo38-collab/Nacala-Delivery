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
  final seed = Platform.environment['SEED'] != '0';
  final demoSeed = Platform.environment['SEED_DEMO'] == '1';

  if (secret.startsWith('dev-only')) {
    stderr.writeln(
      'AVISO: JWT_SECRET não definido. A usar segredo de desenvolvimento.',
    );
  }

  final db = openDatabase(dbPath, seed: seed, demoSeed: demoSeed);
  final imageDirectory =
      Directory(Platform.environment['UPLOADS_DIR'] ?? 'data/uploads');
  final api = Api(
    db: db,
    jwt: JwtService(secret),
    imageDirectory: imageDirectory,
  );

  final server = await shelf_io.serve(
    api.handler,
    InternetAddress.anyIPv4,
    port,
  );
  stdout.writeln('Nacala API em http://${server.address.host}:${server.port}');
  stdout.writeln('Base de dados: $dbPath');
  stdout.writeln('Imagens de produtos: ${imageDirectory.path}');

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    db.dispose();
    exit(0);
  });
}
