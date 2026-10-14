# schematize-api — contrato de API

> **O contrato é o produto; quebrá-lo é cobrar de quem você não vê.** REST em OpenAPI 3.1+
> contract-first, gRPC/protobuf com `buf`, webhooks assinados, `Idempotency-Key`, erros RFC 9457,
> paginação por cursor, versionamento e deprecação com `Sunset`, rate limit e ETag.

Pacote de **skill normativa para [Claude Code](https://claude.com/claude-code)**.
Parte do catálogo **schematize skills**.

## Por que ela existe

A `schematize-docs` publica a documentação de API; a `schematize-iam` cuida da identidade. Faltava a
dona do **conteúdo do contrato**: o que cada endpoint promete sobre retry, erro, página, evento,
mudança e desligamento. Esses itens são visíveis na spec antes de existir cliente, e depois de
publicados viram dívida de compatibilidade.

## Instalar

### Pelo app schematize (recomendado)

```bash
schematize install api    # requer o CLI schematize instalado
```

### Manual

```bash
git clone https://github.com/schematizeme/skill-api.git /tmp/skill-api
bash /tmp/skill-api/install.sh "$HOME"      # global
bash /tmp/skill-api/install.sh              # só no projeto atual
```

## O que vem no pacote

- **SKILL.md** — pisos inegociáveis, fronteiras com as outras skills e mapa de references.
- **references/** — `contrato-rest`, `erros`, `idempotencia`, `webhooks`, `paginacao-filtros`,
  `versionamento-deprecacao`, `limites-concorrencia`, `grpc-protobuf` e `stack-versoes` (anexo volátil
  com data e fonte).
- **scripts/** — `check-api.sh`, o gate estático (precisa só de `python3`; usa `oasdiff` e `buf` se
  instalados e **avisa** quando faltam), com `check-api.test.sh` (vermelho e verde plantados).
- **assets/** — comandos `/api-*`, `CLAUDE.md` sempre-on, contrato de exemplo que passa no gate e
  workflow de CI pinado por SHA.

## Comandos

`/api-help` · `/api-load` · `/api-review` · `/api-design` · `/api-webhook` · `/api-breaking` ·
`/api-claude` · `/api-cc` · `/api-handoff`

## Gate

```bash
bash scripts/check-api.sh .                              # 0 passa · 1 reprova · 2 nada para verificar
API_BASE=openapi.main.yaml bash scripts/check-api.sh .   # + oasdiff breaking
API_PROTO_AGAINST='.git#branch=main' bash scripts/check-api.sh .   # + buf breaking
```

## Licença

MIT. Veja `LICENSE`.
