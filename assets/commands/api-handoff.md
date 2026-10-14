---
description: schematize-api — gera o handoff (context.md + checklist.md) no archive, sem compactar.
---
Gere o handoff em `<projeto>/<projeto>_archive/context/`: `AAAA-MM-DD-<slug>-context.md` (o que foi
feito, decisões de contrato, o que o gate acusou, breaking pendente de ADR) e
`AAAA-MM-DD-<slug>-checklist.md` (FEITO vs ABERTO, nas três classes da casa: `- [ ]` máquina ·
`- [H ]` humano · `- [~]` on-hold). Não compacte — só grave. Nunca grave segredo de webhook, token
nem chave de idempotência real no handoff.
