#!/usr/bin/env bash
# shellcheck disable=SC2001,SC2016  # sed de recuo em harness e agulhas YAML literais em aspas simples
# Vermelho primeiro do gate check-api.sh. Cada fixture é uma spec/proto mínima com UM defeito;
# o caso verde correspondente prova que a regra não dispara em contrato correto.
#
# EXCEÇÃO DECLARADA (piso da schematize-shell, strict mode): harness de teste roda `set -u` sem `-e`
# — precisa continuar depois de um caso vermelho para reportar todos, em vez de parar no primeiro.
set -u
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G="$AQUI/check-api.sh"
EX="$AQUI/../assets/exemplos/openapi-minimo.yaml"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT INT TERM
ok=0; fail=0
D=""; NOME=""

novo() { D="$TMP/$1"; mkdir -p "$D"; NOME="$1"; }
f() { mkdir -p "$(dirname "$D/$1")"; cat >"$D/$1"; }
# esperar <exit> <agulha>: roda o gate no caso atual e confere exit e trecho da saída.
esperar() {
  local esp="$1" agulha="$2" saida rc
  saida="$(bash "$G" "$D" 2>&1)"; rc=$?
  if [ "$rc" != "$esp" ]; then echo "  ✖ $NOME: exit $rc, esperado $esp"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  if [ -n "$agulha" ] && ! grep -qF -- "$agulha" <<<"$saida"; then echo "  ✖ $NOME: exit certo, saída sem \"$agulha\""; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $NOME"; ok=$((ok+1))
}
# nao_ter <agulha>: a saída NÃO pode conter a regra (verde específico).
nao_ter() {
  local saida
  saida="$(bash "$G" "$D" 2>&1)"
  if grep -qF -- "$1" <<<"$saida"; then echo "  ✖ $NOME: apareceu \"$1\" indevido"; sed 's/^/      /' <<<"$saida"; fail=$((fail+1)); return; fi
  echo "  ✔ $NOME"; ok=$((ok+1))
}

CAB='openapi: 3.1.0
info: {title: T, version: 1.0.0}
servers:
  - url: https://api.exemplo.org/v1
security:
  - k: []
components:
  securitySchemes:
    k: {type: apiKey, in: header, name: X-Key}
  schemas:
    P: {type: object}
  responses:
    E:
      description: erro
      content:
        application/problem+json:
          schema: {$ref: "#/components/schemas/P"}
paths:'
# spec <nome> : lê o corpo de `paths:` do stdin e monta o arquivo com cabeçalho válido.
spec() { novo "$1"; { printf '%s\n' "$CAB"; cat; } >"$D/openapi.yaml"; }

echo "== verdes =="
novo exemplo-da-casa; cp "$EX" "$D/openapi.yaml"; esperar 0 "0 erro(s), 0 aviso(s)"

spec get-simples-ok <<'FIX'
  /saude:
    get:
      operationId: saude
      responses:
        "200": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
esperar 0 "0 erro(s)"

spec post-com-idempotencia-por-ref <<'FIX'
  /x:
    post:
      operationId: x
      parameters:
        - $ref: "#/components/parameters/IdempotencyKey"
      responses:
        "201": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
nao_ter "post-sem-idempotencia"

spec seguranca-publica-explicita <<'FIX'
  /publico:
    get:
      operationId: publico
      security: []
      responses:
        "200": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
nao_ter "operacao-sem-seguranca"

spec waiver-com-motivo <<'FIX'
  /x:
    post:
      operationId: x
      x-api-ok: ["post-sem-idempotencia: PUT lógico por id natural, repetir é inócuo"]
      responses:
        "201": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
nao_ter "post-sem-idempotencia"

novo json-valido
cat >"$D/openapi.json" <<'FIX'
{"openapi":"3.1.0","info":{"title":"T","version":"1"},
 "components":{"securitySchemes":{"k":{"type":"apiKey","in":"header","name":"X"}},
  "schemas":{"P":{"type":"object"}}},
 "security":[{"k":[]}],
 "paths":{"/s":{"get":{"operationId":"s","responses":{"200":{"description":"ok"},
   "default":{"description":"e","content":{"application/problem+json":{"schema":{"$ref":"#/components/schemas/P"}}}}}}}}}
FIX
esperar 0 "0 erro(s)"

novo proto-bom
f api/v1/svc.proto <<'FIX'
syntax = "proto3";
package empresa.pedidos.v1;
enum Estado {
  ESTADO_UNSPECIFIED = 0;
  ESTADO_NOVO = 1;
}
FIX
nao_ter "proto-"

echo "== vermelhos =="
novo sem-security-schemes
cat >"$D/openapi.yaml" <<'FIX'
openapi: 3.1.0
info: {title: T, version: 1}
security:
  - k: []
paths:
  /a:
    get:
      operationId: a
      responses:
        "200": {description: ok}
FIX
esperar 1 "sem-seguranca-declarada"

spec operacao-sem-seguranca <<'FIX'
  /a:
    get:
      operationId: a
      security:
        - k: []
      responses:
        default: {$ref: "#/components/responses/E"}
FIX
# remove o `security` global para a operação ficar exposta por omissão
sed -i '/^security:/,/^  - k: \[\]/d' "$D/openapi.yaml"
sed -i 's/^      security:$/      xsec:/' "$D/openapi.yaml"
esperar 1 "operacao-sem-seguranca"

spec servidor-http <<'FIX'
  /a:
    get:
      operationId: a
      responses:
        default: {$ref: "#/components/responses/E"}
FIX
sed -i 's#https://api.exemplo.org/v1#http://api.exemplo.org/v1#' "$D/openapi.yaml"
esperar 1 "servidor-sem-tls"

spec erro-em-json-puro <<'FIX'
  /a:
    get:
      operationId: a
      responses:
        "200": {description: ok}
        "400":
          description: ruim
          content:
            application/json:
              schema: {type: object}
FIX
esperar 1 "erro-sem-problem-json"

spec sem-resposta-de-erro <<'FIX'
  /a:
    get:
      operationId: a
      responses:
        "200": {description: ok}
FIX
esperar 1 "sem-resposta-de-erro"

spec post-sem-idempotencia <<'FIX'
  /a:
    post:
      operationId: a
      responses:
        "201": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
esperar 1 "post-sem-idempotencia"

spec waiver-sem-motivo-nao-vale <<'FIX'
  /a:
    post:
      operationId: a
      x-api-ok: ["post-sem-idempotencia"]
      responses:
        "201": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
esperar 1 "post-sem-idempotencia"

spec paginacao-offset <<'FIX'
  /a:
    get:
      operationId: a
      parameters:
        - {name: offset, in: query, schema: {type: integer}}
        - {name: limit, in: query, schema: {type: integer}}
      responses:
        "200": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
esperar 1 "paginacao-offset"

spec lista-sem-cursor <<'FIX'
  /a:
    get:
      operationId: a
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema: {type: array, items: {type: string}}
        default: {$ref: "#/components/responses/E"}
FIX
esperar 0 "lista-sem-cursor"

spec rate-limit-sem-header <<'FIX'
  /a:
    get:
      operationId: a
      responses:
        "200": {description: ok}
        "429": {description: devagar, content: {application/problem+json: {schema: {type: object}}}}
FIX
esperar 0 "429-sem-ratelimit"

spec put-sem-if-match <<'FIX'
  /a/{id}:
    put:
      operationId: a
      parameters:
        - {name: id, in: path, required: true, schema: {type: string}}
      responses:
        "200": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
esperar 0 "escrita-sem-concorrencia"

spec deprecada-sem-sunset <<'FIX'
  /velha:
    get:
      operationId: velha
      deprecated: true
      responses:
        "200": {description: ok}
        default: {$ref: "#/components/responses/E"}
FIX
esperar 1 "deprecada-sem-sunset"

spec deprecada-com-sunset-ok <<'FIX'
  /velha:
    get:
      operationId: velha
      deprecated: true
      responses:
        "200":
          description: ok
          headers:
            Sunset: {schema: {type: string}}
            Deprecation: {schema: {type: string}}
        default: {$ref: "#/components/responses/E"}
FIX
nao_ter "deprecada-sem-sunset"

novo webhook-sem-assinatura
cp "$EX" "$D/openapi.yaml"
sed -i '/name: webhook-signature/,/schema: { type: string }/d' "$D/openapi.yaml"
esperar 1 "webhook-sem-assinatura"

novo webhook-sem-timestamp
cp "$EX" "$D/openapi.yaml"
sed -i 's/name: webhook-timestamp/name: x-hora/' "$D/openapi.yaml"
esperar 0 "webhook-sem-id-ou-timestamp"

novo versao-openapi-antiga
cp "$EX" "$D/openapi.yaml"; sed -i 's/^openapi: 3.1.0/openapi: 3.0.3/' "$D/openapi.yaml"
esperar 0 "versao-openapi"

novo spec-ilegivel
printf 'openapi: "3.1.0"\n{ json: quebrado\n' >"$D/openapi.yaml"
esperar 1 "spec-ilegivel"

novo proto-sem-versao
f svc.proto <<'FIX'
syntax = "proto3";
package empresa.pedidos;
FIX
esperar 0 "proto-pacote-sem-versao"

novo proto-enum-sem-zero
f api/v1/svc.proto <<'FIX'
syntax = "proto3";
package empresa.pedidos.v1;
enum Estado {
  ESTADO_NOVO = 0;
  ESTADO_PAGO = 1;
}
FIX
esperar 1 "proto-enum-sem-zero-unspecified"

novo nada-para-verificar
echo "so texto" >"$D/README.md"
esperar 2 "nada verificado"

echo "== ferramentas externas (stubs) =="
# oasdiff ausente com API_BASE => AVISO, nunca falso verde.
novo oasdiff-ausente; cp "$EX" "$D/openapi.yaml"; cp "$EX" "$D/antiga.yaml"
SEMFERR="$TMP/semferr"; mkdir -p "$SEMFERR"
for b in bash python3 mktemp awk grep head tr printf rm cat sed dirname env; do
  p="$(command -v "$b" 2>/dev/null)" && ln -sf "$p" "$SEMFERR/$b"
done
saida="$(PATH="$SEMFERR" API_BASE="$D/antiga.yaml" bash "$G" "$D/openapi.yaml" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && grep -qF "oasdiff ausente" <<<"$saida"; then echo "  ✔ oasdiff-ausente avisa"; ok=$((ok+1)); else echo "  ✖ oasdiff-ausente: rc=$rc"; echo "$saida"; fail=$((fail+1)); fi

# oasdiff presente que reporta quebra => ERRO (stub: exit 1).
STUB="$TMP/stub"; mkdir -p "$STUB"
printf '#!/bin/sh\necho "1 changes: 1 error"\nexit 1\n' >"$STUB/oasdiff"; chmod +x "$STUB/oasdiff"
saida="$(PATH="$STUB:$PATH" API_BASE="$D/antiga.yaml" bash "$G" "$D/openapi.yaml" 2>&1)"; rc=$?
if [ "$rc" = 1 ] && grep -qF "breaking-change" <<<"$saida"; then echo "  ✔ oasdiff-quebra reprova"; ok=$((ok+1)); else echo "  ✖ oasdiff-quebra: rc=$rc"; echo "$saida"; fail=$((fail+1)); fi
# oasdiff presente sem quebra => verde.
printf '#!/bin/sh\nexit 0\n' >"$STUB/oasdiff"
saida="$(PATH="$STUB:$PATH" API_BASE="$D/antiga.yaml" bash "$G" "$D/openapi.yaml" 2>&1)"; rc=$?
if [ "$rc" = 0 ]; then echo "  ✔ oasdiff-sem-quebra passa"; ok=$((ok+1)); else echo "  ✖ oasdiff-sem-quebra: rc=$rc"; echo "$saida"; fail=$((fail+1)); fi

# buf ausente com .proto => AVISO.
novo buf-ausente
f api/v1/svc.proto <<'FIX'
syntax = "proto3";
package empresa.pedidos.v1;
FIX
saida="$(PATH="$SEMFERR" bash "$G" "$D" 2>&1)"; rc=$?
if [ "$rc" = 0 ] && grep -qF "buf ausente" <<<"$saida"; then echo "  ✔ buf-ausente avisa"; ok=$((ok+1)); else echo "  ✖ buf-ausente: rc=$rc"; echo "$saida"; fail=$((fail+1)); fi

echo
echo "check-api.test: $ok ok, $fail falha(s)"
[ "$fail" = 0 ]
