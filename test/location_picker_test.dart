import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nacala_derivery/widgets/location_picker.dart';

/// FASE 11 — pesquisa de localização no mapa.
///
/// O seletor passa a ter campo de texto ("Pesquisar rua, bairro ou local")
/// além do toque no mapa e do botão de localização atual. Sem texto o
/// pedido falha honestamente (mensagem do sistema) em vez de silenciar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showLocationPicker(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('seletor apresenta o campo de pesquisa de localização', (
    tester,
  ) async {
    await openPicker(tester);

    expect(find.text('Pesquisar rua, bairro ou local…'), findsOneWidget);
    expect(find.byTooltip('Pesquisar'), findsOneWidget);
    expect(find.text('Confirmar ponto'), findsOneWidget);
    // Sem ponto escolhido não se confirma (evita guardar o mapa vazio).
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar ponto'),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('pesquisar sem texto mostra mensagem honesta', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byTooltip('Pesquisar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Escreva o que pretende procurar.'), findsOneWidget);
    // O mapa continua utilizável depois do erro.
    expect(find.text('Confirmar ponto'), findsOneWidget);
  });
}
