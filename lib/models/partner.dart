import 'package:flutter/material.dart';

/// Parceiro registado, usado no painel de administração.
class Partner {
  const Partner({
    required this.initials,
    required this.name,
    required this.type,
    required this.tint,
    this.pending = false,
  });

  final String initials;
  final String name;
  final String type;
  final Color tint;
  final bool pending;

  String get status => pending ? 'Em análise' : 'Ativo';
}
