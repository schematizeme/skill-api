---
description: schematize-api — carrega à força TODO o corpo normativo de contrato de API e passa a aplicá-lo nesta sessão.
---
Carregue **agora** o corpo normativo da skill `schematize-api`. A partir daqui, nesta sessão,
isto **não é opcional**.

1. **Leia na íntegra, sem trabalhar de memória.** Caminho:
   `.claude/skills/schematize-api/references/*.md` (projeto) ou
   `~/.claude/skills/schematize-api/references/*.md` (global):
   - `contrato-rest.md` — contract-first, operações e status, segurança declarada, TLS, lint.
   - `erros.md` — RFC 9457, `type` estável, status que contam, validação.
   - `idempotencia.md` — `Idempotency-Key`, escopo, replay, reserva atômica.
   - `webhooks.md` — emitir e receber: HMAC, janela de replay, retry, DLQ, SSRF, dedupe, sink fora de prd.
   - `paginacao-filtros.md` — cursor opaco, ordem total, limite máximo.
   - `versionamento-deprecacao.md` — o que é breaking, `oasdiff`/`buf breaking`, `Deprecation`/`Sunset`.
   - `limites-concorrencia.md` — `429`/`Retry-After`/RateLimit (draft), ETag e `If-Match`.
   - `grpc-protobuf.md` — package versionado, enum UNSPECIFIED, `reserved`, deadline, `buf`.
   - `stack-versoes.md` — anexo volátil: versões e status de drafts, com data.
2. **Rode o gate no repo atual** antes de opinar sobre estilo:
   `bash .claude/skills/schematize-api/scripts/check-api.sh .`
3. **Aplique daqui em diante** a toda spec, `.proto` ou webhook que você escrever ou tocar, e diga qual
   piso está aplicando quando ele mudar o que você ia fazer. **Nunca** publique breaking change sem ADR
   e plano com data.
