# Nacala Entrega

Aplicação Flutter de entregas locais para **Nacala-Porto, Nampula** — liga
clientes a restaurantes, mercados, farmácias e lojas de bairro.

## O que já funciona

- **Cliente**
  - Pesquisa e filtro por categoria de locais próximos.
  - Página de cada local com menu e preços.
  - Carrinho com quantidades (um local por pedido).
  - Checkout com morada, notas e pagamento (M-Pesa, e-Mola ou dinheiro).
  - Histórico de pedidos com acompanhamento em tempo real (simulado).
- **Parceiro** (modo demonstração): vendas, pedidos recentes, despesas e repasses.
- **Administração** (modo demonstração): movimento, parceiros e pendentes.
- **Modo claro e escuro**, seguindo o sistema.
- Pedidos e morada guardados localmente (`shared_preferences`).

O modo demonstração ativa-se em **Conta → Modo demonstração** e mostra a barra
de perfis no topo (Cliente / Parceiro / Admin). Em produção este seletor deve
ser removido e substituído por autenticação real.

Ainda **não** existem backend, autenticação real, pagamentos efetivos nem
rastreio de estafeta. Os dados dos painéis de parceiro/admin são demonstrativos.

## Arquitetura

```
lib/
├── main.dart                    # arranque + SharedPreferences
├── app.dart                     # MaterialApp, tema claro/escuro
├── models/                      # Place, Product, CartLine, Order, Partner
├── data/mock_data.dart          # catálogo demonstrativo
├── state/
│   ├── app_state.dart           # ChangeNotifier: carrinho, pedidos, morada
│   └── app_scope.dart           # InheritedNotifier (injeção sem dependências)
├── screens/
│   ├── root_shell.dart          # navegação + barra de perfis (demo)
│   ├── customer/                # home, loja, carrinho, checkout, pedidos, conta
│   ├── partner/                 # painel do parceiro
│   └── admin/                   # painel de administração
├── widgets/                     # componentes reutilizáveis
├── theme/                       # cores e ThemeData
└── utils/                       # formatação (MT, datas) e snackbars
```

Gestão de estado com `ChangeNotifier` + `InheritedNotifier` — sem pacotes
externos de estado. Para crescer, o passo natural é migrar para Riverpod ou
Bloc e adicionar `go_router`.

## Executar

```sh
flutter pub get
flutter run
```

## Testes e análise

```sh
dart analyze lib test
flutter test
```

Cobertura atual: fluxo completo de compra, pesquisa/filtros, validação de
checkout, modo demonstração e regras do carrinho/pedidos.

## Build de release

O `applicationId` é `com.nacaladelivery.app` e a assinatura é lida de
`android/key.properties` (ignorado pelo git):

```properties
storePassword=...
keyPassword=...
keyAlias=nacala
storeFile=nacala-release.jks
```

Para gerar um novo keystore:

```sh
keytool -genkeypair -v -keystore android/app/nacala-release.jks \
  -alias nacala -keyalg RSA -keysize 2048 -validity 10000
```

> **Guarde o keystore e as palavras-passe em local seguro.** Sem eles não é
> possível publicar atualizações na Play Store.

Build:

```sh
flutter build apk --release --split-per-abi   # APKs por arquitetura (~17 MB)
flutter build appbundle --release             # para a Play Store
```

## Próximos passos

1. Backend (Firebase/Supabase ou API própria) e autenticação por telemóvel.
2. Pagamentos reais M-Pesa/e-Mola e confirmação de entrega.
3. Notificações push e rastreio do estafeta no mapa.
4. Painéis de parceiro e admin ligados a dados reais.
5. CI/CD, flavors (dev/prod) e testes de integração.
