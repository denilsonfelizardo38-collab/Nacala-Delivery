import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Seletor de imagens simulado para os testes de widget.
///
/// Devolve uma fotografia **em memória** em vez de abrir a galeria. Os
/// testes de widget correm num relógio falso onde o I/O real de `dart:io`
/// nunca completa (`File.readAsBytes()` pendurava o teste), por isso o
/// aplicativo recebe um `XFile` que lê de memória — o mesmo caminho de
/// código do dispositivo real (`readAsBytes()`).
class FakeImagePickerPlatform extends ImagePickerPlatform {
  FakeImagePickerPlatform(this.bytes);

  /// Fotografia devolvida a qualquer pedido de seleção.
  final Uint8List bytes;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile.fromData(bytes, mimeType: 'image/png');
}

/// Instala o seletor simulado e regessa a reposição da instância anterior.
///
/// Uso nos testes:
/// ```dart
/// mockImagePicker(base64Decode(tinyPng));
/// ```
void mockImagePicker(Uint8List bytes) {
  final previous = ImagePickerPlatform.instance;
  ImagePickerPlatform.instance = FakeImagePickerPlatform(bytes);
  addTearDown(() {
    ImagePickerPlatform.instance = previous;
  });
}
