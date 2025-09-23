import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart' show load, env;

void main() async {
  load(); // Carga variables de entorno desde .env

  final conn = PostgreSQLConnection(
    env['DB_HOST']!,
    int.parse(env['DB_PORT']!),
    env['DB_NAME']!,
    username: env['DB_USER']!,
    password: env['DB_PASS']!,
  );

  await conn.open();
  print('Conectado a PostgreSQL');

  final router = Router();

  // Endpoint /login
  router.post('/login', (Request request) async {
    final body = jsonDecode(await request.readAsString());
    final email = body['email'];
    final password = body['password'];

    final result = await conn.query(
      'SELECT validate_user(@email, @password) AS valid',
      substitutionValues: {
        'email': email,
        'password': password,
      },
    );

    final isValid = result.first[0] as bool;

    return Response.ok(
      jsonEncode({'success': isValid}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  final handler =
      const Pipeline().addMiddleware(corsHeaders()).addHandler(router);

  final server = await io.serve(handler, 'localhost', 8080);
  print('Servidor corriendo en http://${server.address.host}:${server.port}');
}
