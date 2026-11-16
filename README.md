# Nacala Entrega

Plataforma de entregas locais para **Nacala-Porto, Nampula** — liga clientes a
restaurantes, mercados, farmácias e lojas de bairro, com portal de parceiro,
gestão de estafetas e administração da plataforma.

> **A cidade à sua porta.** Peça local. Receba com cuidado.

A versão 2 substitui o protótipo demonstrativo por uma aplicação com **backend
real (Dart + SQLite)**, autenticação por sessão, autorização por papéis e
totais calculados no servidor.

---

## O que funciona

### Cliente
- Arranque com identidade da marca, login e registo.
- Home com saudação, morada selecionada, pesquisa com debounce, banner de marca
  e estabelecimentos próximos vindos da API.
- Ecrã de categorias com contagem real de parceiros e filtro.
- Página de estabelecimento com capa, horário, taxa de entrega, avaliações
  reais e menu por categoria.
- Carrinho persistido (um estabelecimento por pedido), quantidades, notas por
  item, subtotal, taxa e total em MZN.
- Checkout com moradas guardadas, contacto, nota, cupão e método de pagamento.
- Acompanhamento do pedido com estados, eventos e atualização manual.
- Acompanhamento de entregas em tempo real: ponto de entrega escolhido no mapa,
  posição GPS do estafeta, rota viária e previsão de chegada atualizada.
- Histórico com filtros (todos / em curso / entregues), detalhe e repetição de
  pedido quando os produtos continuam disponíveis.
- Conta: perfil, moradas CRUD, alteração de palavra-passe, cupões e logout.
- Favoritos, mensagens com o estabelecimento (chat) e registo de chamadas.
- Recuperação de palavra-passe por **código exibido uma vez** no registo
  (não depende de email/SMS).

### Parceiro
- Painel com estabelecimento, estado aberto/fechado, métricas do dia e totais
  reais, avaliações e pedidos recentes.
- Gestão de pedidos: aceitar, rejeitar com motivo, iniciar preparação e marcar
  como pronto (transições validadas no servidor).
- Gestão de produtos: criar, editar, preço em MZN, stock, categoria do menu,
  disponibilidade, carregamento de fotografias do dispositivo (JPEG, PNG ou
  WebP até 5 MB) e desativação. As imagens ficam em `server/data/uploads`;
  links públicos HTTPS também continuam suportados.
- Perfil do estabelecimento: descrição, contacto, morada, horário e abertura.

### Estafeta
- Candidatura própria com **NUIT** e documentos obrigatórios carregados como
  ficheiro (selfie, B.I. frente, B.I. verso e carta de condução), com
  acompanhamento do estado até à aprovação.
- Entregas disponíveis, em curso e histórico.
- Aceitar, recusar e concluir entregas; contacto e morada apenas do pedido
  atribuído.
- Partilha de posição GPS durante a entrega (apagada ao concluir, por
  privacidade).

### Administração
- **Candidaturas** de estabelecimentos e estafetas (ver **API →
  Candidaturas**): fila com contagens, aprovação, recusa com nota e pedido de
  alterações — cada decisão é notificada ao candidato.
- Registo de parceiros reais (conta + estabelecimento) com **NUIT**
  obrigatório e fotografia carregada como ficheiro; o catálogo começa vazio
  e é preenchido pela administração.
- **Funcionários** criados pelo administrador com nível (`admin`/`staff`) e
  permissões por módulo (pedidos, produtos, estabelecimentos, clientes,
  candidaturas, notificações); activação/desactivação invalida a sessão de
  imediato.
- Métricas da plataforma (clientes, parceiros ativos, estafetas, pedidos,
  vendas) calculadas por consultas reais.
- Fila de aprovação de parceiros, suspensão e reativação.
- Gestão de utilizadores (papel e estado da conta).
- Pedidos da plataforma com filtros e detalhe.
- Notificações da plataforma (por utilizador, com contagem de não lidas).
- Categorias (criar/eliminar) e registo de auditoria.

### Transversal
- Design system centralizado, **sempre em tema escuro** (`AppTheme.dark()`
  é aplicada em `theme`, `darkTheme` e `themeMode: ThemeMode.dark` — a
  aplicação não expõe escolha de tema):
  - tipografia **Bricolage Grotesque** nos títulos e **Figtree** no corpo,
    incluídas na aplicação (instâncias estáticas geradas a partir das
    fontes variáveis OFL);
  - destaque vermelho `#F2151C` (pressionado `#C10D13`, tinta `#FF4A50`),
    fundo `#000000`, superfícies `#141414` · `#1F1F1F` · `#2B2B2B`, texto
    `#FFFFFF` · `#B9B9B9` · `#858585`;
  - estados verde `#2BD46F`, âmbar `#FFA41B` e ouro `#FFB81C` sobre fundos
    escuros próprios (`#0D2417`, `#241704`, `#2A0709`);
  - escala de raios 10 · 14 · 20 · 28 px, campos e cartões com contorno
    discreto, botões e filtros em pílula (999 px);
  - navegação inferior em cápsula vermelha com o item ativo em selo preto,
    barra lateral `#0B0B0B` e trilho de administração vermelho;
  - splash com fotografia noturna de Nacala, capas de estabelecimentos e
    fotografias reais dos produtos carregadas pelos parceiros.
- Layout responsivo: navegação inferior para cliente/parceiro/estafeta, trilho
  lateral para administração em mobile e *sidebar* em ecrãs largos.
- Estados de carregamento, vazio e erro em todos os ecrãs com dados remotos.
- Feedback em português; alvos de toque ≥44 px; *safe areas* respeitadas.
- Sessão persistida e revalidada em `/api/auth/me`; `401` limpa a sessão.
- Notificações locais (barra de estado) com som próprio por evento, alimentadas
  por *polling* a `/api/notifications`.

---

## Arquitetura

```
Nacala Derivery/
├── lib/                         # aplicação Flutter
│   ├── main.dart                # arranque + SharedPreferences
│   ├── app.dart                 # MaterialApp, gate de sessão, rotas nomeadas
│   ├── core/                    # cliente HTTP, configuração, formatação
│   ├── data/api_service.dart    # contrato tipado da API
│   ├── models/models.dart       # modelos + CartStore
│   ├── state/                   # AppState (ChangeNotifier) e AppScope
│   ├── theme/                   # cores e ThemeData
│   ├── widgets/                 # componentes partilhados
│   └── screens/                 # auth, customer, partner, delivery, admin
├── server/                      # API Dart (shelf + SQLite)
│   ├── bin/server.dart          # entrypoint
│   ├── lib/src/api.dart         # rotas, regras de negócio, autorização
│   ├── lib/src/auth.dart        # PBKDF2 + JWT
│   ├── lib/src/db.dart          # migrações e helpers SQL
│   ├── lib/src/seed.dart        # fixtures de desenvolvimento
│   └── test/api_test.dart       # testes de integração da API
└── test/                        # testes Flutter (estado, formatação, widgets)
```

### Backend
- **Dart + shelf + shelf_router + sqlite3**, sem serviços externos.
- Base de dados SQLite com **migrações versionadas** (`migrations`), incluindo
  reconstruções de tabela com verificação de integridade referencial.
- CORS configurável, tratamento uniforme de erros (`ApiError`), *health check*
  em `/health` que **toca na base de dados** (503 se indisponível), limitação
  de tentativas de login/registo e log de pedidos (método, rota, estado,
  duração).
- Autenticação **PBKDF2-HMAC-SHA256** (120 000 iterações, salt por utilizador)
  calculada em *isolate*, e **JWT HS256** com `token_version` para invalidar
  sessões após alteração de palavra-passe, papel ou estado da conta.
- Autorização por papel em **todas** as rotas sensíveis
  (`customer | partner | delivery | admin`); o parceiro só acede ao próprio
  estabelecimento e o estafeta apenas às entregas atribuídas.
- Auditoria de ações de negócio e administração.

### Dinheiro
- Todos os valores são inteiros em **centavos de metical** (`*_cents`), moeda
  `MZN`. Nenhum cálculo monetário usa vírgula flutuante.
- Os preços e totais são **recalculados no servidor** ao criar o pedido; o
  cliente nunca define o total.
- Cada linha de pedido guarda um **snapshot** do nome e do preço unitário.
- A criação do pedido corre numa **transação** (pedido, itens, evento e
  atribuição de entrega).

### Estados do pedido

```
pending → confirmed → preparing → ready → on_the_way → delivered
        ↘ rejected                ↘ cancelled
```

A atribuição de entrega é criada ao entrar em `preparing`; o estafeta aceita
(`on_the_way`) e conclui (`delivered`).

---

## Executar localmente

### 1. Servidor

```sh
cd server
dart pub get
JWT_SECRET=dev-test-secret dart run bin/server.dart
```

O servidor fica em `http://127.0.0.1:8080` (o primeiro arranque demora ~10 s
porque gera o hash da conta de administração). A base de dados é criada em
`server/data` (ignorada pelo git).

O arranque normal cria **apenas** a conta de administração e as quatro
categorias do catálogo. Não existem parceiros, produtos, pedidos ou avaliações
fictícios: os parceiros reais são registados no portal de administração.

Variáveis de ambiente:

| Variável     | Omissão                                  | Descrição |
| ------------ | ---------------------------------------- | --------- |
| `PORT`       | `8080`                                   | porta HTTP |
| `DB_PATH`    | `data`                                   | caminho da base SQLite |
| `UPLOADS_DIR` | `data/uploads`                          | pasta persistente para imagens carregadas |
| `JWT_SECRET` | segredo de desenvolvimento (com aviso)   | **definir em produção** |
| `SEED`       | ativo                                    | `SEED=0` não cria administrador/categorias |
| `SEED_DEMO`  | desligado                                | `SEED_DEMO=1` cria dados de demonstração (apenas desenvolvimento/testes) |

### 2. Aplicação Flutter

```sh
flutter pub get
flutter run
```

O cliente liga por omissão ao servidor publicado no Render
(`https://nacala-delivery.onrender.com`). Para desenvolvimento local
(apontando ao próprio computador):

```sh
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

Para outro endereço (emulador, LAN ou produção):

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
flutter build apk --release --dart-define=API_BASE_URL=https://<o-teu-host>
```

O tráfego em texto simples só está autorizado para `127.0.0.1`, `localhost` e
`10.0.2.2` (`android/app/src/main/res/xml/network_security_config.xml`).

### Primeiro acesso

| Papel         | Email                | Palavra-passe                        |
| ------------- | -------------------- | ------------------------------------ |
| Administrador | `admin@nacala.co.mz` | definida no arranque (ver abaixo)    |

A palavra-passe inicial do administrador é resolvida nesta ordem:

1. `SEED_DEMO=1` (testes/demonstração): `Admin@1234`, determinística.
2. Variável `ADMIN_PASSWORD` (mínimo 8 caracteres com letras e números).
3. Caso contrário, é **gerada aleatoriamente e impressa uma única vez** no
   log do servidor no primeiro arranque — guarde-a nesse momento.

A antiga `Admin@1234` publicada no README já **não** nasce em produção.

1. Entrar como administrador.
2. Abrir **Parceiros → Registar parceiro**.
3. Preencher os dados da conta do parceiro (email, telemóvel, palavra-passe
   inicial) e do estabelecimento (nome, categoria, **NUIT**, morada, taxa de
   entrega, horário, fotografia carregada como ficheiro). O parceiro fica
   ativo e visível no catálogo de imediato.

Os clientes registam-se na app. Os estafetas candidatam-se por **Candidaturas**
(com NUIT e documentos) e a administração aprova antes de o painel de entregas
desbloquear; o papel é promovido na aprovação (a alteração manual em
**Utilizadores** continua disponível para migrações de contas antigas).

> `SEED_DEMO=1` repõe o conjunto antigo de dados de demonstração (parceiros,
> produtos, pedidos e cupões `BEMVINDO10`/`ENTREGA50`). Serve apenas para
> testes e nunca deve ser usado em produção.

---

## Deploy grátis (backend)

O servidor Dart (Shelf + SQLite) pode ser publicado como container Docker em
qualquer host que suporte Docker (Render, Fly.io, Railway, Koyeb, etc.).

### Variáveis de ambiente

| Variável              | Omissão                     | Descrição                                            |
| --------------------- | --------------------------- | ---------------------------------------------------- |
| `PORT`                | `8080`                      | porta HTTP                                          |
| `DB_PATH`             | `data`                      | diretório da base SQLite                            |
| `UPLOADS_DIR`         | `data/uploads`              | pasta persistente para imagens                      |
| `JWT_SECRET`          | — (obrigatória)             | segredo HS256; **o servidor recusa arrancar sem ele** |
| `ALLOW_DEV_JWT_SECRET`| desligado                   | `1` permite o segredo de desenvolvimento (só local)  |
| `ADMIN_PASSWORD`      | aleatória (log no arranque) | palavra-passe inicial do administrador               |
| `CORS_ORIGIN`         | `*`                         | origem permitida (ex.: `https://app.exemplo.com`)    |
| `SEED`                | ativo                       | `SEED=0` não cria administrador/categorias           |
| `SEED_DEMO`           | desligado                   | `SEED_DEMO=1` cria dados de demonstração             |

O endpoint de login/registo limita tentativas falhadas por IP (10/min no
login, 5/10 min no registo) e devolve `429` quando excedidas. Os corpos JSON
estão limitados a 1 MB e todos os pedidos ficam registados no log com método,
rota, estado e duração.

### Opção 1 — Render (recomendado para teste gratuito)

1. Cria conta em [render.com](https://render.com) e **New → Web Service**.
2. Liga o repositório GitHub do Nacala Delivery.
3. Configura: **Runtime = Docker**, **Dockerfile path = `server/Dockerfile`**.
4. Instance type: **Free**.
5. Define as variáveis de ambiente (`PORT=8080`, `DB_PATH=/data`,
   `UPLOADS_DIR=/data/uploads`, `JWT_SECRET=<segredo aleatório>`, `SEED=1`).
   **Não definas `SEED_DEMO`** — em produção ele enche o catálogo com lojas,
   contas e pedidos de demonstração. Sem `JWT_SECRET` o serviço **não arranca**
   (é proposital).
6. Publica e guarda a URL gerada (ex.: `https://<nome>.onrender.com`).

> **Disco efémero:** o plano gratuito do Render não tem disco persistente — a
> base SQLite (`/data`) e as imagens sobrevivem a *redeploys* apenas em planos
> com disco montado (ou via Fly.io volume). Perde os dados a cada apagamento do
> serviço; para produção, monte um disco ou use armazenamento de objetos.

### Opção 2 — Fly.io

```sh
cd server
fly launch --no-deploy
fly volumes create data --size 1
fly secrets set JWT_SECRET=<segredo>
fly deploy
```

### Ligar a app Flutter ao backend remoto

```sh
flutter run --dart-define=API_BASE_URL=https://<o-teu-host>:8080
```

> **Nota:** planos gratuitos (Render, Fly.io, Koyeb) podem "adormecer" após
> inatividade. O primeiro pedido após o spin-down demora ~30–60 s (cold start).
> Para testes contínuos, prefira instância sempre ativa no plano gratuito.

---

## API

Rotas principais (todas sob `/api`, JSON, `Authorization: Bearer <token>`):

- **Auth**: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`,
  `PATCH /auth/profile`, `POST /auth/change-password`, `POST /auth/logout`,
  `POST /auth/recover` (código de recuperação), `POST /auth/recovery-code`,
  `POST /auth/avatar`.
- **Catálogo**: `GET /categories`, `GET /establishments`,
  `GET /establishments/<id>`, `GET /establishments/<id>/products`,
  `GET /products`, `GET /search`.
- **Cliente**: `GET/POST /addresses`, `PATCH/DELETE /addresses/<id>`,
  `POST /coupons/validate`, `POST /orders`, `GET /orders`, `GET /orders/<id>`,
  `POST /orders/<id>/cancel`, `POST /orders/<id>/review`,
  `GET/POST/DELETE /favorites[/<id>]`.
- **Candidaturas**: `POST /applications` (estabelecimento ou estafeta, com
  NUIT), `POST /applications/images` (documentos), `GET /applications/me`.
- **Parceiro**: `GET /partner/summary`, `GET /partner/orders`,
  `POST /partner/orders/<id>/{accept,reject,preparing,ready}`,
  `GET/POST /partner/products`, `PATCH/DELETE /partner/products/<id>`,
  `POST /partner/product-images`, `GET/PATCH /partner/establishment`.
- **Estafeta**: `GET /delivery/assignments`, `GET /delivery/history`,
  `POST /delivery/assignments/<id>/{accept,decline,start,complete}`,
  `POST /delivery/assignments/<id>/location` (GPS durante a entrega).
- **Notificações**: `GET /notifications`, `POST /notifications/read`.
- **Mensagens**: `GET/POST /conversations`, `GET/POST
  /conversations/<id>/messages`, `POST /conversations/<id>/read`,
  `GET/POST /call-logs` (só participantes; terceiros recebem 403).
- **Admin**: `GET /admin/summary`, `GET /admin/partners`,
  `POST /admin/partners` (registo de parceiro + estabelecimento, com NUIT e
  fotografia), `POST /admin/partner-images`,
  `POST /admin/partners/<id>/{approve,reject}`, `GET /admin/users`,
  `PATCH /admin/users/<id>`, `GET /admin/orders`, `GET /admin/audit`,
  `GET/POST /admin/applications`, `POST /admin/applications/<id>/{approve,
  reject,changes}`, `GET/POST/PATCH/DELETE /admin/employees[/<id>]`,
  `GET /admin/notifications`, `POST/PATCH/DELETE /admin/categories...`.

**Paginação:** as listagens (`/establishments`, `/orders`,
`/partner/orders`, `/admin/orders`, `/admin/users`) aceitam `limit`
(teto 500) e `offset` e devolvem `has_more` para paginação incremental. Por
omissão mantêm os limites anteriores (100/200), por isso clientes existentes
não mudam de comportamento.

---

## Testes e análise

```sh
# Flutter
dart analyze lib test
flutter test

# Servidor
cd server
dart analyze
dart test
```

Estado atual:

- `dart analyze lib test server`: sem erros nem avisos (restam apenas 8
  sugestões informativas externas `use_null_aware_elements` e
  `use_build_context_synchronously`).
- `flutter test`: **71/71** a passar (formatação monetária, sessão, carrinho,
  arranque/login/home, confirmação do checkout, repetição de pedido, menu de
  conta do administrador, favoritos, notificações, localização, candidaturas
  com NUIT/documentos, funcionários e permissões, produtos do parceiro,
  splash e offline).
- `server`: `dart analyze lib bin test` sem problemas e `dart test` **58/58**
  a passar (autenticação, autorização por papel, permissões de funcionários,
  candidaturas e aprovação, NUIT, documentos do estafeta, totais no servidor,
  cupões, indisponibilidade de produtos, transições de parceiro/estafeta,
  chat com bloqueio de terceiros, isolamento entre estabelecimentos,
  pagamentos mKesh, JSON inválido → 400, corpo excessivo → 413, bloqueio de
  força-bruta 429 e `/health`).
- **Smoke E2E** (fluxos HTTP reais contra o servidor local com
  `SEED_DEMO=1`): **99/99 verificações OK** cobrindo os TESTEs 1–16 do
  specification (registo/login, candidaturas, aprovações, produtos,
  funcionários e permissões, ciclo completo de pedido com mapa e GPS,
  notificações, splash, funcionalidades antigas e limites de tentativas).
  Script reutilizável em `tool/smoke_e2e.py` (ver "Limitações conhecidas").
- O CI (`.github/workflows/ci.yml`) corre **os dois conjuntos**: Flutter
  (format + analyze + test) e servidor (format + analyze + test) em jobs
  separados.

Os testes usam `test/fake_api.dart` e `test/fake_image_picker.dart`
(implementações falsas explícitas) e uma base SQLite `:memory:` partilhada;
nenhum teste depende de rede ou dados reais.

---

## Build de release

`applicationId`: `com.nacaladelivery.app`. A assinatura é lida de
`android/key.properties` (ignorado pelo git):

```properties
storePassword=...
keyPassword=...
keyAlias=nacala
storeFile=nacala-release.jks
```

```sh
flutter build apk --release --split-per-abi   # APKs por arquitetura
flutter build appbundle --release             # Play Store
```

Última build validada (16 Nov 2026): `app-armeabi-v7a-release.apk` (22,0 MB),
`app-arm64-v8a-release.apk` (24,4 MB), `app-x86_64-release.apk` (25,9 MB) e o
`app-release.apk` único com os três ABIs (63,3 MB) — todos assinados com a
chave de release (`CN=Nacala Entrega`).

> **Guarde o keystore e as palavras-passe em local seguro.** Sem eles não é
> possível publicar atualizações na Play Store.

---

## Integrações pendentes

- **Pagamentos M-Pesa/e-Mola/mKesh**: a UI expõe os métodos (o mKesh já é
  guardado na base desde a migração 6), mas a cobrança automática **não está
  integrada**. O pedido é registado com
  `payment_status = pending_integration` (ou `cash_on_delivery` para dinheiro) e
  o utilizador é avisado no checkout. É necessária uma conta de comerciante e
  credenciais do fornecedor (API M-Pesa / e-Mola) para implementar o fluxo de
  cobrança e confirmação por *callback*.
- **Imagens**: uploads locais funcionam (produtos, fotografia do parceiro,
  avatar e documentos de candidatura ficam em `server/data/uploads`, com
  validação de tipo/tamanho). Falta, para produção, **armazenamento
  persistente** (o disco do Render é efémero: as imagens desaparecem no
  redeploy) — integre um serviço de objetos (S3, Cloudinary, etc.) quando
  houver credenciais.
- **Mapa e GPS**: OpenStreetMap mostra o ponto do cliente e a posição do
  estafeta; o serviço OSRM calcula a rota e a previsão de chegada. A partilha
  inicia quando o estafeta toca em **Iniciar entrega** e exige permissão de
  localização. Os serviços públicos de mapas/rotas têm limites e não oferecem
  SLA; para produção, configure fornecedores próprios ou serviços contratados.
  O APK deve apontar para uma API acessível pelos dois telemóveis via
  `--dart-define=API_BASE_URL=https://...` (a configuração `localhost` é apenas
  para desenvolvimento).
- **Notificações push (FCM/APNs)**: inexistentes. Existem notificações
  locais no telemóvel (polling a `/api/notifications`); push automático
  exigiria credenciais do fornecedor.
- **Pagamentos/recibos e comissões da plataforma**: as métricas de vendas são
  reais; o modelo de comissão ainda não está definido.
- **Reposição de palavra-passe por email/SMS**: a reposição por **código de
  recuperação** (exibido uma vez no registo, regenerável autenticadamente)
  está implementada e testada; falta a entrega automática por email/SMS —
  exige fornecedor (SMTP, Twilio, etc.) e credenciais.

---

## Segurança

- Palavras-passe com PBKDF2-HMAC-SHA256 (120 000 iterações) em *isolate*;
  nunca em texto simples e sem bloquear o event loop.
- JWT assinado no servidor; o arranque **recusa** usar o segredo de
  desenvolvimento (use `JWT_SECRET` ou `ALLOW_DEV_JWT_SECRET=1` apenas em
  local).
- Conta de administração semeada com `ADMIN_PASSWORD` ou palavra-passe
  aleatória impressa uma vez no log — nunca com credenciais públicas fixas.
- Autorização por papel no backend em todas as rotas sensíveis.
- Limite de tentativas de login/registo por IP (429) e corpos JSON limitados
  a 1 MB (413); tentativas de login falhadas ficam em `audit_logs`.
- Consultas SQL parametrizadas e validação de entrada nos limites do sistema.
- CORS restritível por variável `CORS_ORIGIN`.
- Auditoria de ações administrativas e de negócio.
- Nenhum dado de outro cliente é devolvido ao cliente autenticado.

## Limitações conhecidas

- A pesquisa do catálogo é feita no servidor (insensível a acentos), mas a
  pesquisa dentro das listas de parceiro/admin é local ao ecrã.
- Não há testes de integração end-to-end em dispositivo; o **smoke E2E por
  HTTP** (`tool/smoke_e2e.py`, 99 verificações contra um servidor local com
  `SEED_DEMO=1` na porta 8099) cobre os fluxos de negócio e a validação da
  UI em telemóvel é manual.
- O limite de tentativas de login é em memória (por instância) — correto para
  o SQLite de instância única desta API.
