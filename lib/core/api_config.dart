/// Configuração da API.
///
/// Por omissão aponta para o servidor publicado no Render, para que o APK
/// instalado funcione sem flags. Em desenvolvimento local compile com:
/// `--dart-define=API_BASE_URL=http://127.0.0.1:8080` (com `adb reverse
/// tcp:8080 tcp:8080` num telemóvel ligado por USB).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://nacala-delivery.onrender.com',
);

const appVersion = '2.0.0';
