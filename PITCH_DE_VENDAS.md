# Nacala Entrega — Pitch de Vendas

> **A cidade à sua porta.** Peça local. Receba com cuidado.

---

## 1. O problema

Nacala-Porto, Nampula, tem comércio de bairro vibrante — restaurantes, mercados, farmácias e lojas locais — mas falta uma ponte digital que ligue esses estabelecimentos aos clientes da cidade. Hoje, quem quer pedir comida ou produtos locais depende de telefonemas, WhatsApp informal e entregas sem rastreio. Do outro lado, o pequeno comerciante não tem ferramentas para gerir pedidos, stock ou entregas de forma profissional.

O Nacala Entrega fecha essa lacuna com uma plataforma completa, feita para a realidade local.

---

## 2. A solução

Uma aplicação móvel (Flutter) + backend próprio (Dart + SQLite) que funciona em quatro frentes, numa só plataforma:

| Papel | O que faz |
|-------|-----------|
| **Cliente** | Descobre estabelecimentos próximos, pesquisa por categoria, monta carrinho, paga em MZN, acompanha o pedido em tempo real no mapa e repete compras com um toque. |
| **Parceiro (comerciante)** | Recebe pedidos na app, aceita ou rejeita com motivo, gere o menu (preço, stock, fotos), atualiza o estado da loja (aberto/fechado) e consulta métricas do dia. |
| **Estafeta** | Vê entregas disponíveis, aceita ou recusa, segue a rota viária até ao cliente e conclui a entrega com confirmação de posição GPS. |
| **Administrador** | Regista parceiros reais, aprova ou suspende estabelecimentos, gere utilizadores, acompanha pedidos da plataforma e consulta auditoria de ações. |

---

## 3. Diferenciais competitivos

- **Feito para Nacala.** Não é um clone genérico importado. A moeda é o metical (MZN), os endereços são locais, o suporte é em português e o foco é o comércio de bairro da cidade.
- **Backend real, não protótipo.** Servidor próprio em Dart (Shelf + SQLite) com autenticação por sessão (PBKDF2 + JWT), autorização por papel em todas as rotas sensíveis e totais de pedido recalculados no servidor — o cliente nunca define o preço final.
- **Segurança financeira.** Todos os valores são inteiros em cêntimos de metical. Sem vírgula flutuante no dinheiro. Criação de pedido em transação (pedido + itens + evento + entrega). Limite de tentativas de login (anti-força-bruta) e corpo JSON limitado a 1 MB.
- **Design premium, sempre escuro.** Tipografia própria (Bricolage Grotesque para títulos, Figtree para o corpo), cores de marca (#F2151C vermelho, fundo preto, superfícies escuras), estados de carregamento, vazio e erro em todos os ecrãs, alvos de toque ≥44 px.
- **Rastreio em tempo real.** Ponto de entrega escolhido no mapa, posição GPS do estafeta, rota viária e previsão de chegada atualizada.
- **Pronto para produção.** APKs de release já gerados (armeabi-v7a, arm64-v8a, x86_64), CI automatizado (format + analyze + test), documentação de deploy em Render e Fly.io.

---

## 4. Qualidade comprovada

- **Flutter:** 40/40 testes a passar (formatação monetária, sessão, carrinho, checkout, repetição de pedido, conta de admin, notificações, localização).
- **Servidor:** 29/29 testes a passar (autenticação, autorização por papel, totais no servidor, cupões, transições de parceiro/estafeta, isolamento entre estabelecimentos, pagamentos mKesh, JSON inválido → 400, corpo excessivo → 413, bloqueio 429, health check).
- **Análise estática:** sem erros nem avisos em `dart analyze` (Flutter e servidor).

---

## 5. Modelo de negócio (sugestão)

A plataforma está pronta para ser monetizada de imediato:

1. **Comissão por pedido** — percentagem sobre cada venda concluída através da app.
2. **Subscrição do parceiro** — plano mensal para estabelecimentos que queiram destaque no catálogo ou funcionalidades avançadas.
3. **Taxa de entrega** — definida pelo parceiro e cobrada ao cliente.
4. **Promoções destacadas** — banner de marca e posição privilegiada na home para comerciantes pagos.

Os métodos de pagamento expostos na UI incluem dinheiro, mKesh e outros móveis (M-Pesa/e-Mola pendentes de integração com credenciais do comerciante).

---

## 6. Estado atual e roadmap

**Versão 2.0.0+2 — já funcional:**
- App cliente, parceiro, estafeta e admin completa.
- Backend com SQLite, migrações versionadas e seed de produção.
- Deploy em container Docker (Render, Fly.io, Koyeb, etc.).

**Próximos passos (valor imediato para o comprador):**
- Integração de pagamentos móveis automática (M-Pesa, e-Mola, mKesh) via callback.
- Upload de imagens para armazenamento de objetos (hoje suporta links públicos HTTPS).
- Notificações push para atualizações de estado do pedido.
- Versão web e iOS (já suportadas pelo Flutter, pendentes de build).

---

## 7. Por que investir agora

O comércio local em Nacala-Porto está a digitalizar, e não existe ainda uma plataforma dominante focada na cidade. O Nacala Entrega chega com tecnologia própria, testes automatizados, design de marca e arquitetura pronta para escalar — sem depender de serviços externos caros ou assinaturas de terceiros.

**Quer ver a plataforma ao vivo?**
O servidor roda localmente com `dart run bin/server.dart` e a app com `flutter run`. O primeiro acesso é como administrador (`admin@nacala.co.mz`), a partir do qual se registam os primeiros parceiros reais.

---

*Desenvolvido com foco em Nacala-Porto, Nampula. Código aberto para avaliação técnica sob consulta.*
