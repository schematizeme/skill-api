---
description: schematize-api — desenha um recurso ou operação nova, contract-first, antes de qualquer handler.
argument-hint: "<recurso ou operação, ex.: pedidos>"
---

# /api-design — a spec nasce antes do código

Alvo: `${ARGUMENTS}`. **Não escreva handler.** Entregue a spec e o que ela exige do servidor.

1. **Levante**: quem consome (interno, parceiro, público), operações e o ciclo de vida do recurso
   (estados e transições), volume e consistência exigida.
2. **Modele o recurso** (`references/contrato-rest.md`): caminho no plural, ids opacos, datas RFC 3339
   UTC, dinheiro em inteiro + moeda, teto em todo campo de entrada. Ação fora de CRUD vira sub-recurso;
   operação longa devolve `202` + recurso de status.
3. **Para cada operação** defina: `operationId`, `security` com escopo mínimo, respostas de sucesso, e as
   de erro em `application/problem+json` (`references/erros.md`) com os `type` próprios.
4. **Escritas**: `POST` com `Idempotency-Key`; `PUT`/`PATCH`/`DELETE` com `If-Match`/ETag
   (`references/idempotencia.md`, `references/limites-concorrencia.md`).
5. **Coleções**: cursor opaco, `limite` com máximo, filtros e ordenação em lista fechada, índice
   correspondente (`schematize-database`) (`references/paginacao-filtros.md`).
6. **Eventos**: se outro sistema precisa saber, declare em `webhooks:` (`/api-webhook`).
7. **Grave a spec** (OpenAPI 3.1+), rode `bash .claude/skills/schematize-api/scripts/check-api.sh .`
   até verde e liste ao final o que o servidor precisa implementar (reserva de chave, ETag, cursor).
   Decisão estrutural (versionamento por caminho ou header, estilo de erro) vira ADR (`/docs-adr`).
