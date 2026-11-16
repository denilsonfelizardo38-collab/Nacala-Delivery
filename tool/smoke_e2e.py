#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Smoke E2E — TESTEs 1..16 do spec Nacala Delivery.

Corre contra um servidor local de smoke. Usa apenas fluxos HTTP reais como
evidência (nenhum mock). Uso:

    # 1) levantar o servidor com base temporária e dados demo:
    cd server
    PORT=8099 DB_PATH=/tmp/smoke.db JWT_SECRET=smoke-secret \
      SEED_DEMO=1 UPLOADS_DIR=/tmp/smoke-uploads dart run bin/server.dart &
    # 2) correr os TESTEs 1..16:
    python3 tool/smoke_e2e.py            # ou SMOKE_BASE=http://ip:8099 ...

O script cria utilizadores com telemóveis próprios, por isso convém correr
contra uma base limpa; no fim valida também o bloqueio de força-bruta (429),
que é em memória por IP.
"""
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("SMOKE_BASE", "http://127.0.0.1:8099")
TINY_PNG = (
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQ"
    "GAhKmMIQAAAABJRU5ErkJggg=="
)

checks = []  # (teste, descricao, ok, detalhe)


def req(method, path, body=None, token=None):
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    r = urllib.request.Request(BASE + path, data=data, method=method)
    if data is not None:
        r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(r, timeout=20) as resp:
            status, text = resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        status, text = e.code, e.read().decode("utf-8", "replace")
    try:
        parsed = json.loads(text) if text else {}
    except Exception:
        parsed = {"_raw": text}
    return status, parsed


def check(teste, desc, cond, detail=""):
    ok = bool(cond)
    checks.append((teste, desc, ok, str(detail)[:220]))
    mark = "OK  " if ok else "FAIL"
    line = "  %s %s" % (mark, desc)
    if not ok and detail:
        line += " — " + str(detail)[:220]
    print(line, flush=True)


def err_code(j):
    e = j.get("error")
    return e.get("code") if isinstance(e, dict) else None


def main():
    # ================================================================ TESTE 1
    print("== TESTE 1: Registo e login de clientes ==", flush=True)
    st, reg = req("POST", "/api/auth/register",
                  {"name": "Cliente Smoke", "phone": "845300001",
                   "password": "Smoke@1234"})
    check(1, "registo de cliente devolve token (201)",
          st == 201 and reg.get("token"), (st, reg))
    cust_token = reg.get("token", "")
    recovery_code = reg.get("recovery_code", "")
    check(1, "registo devolve código de recuperação",
          len(recovery_code) >= 6, recovery_code)

    st, dup = req("POST", "/api/auth/register",
                  {"name": "Cliente Smoke", "phone": "845300001",
                   "password": "Smoke@1234"})
    check(1, "telemóvel duplicado rejeitado",
          st != 201 and "error" in dup, (st, dup))

    st, lg = req("POST", "/api/auth/login",
                 {"identifier": "845300001", "password": "Smoke@1234"})
    check(1, "login por telemóvel devolve token (200)",
          st == 200 and lg.get("token"), (st, lg))
    cust_token = lg.get("token") or cust_token

    st, bad = req("POST", "/api/auth/login",
                  {"identifier": "845300001", "password": "Errada@999"})
    check(1, "palavra-passe errada rejeitado", st == 401, (st, bad))

    st, me = req("GET", "/api/auth/me", token=cust_token)
    check(1, "sessão restaurada em /api/auth/me",
          st == 200 and me.get("user", {}).get("phone") == "845300001",
          (st, me))

    # ================================================================ TESTE 2
    print("== TESTE 2: Registo de estabelecimentos (validação) ==", flush=True)
    est_payload = {
        "establishment_name": "Smoke Mercado Lda",
        "category_id": "cat_mercados",
        "nuit": "400011223",
        "description": "Loja de bairro para o smoke test.",
        "address": "Bairro Central, Rua 12, Nacala-Porto",
        "delivery_fee_cents": 1500,
        "prep_minutes": 20,
        "opens_at": "08:00",
        "closes_at": "20:00",
        "latitude": -14.5501,
        "longitude": 40.6812,
    }
    st, badnuit = req("POST", "/api/applications", {
        "kind": "establishment", "name": "Dono Inválido",
        "phone": "845100003", "password": "Smoke@1234",
        "payload": dict(est_payload, nuit="123"),
    })
    check(2, "NUIT inválido rejeitado (422 invalid_nuit)",
          st == 422 and err_code(badnuit) == "invalid_nuit", (st, badnuit))

    st, app1 = req("POST", "/api/applications", {
        "kind": "establishment", "name": "Dono Smoke",
        "phone": "845100001", "password": "Smoke@1234",
        "payload": est_payload,
    })
    check(2, "candidatura de estabelecimento aceite (201, pending)",
          st == 201 and app1.get("application", {}).get("status") == "pending",
          (st, app1))
    est_app_id = app1.get("application", {}).get("id", "")

    # ================================================================ TESTE 3
    print("== TESTE 3: Envio de candidatura ==", flush=True)
    st, aplg = req("POST", "/api/auth/login",
                   {"identifier": "845100001", "password": "Smoke@1234"})
    check(3, "conta pendente consegue iniciar sessão",
          st == 200 and aplg.get("token"), (st, aplg))
    pend_token = aplg.get("token", "")

    st, mine = req("GET", "/api/applications/me", token=pend_token)
    check(3, "candidatura visível em /api/applications/me (pending)",
          st == 200 and mine.get("application", {}).get("id") == est_app_id,
          (st, mine))

    st, panel = req("GET", "/api/partner/products", token=pend_token)
    check(3, "painel bloqueado antes da aprovação (403 pending_approval)",
          st == 403 and err_code(panel) == "pending_approval", (st, panel))

    # ================================================================ TESTE 4
    print("== TESTE 4: Visualização da candidatura no Admin ==", flush=True)
    st, admlg = req("POST", "/api/auth/login",
                    {"identifier": "admin@nacala.co.mz",
                     "password": "Admin@1234"})
    check(4, "login da administração", st == 200 and admlg.get("token"),
          (st, admlg))
    admin = admlg.get("token", "")

    st, apps = req("GET", "/api/admin/applications?status=pending",
                   token=admin)
    listed = [a for a in apps.get("applications", [])
              if a.get("phone") == "845100001"]
    check(4, "candidatura aparece na lista do admin com contagens",
          st == 200 and listed and isinstance(apps.get("counts"), dict),
          (st, apps))
    check(4, "candidatura encontrada por telemóvel",
          bool(listed), listed)

    # ================================================================ TESTE 5
    print("== TESTE 5: Aprovação de estabelecimento ==", flush=True)
    st, apr = req("POST", "/api/admin/applications/%s/approve" % est_app_id,
                  {}, token=admin)
    check(5, "aprovação devolve candidatura approved + establishment_id",
          st == 200 and apr.get("application", {}).get("status") == "approved"
          and apr.get("establishment_id"), (st, apr))
    est_id = apr.get("establishment_id", "")

    st, apps2 = req("GET", "/api/admin/applications?status=pending",
                    token=admin)
    check(5, "candidatura sai da lista de pendentes",
          st == 200 and not any(a.get("id") == est_app_id
                                for a in apps2.get("applications", [])),
          (st, apps2))
    st, apps3 = req("GET", "/api/admin/applications?status=approved",
                    token=admin)
    check(5, "candidatura aparece na lista de aprovadas",
          st == 200 and any(a.get("id") == est_app_id
                            for a in apps3.get("applications", [])),
          (st, apps3))

    # ================================================================ TESTE 6
    print("== TESTE 6: Login do estabelecimento aprovado ==", flush=True)
    st, ptok = req("POST", "/api/auth/login",
                   {"identifier": "845100001", "password": "Smoke@1234"})
    partner = ptok.get("token", "")
    check(6, "login do parceiro aprovado", st == 200 and partner, (st, ptok))

    st, prods = req("GET", "/api/partner/products", token=partner)
    check(6, "painel do parceiro acessível (200)",
          st == 200 and isinstance(prods.get("products"), list), (st, prods))

    st, peste = req("GET", "/api/partner/establishment", token=partner)
    check(6, "estabelecimento devolve NUIT registado",
          st == 200 and (peste.get("establishment") or {}).get("nuit")
          == "400011223", (st, peste))

    # ================================================================ TESTE 7
    print("== TESTE 7: Criação e edição de produtos ==", flush=True)
    st, prod = req("POST", "/api/partner/products",
                   {"name": "Arroz 5 kg", "price_cents": 12500,
                    "category": "Mercearia", "description": "Arroz calrosa",
                    "stock": 10}, token=partner)
    check(7, "produto criado (201)", st == 201 and
          prod.get("product", {}).get("id"), (st, prod))
    prod_id = prod.get("product", {}).get("id", "")

    st, upd = req("PATCH", "/api/partner/products/" + prod_id,
                  {"price_cents": 13500, "description": "Arroz calrosa (nov)"},
                  token=partner)
    check(7, "produto editado (200, preço novo)",
          st == 200 and upd.get("product", {}).get("price_cents") == 13500,
          (st, upd))

    st, otherlg = req("POST", "/api/auth/login",
                      {"identifier": "mercado@nacala.co.mz",
                       "password": "Parceiro@1234"})
    other_partner = otherlg.get("token", "")
    st, cross = req("DELETE", "/api/partner/products/" + prod_id,
                    token=other_partner)
    check(7, "parceiro alheio não elimina o produto (403/404)",
          st in (403, 404), (st, cross))

    # ================================================================ TESTE 8
    print("== TESTE 8: Registo de entregadores ==", flush=True)
    docs = {}
    for key in ("selfie", "bi_front", "bi_back", "license"):
        st, up = req("POST", "/api/applications/images",
                     {"mime_type": "image/png", "data_base64": TINY_PNG})
        if st != 201 or not up.get("image_url"):
            check(8, "upload de imagem " + key, False, (st, up))
            break
        docs[key] = up["image_url"]
    check(8, "4 documentos carregados em /api/applications/images",
          len(docs) == 4, docs)

    st, nodocs = req("POST", "/api/applications", {
        "kind": "delivery", "name": "Estafeta Sem Docs",
        "phone": "845100004", "password": "Smoke@1234",
        "payload": {"nuit": "400044557", "vehicle_type": "Mota",
                    "address": "Mucipal, Nacala-Porto"},
    })
    check(8, "documentos em falta rejeitados (422 missing_documents)",
          st == 422 and err_code(nodocs) in
          ("missing_documents", "missing_document"), (st, nodocs))

    st, cour = req("POST", "/api/applications", {
        "kind": "delivery", "name": "Estafeta Smoke",
        "phone": "845100002", "password": "Smoke@1234",
        "payload": {
            "nuit": "400044556",
            "vehicle_type": "Mota",
            "address": "Mucipal, Nacala-Porto",
            "notes": "Disponível de manhã.",
            "documents": docs,
        },
    })
    check(8, "candidatura de entregador com NUIT + 4 documentos (201)",
          st == 201 and cour.get("application", {}).get("status") == "pending",
          (st, cour))
    cour_app_id = cour.get("application", {}).get("id", "")

    # ================================================================ TESTE 9
    print("== TESTE 9: Aprovação de entregadores ==", flush=True)
    st, capr = req("POST",
                   "/api/admin/applications/%s/approve" % cour_app_id,
                   {}, token=admin)
    check(9, "aprovação de entregador (200 approved)",
          st == 200 and capr.get("application", {}).get("status") == "approved",
          (st, capr))

    # =============================================================== TESTE 10
    print("== TESTE 10: Login de entregadores aprovados ==", flush=True)
    st, dlg = req("POST", "/api/auth/login",
                  {"identifier": "845100002", "password": "Smoke@1234"})
    courier = dlg.get("token", "")
    check(10, "login do entregador aprovado", st == 200 and courier,
          (st, dlg))
    st, asg = req("GET", "/api/delivery/assignments", token=courier)
    check(10, "painel de entregas acessível (200, lista)",
          st == 200 and isinstance(asg.get("assignments"), list), (st, asg))

    # =============================================================== TESTE 11
    print("== TESTE 11: Criação de funcionários pelo administrador ==",
          flush=True)
    st, emp = req("POST", "/api/admin/employees",
                  {"name": "Funcionário Smoke", "email": "func.smoke@nacala.co.mz",
                   "phone": "845200001", "password": "Smoke@1234",
                   "level": "staff", "permissions": ["orders"]},
                  token=admin)
    check(11, "funcionário criado com nível e permissões (201)",
          st == 201 and emp.get("employee", {}).get("id")
          and emp.get("employee", {}).get("permissions") == ["orders"],
          (st, emp))
    emp_id = emp.get("employee", {}).get("id", "")

    st, elg = req("POST", "/api/auth/login",
                  {"identifier": "func.smoke@nacala.co.mz",
                   "password": "Smoke@1234"})
    employee = elg.get("token", "")
    check(11, "login do funcionário", st == 200 and employee, (st, elg))

    st, elist = req("GET", "/api/admin/employees", token=admin)
    check(11, "funcionário aparece na lista da administração",
          st == 200 and any(e.get("id") == emp_id
                            for e in elist.get("employees", [])), (st, elist))

    # =============================================================== TESTE 12
    print("== TESTE 12: Verificação de permissões ==", flush=True)
    st, _ = req("GET", "/api/admin/orders", token=employee)
    check(12, "funcionário com permissão `orders` acede a /admin/orders",
          st == 200, st)
    st, denied = req("GET", "/api/admin/applications", token=employee)
    check(12, "sem permissão `applications` → 403 missing_permission",
          st == 403 and err_code(denied) == "missing_permission",
          (st, denied))
    st, _ = req("GET", "/api/admin/employees", token=employee)
    check(12, "funcionário não lista funcionários (403, só admin)",
          st == 403, st)
    st, _ = req("POST", "/api/partner/products",
                {"name": "X", "price_cents": 100}, token=employee)
    check(12, "funcionário não escreve no painel de parceiro (403)",
          st == 403, st)
    st, _ = req("GET", "/api/admin/employees", token=cust_token)
    check(12, "cliente não acede a rotas de admin (403)", st == 403, st)
    st, _ = req("GET", "/api/partner/products", token=cust_token)
    check(12, "cliente não acede ao painel de parceiro (403)", st == 403, st)
    st, _ = req("GET", "/api/admin/orders")
    check(12, "rota protegida sem token → 401", st == 401, st)

    st, patch = req("PATCH", "/api/admin/employees/" + emp_id,
                    {"permissions": ["orders", "applications"]},
                    token=admin)
    check(12, "admin actualiza permissões do funcionário",
          st == 200 and sorted(patch.get("employee", {}).get("permissions", []))
          == ["applications", "orders"], (st, patch))
    st, _ = req("GET", "/api/admin/applications", token=employee)
    check(12, "nova permissão passa a valer imediatamente (200)",
          st == 200, st)

    st, deac = req("PATCH", "/api/admin/employees/" + emp_id,
                   {"is_active": False}, token=admin)
    check(12, "admin desactiva funcionário",
          st == 200 and deac.get("employee", {}).get("is_active") is False,
          (st, deac))
    st, _ = req("GET", "/api/admin/orders", token=employee)
    check(12, "sessão do funcionário desactivado invalidada (401)",
          st == 401, st)

    # =============================================================== TESTE 13
    print("== TESTE 13: Localização no mapa ==", flush=True)
    st, addr = req("POST", "/api/addresses",
                   {"label": "Casa", "line": "Bairro Central, Rua 12",
                    "latitude": -14.5428, "longitude": 40.6729},
                   token=cust_token)
    check(13, "morada com coordenadas guardada (201)",
          st == 201 and addr.get("address", {}).get("latitude") == -14.5428,
          (st, addr))
    st, badaddr = req("POST", "/api/addresses",
                      {"label": "Mau", "line": "Rua sem fim",
                       "latitude": 91, "longitude": 40.67},
                      token=cust_token)
    check(13, "coordenada inválida rejeitada (422 invalid_coordinates)",
          st == 422 and err_code(badaddr) == "invalid_coordinates",
          (st, badaddr))

    st, public = req("GET", "/api/establishments")
    ours = [e for e in public.get("establishments", []) if e.get("id") == est_id]
    check(13, "localização da candidatura chega ao catálogo público",
          st == 200 and ours and ours[0].get("latitude") == -14.5501
          and ours[0].get("longitude") == 40.6812, (st, ours))

    # --- ciclo completo do pedido com destino no mapa -------------------
    st, order = req("POST", "/api/orders", {
        "establishment_id": est_id,
        "address_line": "Bairro Central, Rua 12, casa 34",
        "address_label": "Casa",
        "phone": "845300001",
        "payment_method": "mpesa",
        "address_latitude": -14.5428,
        "address_longitude": 40.6729,
        # Preço adulterado pelo cliente: tem de ser ignorado.
        "items": [{"product_id": prod_id, "quantity": 2,
                   "price_cents": 999999}],
    }, token=cust_token)
    check(13, "pedido criado com destino no mapa (201, pending)",
          st == 201 and order.get("order", {}).get("status") == "pending",
          (st, order))
    oid = order.get("order", {}).get("id", "")
    oj = order.get("order", {})
    check(13, "totais calculados no servidor (ignora preço do cliente)",
          oj.get("subtotal_cents") == 27000 and
          oj.get("delivery_fee_cents") == 1500 and
          oj.get("total_cents") == 28500, oj)

    st, cross2 = req("POST", "/api/partner/orders/%s/accept" % oid, {},
                     token=other_partner)
    check(13, "parceiro alheio não aceita o pedido (403)", st == 403,
          (st, cross2))

    for action, want in (("accept", "confirmed"), ("preparing", "preparing"),
                         ("ready", "ready")):
        st, tr = req("POST", "/api/partner/orders/%s/%s" % (oid, action), {},
                     token=partner)
        check(13, "parceiro %s → %s" % (action, want),
              st == 200 and tr.get("order", {}).get("status") == want,
              (st, tr))

    st, asg2 = req("GET", "/api/delivery/assignments", token=courier)
    mine_a = [a for a in asg2.get("assignments", [])
              if a.get("order_id") == oid]
    check(13, "atribuição disponível aparece no painel do entregador",
          st == 200 and mine_a, (st, asg2))
    aid = mine_a[0].get("id", "") if mine_a else ""

    st, acc = req("POST", "/api/delivery/assignments/%s/accept" % aid, {},
                  token=courier)
    check(13, "entregador aceita a atribuição (200)",
          st == 200, (st, acc))
    st, start = req("POST", "/api/delivery/assignments/%s/start" % aid, {},
                    token=courier)
    check(13, "início de entrega com destino no mapa → on_the_way",
          st == 200 and start.get("order", {}).get("status") == "on_the_way",
          (st, start))
    st, badloc = req("POST", "/api/delivery/assignments/%s/location" % aid,
                     {"latitude": 91, "longitude": 40.67}, token=courier)
    check(13, "localização inválida do entregador rejeitada (422)",
          st == 422 and err_code(badloc) == "invalid_coordinates",
          (st, badloc))
    st, loc = req("POST", "/api/delivery/assignments/%s/location" % aid,
                  {"latitude": -14.54, "longitude": 40.67}, token=courier)
    check(13, "localização do entregador aceite (200)", st == 200, (st, loc))
    st, track = req("GET", "/api/orders/" + oid, token=cust_token)
    check(13, "cliente vê a localização do entregador no seguimento",
          st == 200 and (track.get("order", {}).get("delivery") or {})
          .get("latitude") == -14.54, (st, track))
    st, comp = req("POST", "/api/delivery/assignments/%s/complete" % aid, {},
                   token=courier)
    check(13, "entrega concluída → delivered",
          st == 200, (st, comp))
    st, done = req("GET", "/api/orders/" + oid, token=cust_token)
    doj = done.get("order", {})
    check(13, "pedido entregue e morada libertada (privacidade)",
          st == 200 and doj.get("status") == "delivered"
          and doj.get("address_latitude") is None, (st, doj))

    # =============================================================== TESTE 14
    print("== TESTE 14: Notificações ==", flush=True)
    st, pn = req("GET", "/api/notifications", token=partner)
    kinds = [n.get("kind") for n in pn.get("notifications", [])]
    check(14, "parceiro recebeu notificação da aprovação",
          st == 200 and "application_approved" in kinds, (st, kinds))
    st, rd = req("POST", "/api/notifications/read", {}, token=partner)
    check(14, "marcar notificações como lidas (200, updated)",
          st == 200 and isinstance(rd.get("updated"), int), (st, rd))
    st, pn2 = req("GET", "/api/notifications", token=partner)
    check(14, "contador de não lidas volta a zero",
          st == 200 and pn2.get("unread_count") == 0, (st, pn2))
    st, cn = req("GET", "/api/notifications", token=cust_token)
    check(14, "cliente lista notificações persistentes (200)",
          st == 200 and "notifications" in cn and "unread_count" in cn,
          (st, cn))
    st, an = req("GET", "/api/admin/notifications", token=admin)
    check(14, "administração acede às notificações (200)", st == 200, st)

    # =============================================================== TESTE 15
    print("== TESTE 15: Splash Screen (verificação de fundo) ==", flush=True)
    st, hl = req("GET", "/health")
    check(15, "/health responde ok (o splash não fica preso)",
          st == 200 and hl.get("status") == "ok", (st, hl))
    st, _ = req("GET", "/api/auth/me", token=cust_token)
    check(15, "restauro de sessão do splash responde (200)", st == 200, st)
    st, anon = req("GET", "/api/auth/me")
    check(15, "sem sessão o splash recebe 401 limpo (não texto puro)",
          st == 401 and isinstance(anon, dict) and "error" in anon,
          (st, anon))

    # =============================================================== TESTE 16
    print("== TESTE 16: Funcionalidades antigas operacionais ==", flush=True)
    st, cats = req("GET", "/api/categories")
    check(16, "catálogo de categorias", st == 200 and
          len(cats.get("categories", [])) >= 5, (st, cats))
    st, ests = req("GET", "/api/establishments")
    check(16, "lista de estabelecimentos", st == 200 and
          len(ests.get("establishments", [])) >= 3, (st, ests))
    st, eprods = req("GET", "/api/establishments/est_cantinho/products")
    check(16, "produtos do estabelecimento", st == 200 and
          len(eprods.get("products", [])) >= 1, (st, eprods))
    st, srch = req("GET", "/api/search?q=frango")
    check(16, "pesquisa global", st == 200 and
          "products" in srch and "establishments" in srch, (st, srch))

    st, fav = req("POST", "/api/favorites/est_cantinho", {}, token=cust_token)
    check(16, "favoritar estabelecimento (201)", st == 201, (st, fav))
    st, favs = req("GET", "/api/favorites", token=cust_token)
    check(16, "lista de favoritos contém o estabelecimento",
          st == 200 and any(e.get("id") == "est_cantinho"
                            for e in favs.get("establishments", [])),
          (st, favs))

    st, cpn = req("POST", "/api/coupons/validate",
                  {"code": "BEMVINDO10", "subtotal_cents": 100000},
                  token=cust_token)
    check(16, "cupão BEMVINDO10 valida e calcula desconto (10%)",
          st == 200 and cpn.get("coupon", {}).get("discount_cents") == 10000,
          (st, cpn))
    st, badcpn = req("POST", "/api/coupons/validate",
                     {"code": "NAOEXISTE", "subtotal_cents": 100000},
                     token=cust_token)
    check(16, "cupão inexistente rejeitado", st == 404, (st, badcpn))

    st, myorders = req("GET", "/api/orders", token=cust_token)
    check(16, "histórico de pedidos do cliente",
          st == 200 and any(o.get("id") == oid
                            for o in myorders.get("orders", [])), (st, myorders))
    st, porders = req("GET", "/api/partner/orders", token=partner)
    check(16, "pedidos do parceiro", st == 200 and
          isinstance(porders.get("orders"), list), (st, porders))
    st, summ = req("GET", "/api/admin/summary", token=admin)
    check(16, "métricas reais da administração",
          st == 200 and isinstance(summ.get("summary"), dict), (st, summ))
    st, audit = req("GET", "/api/admin/audit", token=admin)
    check(16, "registo de actividades com entradas reais",
          st == 200 and len(audit.get("logs", [])) >= 3, (st, audit))

    # parceiro edita o próprio estabelecimento
    st, pedit = req("PATCH", "/api/partner/establishment",
                    {"description": "Actualizado no smoke."},
                    token=partner)
    check(16, "parceiro edita descrição do estabelecimento",
          st == 200 and pedit.get("establishment", {}).get("description")
          == "Actualizado no smoke.", (st, pedit))

    # admin cria parceiro com NUIT + foto carregada (ficheiro)
    st, pimg = req("POST", "/api/admin/partner-images",
                   {"mime_type": "image/png", "data_base64": TINY_PNG},
                   token=admin)
    check(16, "admin carrega fotografia de parceiro (ficheiro, 201)",
          st == 201 and pimg.get("image_url"), (st, pimg))
    st, newp = req("POST", "/api/admin/partners", {
        "name": "Gestor Smoke", "email": "parceiro.smoke@nacala.co.mz",
        "phone": "846666661", "password": "Parceiro123",
        "establishment_name": "Loja Smoke", "category_id": "cat_lojas",
        "description": "Artigos para casa.",
        "address": "Bairro Central, Nacala-Porto",
        "delivery_fee_cents": 7500, "prep_minutes": 25,
        "opens_at": "08:00", "closes_at": "20:00",
        "nuit": "400077889", "image_url": pimg.get("image_url", ""),
    }, token=admin)
    check(16, "admin cria parceiro aprovado com NUIT (201)",
          st == 201 and newp.get("establishment", {}).get("nuit")
          == "400077889" and
          newp.get("establishment", {}).get("is_approved") is True,
          (st, newp))

    # chat: participantes falam; terceiro é bloqueado
    owner = ""
    for e in ests.get("establishments", []):
        if e.get("id") == "est_mercado":
            owner = e.get("owner_user_id", "")
    st, conv = req("POST", "/api/conversations", {"other_user_id": owner},
                   token=cust_token)
    check(16, "conversa cliente↔parceiro criada (201)",
          st == 201 and conv.get("conversation", {}).get("id"), (st, conv))
    cid = conv.get("conversation", {}).get("id", "")
    st, msg = req("POST", "/api/conversations/%s/messages" % cid,
                  {"body": "O pedido já saiu?"}, token=cust_token)
    check(16, "mensagem enviada (201)", st == 201, (st, msg))
    st, msgs = req("GET", "/api/conversations/%s/messages" % cid,
                   token=cust_token)
    check(16, "mensagens listadas", st == 200 and
          len(msgs.get("messages", [])) >= 1, (st, msgs))
    st, third = req("GET", "/api/conversations/%s/messages" % cid,
                    token=courier)
    check(16, "terceiro bloqueado na conversa (403)", st == 403,
          (st, third))
    st, third2 = req("POST", "/api/conversations/%s/messages" % cid,
                     {"body": "Intruso"}, token=courier)
    check(16, "terceiro não escreve na conversa (403)", st == 403,
          (st, third2))

    st, call = req("POST", "/api/call-logs",
                   {"callee_id": owner, "type": "voice",
                    "status": "answered"}, token=cust_token)
    check(16, "registo de chamada (201)", st == 201 and
          call.get("call_log", {}).get("id"), (st, call))

    st, av = req("POST", "/api/auth/avatar",
                 {"mime_type": "image/png", "data_base64": TINY_PNG},
                 token=cust_token)
    check(16, "avatar carregado (201)", st == 201 and
          av.get("image_url"), (st, av))
    st, me2 = req("GET", "/api/auth/me", token=cust_token)
    check(16, "avatar devolvido em /api/auth/me",
          st == 200 and (me2.get("user") or {}).get("avatar_url"),
          (st, me2))

    # sessões: logout invalida o token
    st, lo = req("POST", "/api/auth/logout", {}, token=cust_token)
    check(16, "logout (200)", st == 200, (st, lo))
    st, _ = req("GET", "/api/auth/me", token=cust_token)
    check(16, "token do logout invalidado (401)", st == 401, st)

    # recuperação de palavra-passe rota a sessões antigas
    st, rec = req("POST", "/api/auth/recover",
                  {"identifier": "845300001", "code": recovery_code,
                   "password": "Nova@12345"})
    check(16, "recuperação com código devolve nova sessão (200)",
          st == 200 and rec.get("token"), (st, rec))
    st, oldpw = req("POST", "/api/auth/login",
                    {"identifier": "845300001", "password": "Smoke@1234"})
    check(16, "palavra-passe antiga deixa de valer", st == 401, (st, oldpw))
    st, newpw = req("POST", "/api/auth/login",
                    {"identifier": "845300001", "password": "Nova@12345"})
    check(16, "nova palavra-passe funciona", st == 200, (st, newpw))

    # 404 em JSON (nunca texto puro)
    st, nf = req("GET", "/api/rota-inexistente")
    check(16, "rota inexistente devolve 404 JSON route_not_found",
          st == 404 and err_code(nf) == "route_not_found", (st, nf))

    # rate limit de login (por IP) — por último, bloqueia logins seguintes
    statuses = []
    for _ in range(12):
        st, _ = req("POST", "/api/auth/login",
                    {"identifier": "845300001", "password": "Errada@999"})
        statuses.append(st)
    check(16, "força-bruta de login recebe 429 rate_limited",
          429 in statuses, statuses)
    st, _ = req("POST", "/api/auth/login",
                {"identifier": "845300001", "password": "Nova@12345"})
    check(16, "mesmo com palavra-passe certa o limite mantém-se (429)",
          st == 429, st)


if __name__ == "__main__":
    main()
    total = len(checks)
    failed = [c for c in checks if not c[2]]
    print()
    print("RESULTADO: %d OK / %d FAIL (de %d verificações)"
          % (total - len(failed), len(failed), total))
    by_teste = {}
    for t, _, ok, _ in checks:
        by_teste.setdefault(t, []).append(ok)
    for t in sorted(by_teste):
        oks = by_teste[t]
        print("  TESTE %2d: %s (%d/%d)"
              % (t, "OK" if all(oks) else "FALHA", sum(oks), len(oks)))
    sys.exit(1 if failed else 0)
