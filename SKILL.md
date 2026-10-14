---
name: schematize-api
metadata:
  version: 0.1.0
description: >-
  Contrato de API: OpenAPI 3.1 contract-first, gRPC/protobuf, webhooks assinados, Idempotency-Key, RFC 9457, Sunset. Use ao desenhar ou revisar spec, *.proto ou webhook. Gate check-api.sh.
---
<!-- cross-skill: iam.md, dados-eventos.md, efeitos-externos.md -> schematize-engineering; api-versionamento.md, adr.md -> schematize-docs -->

# Contrato de API (schematize-api)

Disciplina normativa para **o contrato entre sistemas**: REST descrito em OpenAPI, gRPC descrito em
protobuf e webhooks. A tese: **o contrato é o produto, e quebrá-lo é cobrar de quem você não vê**.
Quem publica endpoint sem idempotência cobra duas vezes; sem formato de erro, obriga o cliente a
parsear texto; com paginação por offset, entrega duplicata e lentidão; deprecando sem data, nunca
consegue desligar nada. Tudo isso já foi incidente em algum lugar, e todo item é visível **na spec**,
antes de existir cliente.

**Versão:** skill `schematize-api` v0.1.0. Changelog em `CHANGELOG.md`.

## Precedência e herança (leia antes de divergir)

<!-- herdado:engineering/precedencia:dominio intro="Esta skill é o recorte **contrato de API (OpenAPI, protobuf, webhooks)** da base: independe de linguagem e vale para todo serviço do rol (`schematize-engineering` → `references/linguagens.md`), porque o contrato é o que atravessa a fronteira entre linguagens." cmd="api" -->Esta skill é o recorte **contrato de API (OpenAPI, protobuf, webhooks)** da base: independe de linguagem e vale para todo serviço do rol (`schematize-engineering` → `references/linguagens.md`), porque o contrato é o que atravessa a fronteira entre linguagens.

1. **Onde esta skill divergir da base, a BASE MANDA.** Aqui mora a especialização do domínio ou da
   ferramenta — o como, o padrão, o gate. Divergência de *piso* é defeito desta skill, não variante local.
2. **O que não está repetido aqui é HERDADO, não dispensado.** Esta skill herda os pisos da base e
   os comandos dela cobrem o **domínio**, não o piso geral. Valem integralmente, sem cópia local:
   - **§28 Archive** — `<projeto>/<projeto>_archive/` é **repositório git próprio, PRIVADO e
     obrigatório**, criticidade 0 (`schematize-archive`).
   - **§35 Definition of Done** e a lista de anti-padrões (citada por **título**, nunca por número).
   - **§39 Índice/MAPA** — enumeração exaustiva (uma entrada por unidade chamável, `M == N`) e grafo
     com arestas em ASCII (`A -> B`), nunca a seta unicode.
   - **IAM** (`schematize-engineering` → `references/iam.md`): identidade ≠ email, ≥2 fatores, ReBAC
     multi-tenant, argon2id-only para senha nova, sessão longa e logout irreversível.
   - **Efeito externo** nunca sai de não-produção (`schematize-engineering` →
     `references/efeitos-externos.md`).
   - **Orquestração** (`schematize-engineering` → `references/orquestracao.md` §9): o principal não
     desenvolve (é Claude Opus); executor mais barato que resolve — `haiku`/`sonnet` → Codex Terra → Cursor → `opus` só após falha; visual direto ao Codex; imagem nunca pelo Claude: detecta Codex/Gemini e pergunta ao usuário qual usar (Codex é a sugestão, não automática), nunca API paga.
3. **QA, ops, IAM e índice não têm comando próprio aqui:** vêm da base `/eng-*`. Para trabalho
   contínuo use `/eng-overdev`; para planejar `/eng-plan`; para varrer a base `/eng-scan`; para
   revisão geral `/eng-review` (e `/eng-ops`, `/eng-iam`, `/eng-index`). Os comandos
   `/api-*` cobrem o domínio desta skill; o piso geral é o da base.<!-- /herdado -->

## Fronteira com as outras skills

| Assunto | Dono | Ponteiro |
|---|---|---|
| **Conteúdo do contrato**: operações, schemas, erros, idempotência, paginação, webhooks, versionamento, deprecação, limites, ETag | **esta skill** | `references/*.md` abaixo |
| **Publicar** a OpenAPI (Redoc/Scalar), SemVer da superfície, changelog, drift spec x código, ADR de breaking | `schematize-docs` | `schematize-docs → references/api-versionamento.md` (`/docs-api`) |
| **Como** autenticar e autorizar: broker `auth.<domínio>`, OIDC/PKCE, passkeys, ReBAC, sessão | `schematize-iam` | aqui só se **declara** `securitySchemes` e escopos por operação; piso base: `schematize-engineering → references/iam.md` |
| Arquitetura do serviço, DDD, outbox, eventos e contratos de dado | `schematize-engineering` | `schematize-engineering → references/dados-eventos.md`, `arquitetura.md` |
| Webhook/efeito externo fora de prd (sink, rota nula) | `schematize-engineering` | `schematize-engineering → references/efeitos-externos.md` |
| Pagamentos (PSP, estados, conciliação) | `schematize-payments` | pagamento: webhook de PSP (assinatura do PSP, estados, idempotência de cobrança) é de lá; o webhook **genérico** é daqui |
| Esquema de banco, índice do cursor, expand-contract | `schematize-database` | ordem total do cursor exige índice |
| Pipeline/CDC/contrato de dado em movimento | `schematize-data` | contrato de **evento** de dado é de lá; de **API** é daqui |
| Teste de contrato, flaky, gate de CI | `schematize-qa` | disciplina geral; aqui as regras do contrato |
| Ataque a BOLA/IDOR, SSRF no webhook, abuso de limite | `schematize-pentest` | lado ofensivo; aqui o construtivo |
| Tráfego, tracing, SLO de endpoint | `schematize-observability` | `trace_id` no erro liga os dois |
| Rate limit no gateway, rede/TLS, segredo do HMAC | `schematize-infra` | `schematize-infra → references/segredos.md` |

## Comandos (Claude Code)

| Comando | O que faz |
|---|---|
| `/api-help` | lista os comandos |
| `/api-load` | carrega à força o corpo normativo (REST, erros, idempotência, webhooks, paginação, versionamento, limites, gRPC) |
| `/api-review` | revisa spec/proto: roda o gate e lê o que a máquina não lê |
| `/api-design` | desenha um recurso ou operação nova, contract-first, antes de qualquer handler |
| `/api-webhook` | desenha ou revisa webhook emitido ou recebido (assinatura, replay, retry, dedupe) |
| `/api-breaking` | classifica uma mudança, roda o diff de compatibilidade e monta o plano de deprecação com data |
| `/api-claude` | cria/mescla o `CLAUDE.md` sempre-on de contrato de API na raiz do repo |
| `/api-cc` · `/api-handoff` | context compact / handoff arquivado |

## Como usar

1. **Rode o gate antes de discutir estilo:** `bash scripts/check-api.sh .` — `0` passa · `1`
   reprova · `2` **nada para verificar** (que não é aprovação). Funciona só com `python3`; usa
   `oasdiff` e `buf` quando instalados (e **avisa** quando faltam, nunca verde por omissão).
2. **Desenhe pelo contrato** (`references/contrato-rest.md`): spec primeiro, handler depois.
3. **Erro e idempotência** (`references/erros.md`, `references/idempotencia.md`) antes do primeiro
   endpoint que escreve.
4. **Webhooks** (`references/webhooks.md`) tratados como efeito externo, dos dois lados.
5. **Coleções** (`references/paginacao-filtros.md`) com cursor desde o dia 0: trocar depois é breaking.
6. **Evolução** (`references/versionamento-deprecacao.md`) e **limites/concorrência**
   (`references/limites-concorrencia.md`) fecham o ciclo de vida.
7. **gRPC** (`references/grpc-protobuf.md`) segue o mesmo princípio com `buf`.

Mapa de references:

| Tarefa | Reference |
|---|---|
| Contract-first, operações e status, segurança declarada, TLS, lint | `references/contrato-rest.md` |
| `application/problem+json`, `type` estável, status que contam, validação | `references/erros.md` |
| `Idempotency-Key`, escopo, replay, reserva atômica, retry seguro | `references/idempotencia.md` |
| Emitir e receber webhook: HMAC, janela de replay, retry, DLQ, SSRF, dedupe, sink fora de prd | `references/webhooks.md` |
| Cursor opaco, ordem total, limite máximo, filtro e ordenação | `references/paginacao-filtros.md` |
| O que é breaking, versão, `oasdiff`/`buf breaking`, `Deprecation`/`Sunset` | `references/versionamento-deprecacao.md` |
| `429`/`Retry-After`/RateLimit (draft), ETag, `If-Match`, 412/428 | `references/limites-concorrencia.md` |
| protobuf: package versionado, enum UNSPECIFIED, `reserved`, deadline, `buf` | `references/grpc-protobuf.md` |
| Versões, drafts IETF e ferramentas com data (anexo volátil) | `references/stack-versoes.md` |

Assets prontos: `assets/exemplos/openapi-minimo.yaml` (contrato que passa no gate, com cursor, idempotência,
ETag, problem+json e webhook assinado) · `assets/ci/github-actions-api.yml` (gate no PR, actions pinadas por SHA).

## Pisos inegociáveis (vetam o atalho)

1. **Contract-first.** A spec (OpenAPI 3.1+ ou `.proto`) é a fonte; handler e cliente são gerados ou
   validados contra ela, com drift travando o CI. Nunca spec e código à mão, em paralelo.
2. **Segurança declarada em toda operação.** `components.securitySchemes` presente e cada operação
   coberta (global ou própria); pública de propósito é `security: []` explícito. TLS sempre; token
   nunca em query string.
3. **Erro é `application/problem+json` (RFC 9457)** com `type` estável, em toda resposta 4xx/5xx/`default`.
   Nunca `200` com erro no corpo; nunca stack trace, SQL ou dado alheio em `detail`.
4. **POST que cria ou dispara efeito exige `Idempotency-Key`**, escopada ao principal, com replay da
   mesma resposta e 422/409 para reuso indevido. Efeito externo nunca é isentado.
5. **Coleção pagina por cursor opaco**, com ordem total estável e `limite` com máximo. Offset só com
   motivo escrito.
6. **Webhook assinado e com janela de replay.** Emissão: HMAC por endpoint, `id` e `timestamp`, retry com
   backoff e jitter, DLQ, outbox, anti-SSRF. Recepção: corpo cru, timestamp, HMAC em tempo constante,
   dedupe por `id`, `2xx` rápido. Entrega é *at-least-once*; nunca prometa exactly-once.
7. **Breaking change nunca entra sem ADR e plano com data.** O diff de compatibilidade (`oasdiff`,
   `buf breaking`) roda no CI do PR contra a branch alvo.
8. **Deprecar é dar data:** `deprecated: true` + `Deprecation` + `Sunset` + link de migração, uso medido
   por cliente, `410 Gone` na data.
9. **Escrita concorrente usa `If-Match`/ETag** (`412`/`428`), não "o último ganha".
10. **Limite de taxa responde `429` com `Retry-After`**; cabeçalhos `RateLimit*` seguem o draft IETF
    **pinado por revisão** (ainda não é RFC).
11. **Todo campo de entrada tem teto** (`maxLength`, `maximum`, `maxItems`); dinheiro é inteiro de menor
    unidade + moeda, nunca `float`.
12. **Efeito externo nunca sai de não-produção:** webhook de saída fora de prd vai para sink
    (`schematize-engineering → references/efeitos-externos.md`).
13. **Fatos voláteis** (versão do OpenAPI, status de draft IETF, versão de ferramenta) moram só em
    `references/stack-versoes.md`, com data.
14. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

## Regra de mídia

Diagrama de sequência ou de arquitetura da API vai em Mermaid ou texto no repo. Imagem ou mídia gerada
**nunca** por modelo Claude: detecte Codex e Gemini disponíveis e **pergunte ao usuário qual usar**.
Nenhum disponível: avise sem rodeio que visual gerado pelo Claude tem qualidade inversamente
proporcional à de código (sai ruim de verdade) e ofereça alternativas — instalar Codex ou Gemini, imagem
de banco com licença comercial, ou asset do cliente. Claude é o melhor em código.

## Relação com as outras skills

- **`schematize-docs`** publica o que esta skill define: referência da API, changelog, SemVer, ADR de
  breaking e runbook de rotação de segredo de webhook.
- **`schematize-iam`** é dona da identidade e da autorização que o contrato apenas declara.
- **`schematize-engineering`** é a base: arquitetura, outbox, efeito externo, DoD e archive.
- **`schematize-database`** sustenta o cursor (índice composto) e a chave de idempotência (UNIQUE).
- **`schematize-qa`** transforma "duas requisições com a mesma chave produzem um efeito" em teste.
- **`schematize-pentest`** ataca o que aqui se constrói: BOLA, SSRF, abuso de limite, replay.
- **`schematize-observability`** liga erro e trace por `trace_id` e mede SLO por endpoint.
