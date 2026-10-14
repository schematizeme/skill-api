---
description: Mapa da skill schematize-api (contrato de API — REST/OpenAPI, gRPC/protobuf, webhooks, idempotência, erros, versionamento).
---
**schematize-api** — o contrato é o produto; quebrá-lo é cobrar de quem você não vê.

| Comando | O que faz |
|---|---|
| `/api-help` | esta lista |
| `/api-load` | carrega à força TODO o corpo normativo (REST, erros, idempotência, webhooks, paginação, versionamento, limites, gRPC) e passa a aplicá-lo |
| `/api-review` | revisa spec/proto: roda `scripts/check-api.sh` e lê o que a máquina não lê |
| `/api-design` | desenha recurso ou operação nova, contract-first, antes do handler |
| `/api-webhook` | desenha ou revisa webhook emitido ou recebido (assinatura, replay, retry, dedupe) |
| `/api-breaking` | classifica a mudança, roda o diff de compatibilidade e monta o plano de deprecação com data |
| `/api-claude` | cria ou mescla o `CLAUDE.md` sempre-on de contrato de API na raiz do repo |
| `/api-cc` · `/api-handoff` | context compact / handoff no archive |

Pareia com: `schematize-docs` (publicar OpenAPI, SemVer, ADR), `schematize-iam` (authn/authz),
`schematize-engineering` (arquitetura, outbox, efeito externo), `schematize-database` (índice do cursor),
`schematize-qa` (teste de contrato), `schematize-pentest` (BOLA, SSRF, replay).
