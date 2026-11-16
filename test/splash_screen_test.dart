// TESTE 15 — Splash Screen: a mota de entrega atravessa o ecrã da
// direita para a esquerda, desaparece pelo lado esquerdo e a versão
// estática aparece quando o utilizador tem animações desligadas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nacala_derivery/screens/splash_screen.dart';

void main() {
  Widget wrap({required bool disableAnimations}) {
    return MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: const SplashScreen(),
    );
  }

  /// `left` da Positioned da mota (as dos riscos não têm largura).
  double? motoLeft(WidgetTester tester) {
    for (final p in tester.widgetList<Positioned>(find.byType(Positioned))) {
      if (p.width != null) return p.left;
    }
    return null;
  }

  testWidgets('a mota atravessa o ecrã da direita para a esquerda',
      (tester) async {
    await tester.pumpWidget(wrap(disableAnimations: false));

    final lefts = <double>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250)); // até 2000 ms
      final left = motoLeft(tester);
      if (left != null) lefts.add(left);
    }

    // Tem de ter registado a passagem completa.
    expect(lefts, hasLength(greaterThanOrEqualTo(6)));

    // Começa fora do ecrã, pelo lado DIREITO…
    expect(lefts.first, greaterThan(800));

    // …termina fora do ecrã, pelo lado ESQUERDO (totalmente saída).
    expect(lefts.last, lessThanOrEqualTo(-156));

    // O movimento é contínuo e sempre na direção direita → esquerda.
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], lessThanOrEqualTo(lefts[i - 1]),
          reason: 'a mota deve avançar sempre para a esquerda');
    }

    // Em algum momento está visivelmente no meio do ecrã.
    expect(
      lefts.any((l) => l > 0 && l < 600),
      isTrue,
      reason: 'a mota deve aparecer no ecrã durante a passagem',
    );
  });

  testWidgets('a marca entra e o wordmark fica visível no arranque',
      (tester) async {
    await tester.pumpWidget(wrap(disableAnimations: false));
    await tester.pump(const Duration(milliseconds: 900));

    final logo = find.ancestor(
      of: find.byIcon(Icons.delivery_dining_rounded),
      matching: find.byType(Opacity),
    );
    expect(logo, findsWidgets);
    final opacity = tester.widgetList<Opacity>(logo).first.opacity;
    expect(opacity, greaterThan(0.5), reason: 'logótipo visível');

    expect(find.text('Nacala'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
  });

  testWidgets('versão estática quando o utilizador desligou animações',
      (tester) async {
    await tester.pumpWidget(wrap(disableAnimations: true));

    // Sem passagem da mota: só a identidade estática.
    expect(motoLeft(tester), isNull);
    expect(find.text('Nacala Delivery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
