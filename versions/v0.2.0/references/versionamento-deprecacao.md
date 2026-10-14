# Versionamento, compatibilidade e deprecação

API publicada é promessa. O custo de quebrá-la é pago por gente que você não vê.

## 1. O que é breaking

| Mudança | Breaking? |
|---|---|
| remover/renomear endpoint, campo de resposta, valor de enum que o servidor emite | sim |
| tornar campo de requisição obrigatório; restringir tipo, formato ou tamanho | sim |
| mudar semântica (mesmo campo, outro significado), status ou ordem default | sim |
| adicionar campo opcional de requisição, campo de resposta, endpoint, valor de enum de entrada | não |
| adicionar valor a enum **de resposta** | sim para clientes que fazem `switch` exaustivo: documente "enums de resposta são abertos" desde o v1 |
| apertar rate limit, mudar prazo de retenção, mudar `operationId` | pode ser: avalie |

**Regra de Postel documentada**: servidor estrito no que aceita, cliente tolerante no que recebe
(ignora campo desconhecido, trata enum desconhecido como `desconhecido`). Sem essa cláusula no contrato,
qualquer adição é potencialmente breaking.

## 2. Como versionar

1. **Preferência: evoluir sem versão nova** (mudanças aditivas) por muito tempo. Versão nova é custo
   de manter duas.
2. Versão **maior no caminho** (`/v1/`) — visível, cacheável, roteável por gateway. Versão por header
   ou data (`Api-Version: 2026-10-14`, estilo Stripe) é válida se o gateway e os clientes a suportam;
   escolha uma e registre em ADR (`schematize-docs → references/adr.md`).
3. **SemVer da superfície** + changelog escrito para o consumidor: `schematize-docs →
   references/api-versionamento.md`.
4. **Breaking vira ADR + plano de migração com data** antes do merge. Sem ADR, o gate de breaking
   deve reprovar.

## 3. Detectar quebra por máquina

- **OpenAPI**: `oasdiff breaking <spec-base> <spec-nova> --fail-on ERR`. O `check-api.sh` roda isso
  quando você define `API_BASE=<spec antiga>` (ex.: a do `main`) e o `oasdiff` está instalado; sem o
  binário, **avisa** que a quebra não foi verificada (nunca verde por omissão).
- **Protobuf**: `buf breaking --against '.git#branch=main'` (regras `FILE` ou `WIRE_JSON`);
  `check-api.sh` roda com `API_PROTO_AGAINST`.
- No CI do PR: base = branch alvo. A spec antiga vem do git (`git show main:openapi.yaml`).
- **Consumer-driven contract tests** (Pact ou equivalente) quando há consumidor interno conhecido:
  pega o que o diff de spec não pega (uso de campo "não documentado").

## 4. Deprecação com data

Deprecar sem data é anunciar que vai quebrar algum dia, e todo mundo ignora.

1. Marque `deprecated: true` no contrato **e** emita headers na resposta:
   - `Deprecation: @1760400000` (RFC 9745, instante em que passou a estar depreciado, formato de data
     estruturada) ;
   - `Sunset: Wed, 14 Oct 2027 00:00:00 GMT` (RFC 8594, quando será desligado);
   - `Link: <https://docs.exemplo.org/migracao-v2>; rel="deprecation"` (e `rel="sunset"` se houver
     documento do desligamento).
2. **Janela mínima** declarada (ex.: 12 meses para API pública, 90 dias para interna), comunicada por
   e-mail/changelog/status page.
3. **Meça o uso** do endpoint deprecado por cliente (métrica por `client_id`); cobre quem ainda usa.
   Desligue só com uso ~0 **ou** na data, com aviso final. Na data, responda `410 Gone` com problem+json
   apontando a migração (não `404`).
4. O gate reprova `deprecada-sem-sunset`: `deprecated: true` sem `Sunset` documentado nas respostas.

## 5. Mudança perigosa em duas fases (expand/contract) na API

Renomear campo = (1) emitir os dois, aceitar os dois; (2) migrar clientes medindo uso; (3) deprecar o
antigo com data; (4) remover. É o mesmo expand-contract do banco (`schematize-database`).
