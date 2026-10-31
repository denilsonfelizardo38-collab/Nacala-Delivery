import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Número de iterações do PBKDF2-HMAC-SHA256.
const _iterations = 120000;

class PasswordDigest {
  const PasswordDigest(this.hash, this.salt);
  final String hash;
  final String salt;
}

String newSalt([int length = 16]) {
  final random = Random.secure();
  return base64UrlEncode(
    Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256))),
  );
}

PasswordDigest hashPassword(String password, {String? salt}) {
  final effectiveSalt = salt ?? newSalt();
  final derived = _pbkdf2(
    utf8.encode(password),
    utf8.encode(effectiveSalt),
    _iterations,
    32,
  );
  return PasswordDigest(base64Encode(derived), effectiveSalt);
}

bool verifyPassword(String password, String hash, String salt) {
  final derived = _pbkdf2(
    utf8.encode(password),
    utf8.encode(salt),
    _iterations,
    32,
  );
  final expected = base64Decode(hash);
  if (derived.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < derived.length; i++) {
    diff |= derived[i] ^ expected[i];
  }
  return diff == 0;
}

List<int> _pbkdf2(
  List<int> password,
  List<int> salt,
  int iterations,
  int keyLength,
) {
  final hmac = Hmac(sha256, password);
  final blockCount = (keyLength / 32).ceil();
  final output = <int>[];
  for (var block = 1; block <= blockCount; block++) {
    final blockIndex = <int>[
      (block >> 24) & 0xff,
      (block >> 16) & 0xff,
      (block >> 8) & 0xff,
      block & 0xff,
    ];
    var u = hmac.convert([...salt, ...blockIndex]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    output.addAll(result);
  }
  return output.sublist(0, keyLength);
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.tokenVersion,
  });

  final String id;
  final String role;
  final String name;
  final String email;
  final String phone;
  final int tokenVersion;

  bool get isAdmin => role == 'admin';
  bool get isPartner => role == 'partner';
  bool get isDelivery => role == 'delivery';
  bool get isCustomer => role == 'customer';
}

class JwtService {
  JwtService(this.secret, {this.ttl = const Duration(days: 7)});

  final String secret;
  final Duration ttl;

  String issue(AuthUser user) {
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'sub': user.id,
      'role': user.role,
      'ver': user.tokenVersion,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(ttl).millisecondsSinceEpoch ~/ 1000,
    };
    return JWT(payload).sign(SecretKey(secret), algorithm: JWTAlgorithm.HS256);
  }

  /// Devolve as claims ou lança [JWTException].
  Map<String, dynamic> verify(String token) {
    final jwt = JWT.verify(token, SecretKey(secret));
    final payload = jwt.payload;
    if (payload is! Map) throw JWTInvalidException('payload inválido');
    return payload.cast<String, dynamic>();
  }
}
