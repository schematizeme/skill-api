---
description: schematize-api — classifica uma mudança de contrato, roda o diff de compatibilidade e monta o plano de deprecação com data.
argument-hint: "[spec ou .proto alterado]"
---

# /api-breaking — quebrar é cobrar de quem você não vê

Alvo: `${ARGUMENTS:-spec do diff atual}`. Carregue `references/versionamento-deprecacao.md`.

1. **Spec base**: obtenha a versão publicada (`git show <branch-alvo>:<caminho>` para um arquivo
   temporário). Nunca compare contra uma cópia sua.
2. **Diff por máquina:** `API_BASE=<base> bash .claude/skills/schematize-api/scripts/check-api.sh .`
   (usa `oasdiff breaking`). Para `.proto`: `API_PROTO_AGAINST='.git#branch=main'` (usa `buf breaking`).
   Ferramenta ausente é **não verificado**: diga isso, não aprove.
3. **Classifique** cada diferença (tabela da reference): breaking / aditiva / depende. Enum de resposta
   e campo obrigatório novo contam como breaking.
4. **Se breaking**: pare e proponha a rota sem quebra primeiro (expand/contract: emitir os dois,
   migrar, deprecar, remover). Se for inevitável: ADR (`/docs-adr`) com motivo, impacto, janela e rota
   de migração.
5. **Plano de deprecação** com data: `deprecated: true`, `Deprecation`, `Sunset`, `Link rel="deprecation"`,
   métrica de uso por cliente, comunicação (changelog, e-mail, status page), `410 Gone` na data.
6. **Registre** no `CHANGELOG` da API (`/docs-api`) com o breaking em destaque, escrito para o consumidor.
