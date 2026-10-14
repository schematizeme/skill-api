---
description: schematize-api — revisa spec OpenAPI/.proto contra o piso: roda o gate e depois lê o que a máquina não lê.
argument-hint: "[caminho da spec ou do repo]"
---

# /api-review — o contrato é a promessa; revisor lê como cliente

Alvo: `${ARGUMENTS:-.}`.

1. **Gate primeiro:** `bash .claude/skills/schematize-api/scripts/check-api.sh ${ARGUMENTS:-.}` — `1`
   reprova (corrija antes de seguir), `2` é "nada verificado" (não é aprovação: ache a spec).
   Se houver spec antiga (branch alvo), rode com `API_BASE=<spec antiga>`; com `.proto`, `API_PROTO_AGAINST=<ref>`.
2. **Avisos de ferramenta ausente** (`oasdiff`, `buf`) entram no relatório como **não verificado**.
3. **Leia como cliente**, o que o gate não lê:
   - o `type` de cada problema é estável, documentado e distinto por causa? `detail` vaza interno?
   - cada POST que dispara efeito externo tem idempotência real (reserva atômica, escopo por principal)?
   - os schemas de entrada têm teto em todo campo? dinheiro é inteiro? enum de resposta é aberto?
   - o cursor é opaco, a ordem é total e há índice para ela?
   - cada operação tem **escopo mínimo** no `security`, coerente com o que o handler exige? (a prova de
     BOLA é da `schematize-pentest`; aqui só se confere o que o contrato promete.)
   - a mudança é breaking? sem ADR e data, bloqueie (`/api-breaking`).
   - webhook: assinatura, janela, id, retry e DLQ descritos (`/api-webhook`)?
4. **Entregue** achados por severidade (bloqueia / corrige antes de publicar / sugestão), cada um com
   arquivo:local e a correção proposta. Nada de "parece ok" sem ter rodado o gate.
