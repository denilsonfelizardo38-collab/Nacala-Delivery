/// Configuração da API.
///
/// Em desenvolvimento usa `adb reverse tcp:8080 tcp:8080` e o valor por
/// omissão. Em produção compile com:
/// `--dart-define=API_BASE_URL=https://api.exemplo.co.mz`
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

const appVersion = '2.0.0';
