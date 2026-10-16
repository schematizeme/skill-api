---
description: schematize-api — context compact: grava o handoff no archive e roda /compact.
---
Antes de compactar, **grave o handoff** em `<projeto>/<projeto>_archive/context/` no par
**context + checklist** do padrão da `schematize-archive` (prefixo `AAAA-MM-DD-<slug>-`), FEITO vs
ABERTO. Inclua: o que foi desenhado ou revisado, os achados do `scripts/check-api.sh` que ficaram
abertos, as quebras de compatibilidade aguardando ADR e as exceções (`x-api-ok`) declaradas, com o
motivo. Nunca inclua segredo de webhook nem token. Só então rode `/compact`.
