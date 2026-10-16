# Changelog — schematize-api

Todas as mudanças relevantes deste pacote, no formato [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/),
com versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [0.3.0] — 2026-10-15
### Alterado
- Fronteira e relação ganham `schematize-regression` (regressão de contrato no CI); breaking change e
  deprecação continuam donos desta skill.
- Porquê: evitar dois lugares decidindo o que é quebra de contrato.

## [0.2.1] — 2026-10-14
Ponteiro para a skill nova `schematize-bots` (piso curto, sem duplicar).

### Alterado
- aponta bots de chat (assinatura de plataforma em /api-webhook e webhooks.md).

## [0.2.0] — 2026-10-14
Integração ao catálogo: orçamento de description e ponteiros entre as irmãs novas.

### Alterado
- `description` <=190 (orçamento do catálogo).
- Webhook de pagamento: o ponteiro genérico "skill de pagamentos do catálogo" passa a `schematize-payments → references/webhooks-idempotencia.md`.
- Motivo: o catálogo estourou o orçamento de listagem com 45 skills; cada fronteira aponta a dona em vez de duplicar.

## [0.1.0] — 2026-10-14
Primeira versão. O catálogo cobria **publicar** a documentação de API (`schematize-docs`) e a
**identidade** (`schematize-engineering`, depois a `schematize-iam`), mas nenhuma skill era dona do
**conteúdo do contrato**: idempotência, formato de erro, paginação, webhooks, deprecação com data,
concorrência otimista. Cada um desses já foi incidente (cobrança duplicada por retry, cliente
parseando mensagem de erro, listagem lenta e com duplicata por offset, endpoint "deprecado" que nunca
foi desligado, webhook forjável) e todos são visíveis na spec antes de existir cliente.

### Adicionado
- `SKILL.md` com 14 pisos inegociáveis e a tabela de fronteiras (docs, iam, engineering, database, data, qa, pentest, observability, infra).
- 8 references: `contrato-rest`, `erros` (RFC 9457), `idempotencia`, `webhooks` (emitir e receber, Standard Webhooks), `paginacao-filtros`, `versionamento-deprecacao` (`Deprecation`/`Sunset`), `limites-concorrencia` (RateLimit draft, ETag), `grpc-protobuf` (`buf`); anexo volátil `stack-versoes` com data e fonte (OpenAPI 3.2.1, drafts IETF de RateLimit e Idempotency-Key, buf, oasdiff, Spectral).
- `scripts/check-api.sh`: gate estático sobre OpenAPI 3.x (JSON/YAML) e `.proto`, só com `python3`. Regras: `sem-seguranca-declarada`, `operacao-sem-seguranca`, `servidor-sem-tls`, `sem-resposta-de-erro`, `erro-sem-problem-json`, `post-sem-idempotencia`, `paginacao-offset`, `lista-sem-cursor`, `429-sem-ratelimit`, `escrita-sem-concorrencia`, `deprecada-sem-sunset`, `webhook-sem-assinatura`, `webhook-sem-id-ou-timestamp`, `versao-openapi`, `operacao-sem-id`, `proto-pacote-sem-versao`, `proto-enum-sem-zero-unspecified`. Roda `oasdiff breaking` (com `API_BASE`) e `buf lint`/`buf breaking` (com `API_PROTO_AGAINST`) quando instalados; ausentes viram aviso explícito, nunca verde por omissão. Waiver rastreável `x-api-ok: ["<regra>: <motivo>"]`.
- `scripts/check-api.test.sh`: 31 casos (verdes e vermelhos plantados, JSON e YAML, waiver com e sem motivo, stubs de `oasdiff` e `buf`).
- Comandos: `/api-help`, `/api-load`, `/api-review`, `/api-design`, `/api-webhook`, `/api-breaking`, `/api-claude`, `/api-cc`, `/api-handoff`.
- Assets: `assets/exemplos/openapi-minimo.yaml` (passa no gate), `assets/ci/github-actions-api.yml` (actions pinadas por SHA), `assets/CLAUDE.md`.
