# Piso de contrato de API (schematize-api) — sempre-on

O contrato é o produto. Quebrá-lo é cobrar de quem você não vê.

1. **Contract-first.** OpenAPI 3.1+ ou `.proto` é a fonte; handler e cliente derivam dela, e drift
   spec x código trava o CI. Nunca os dois à mão.
2. **Segurança declarada** (`securitySchemes` + `security` em toda operação; pública é `security: []`
   explícito). TLS sempre; token nunca em query string. Como autenticar/autorizar é da `schematize-iam`.
3. **Erros em `application/problem+json` (RFC 9457)** com `type` estável. Nunca `200` com erro; nunca
   stack trace, SQL ou dado alheio em `detail`.
4. **POST com efeito exige `Idempotency-Key`** escopada ao principal, replay da mesma resposta, 422/409
   no reuso indevido. Efeito externo nunca é isentado.
5. **Coleção por cursor opaco**, ordem total, `limite` com máximo. Offset só com motivo escrito.
6. **Webhook**: HMAC por endpoint + `id` + `timestamp` + janela de replay; emissor com outbox, retry
   com jitter, DLQ e anti-SSRF; receptor com corpo cru, tempo constante, dedupe e `2xx` rápido.
   *At-least-once*, nunca exactly-once.
7. **Breaking sem ADR e plano com data não entra.** `oasdiff breaking` / `buf breaking` no PR.
8. **Deprecar = `deprecated` + `Deprecation` + `Sunset` + link de migração**; `410` na data.
9. **Escrita concorrente com `If-Match`/ETag** (412/428). **Limite de taxa** responde 429 com `Retry-After`.
10. **Teto em todo campo de entrada**; dinheiro em inteiro de menor unidade, nunca `float`.
11. Webhook/efeito externo nunca sai de não-produção (sink por padrão).
12. <!-- herdado:engineering/orquestracao:curto -->**Orquestrador não desenvolve; subagent barato executa.** O agent principal só planeja, despacha e revisa; ação onerosa vira micro-tasks para o executor mais barato que resolve: `haiku` (mecânico) / `sonnet` (código; falhou → mesmo subagent corrige, até 2 rodadas) → Codex `gpt-5.6-terra` → Cursor → subagent `opus` (motivo) → `park`; **visual vai direto ao Codex**; **imagem nunca pelo Claude: detectar Codex/Gemini e perguntar ao usuário qual usar (Codex é a sugestão), nunca API de imagem paga**; papéis em `agentes.toml`. No overdev, cada item do checklist vai a um subagent e o principal revisa antes do `- [x]`. **Sem frota ociosa:** idle com pendência volta ao trabalho; dependente de outro agent → mata e enfileira com gatilho; terminou → mata (§9.6). Detalhe: `schematize-engineering` → `references/orquestracao.md` §9.<!-- /herdado -->

Mídia: imagem/visual gerado nunca por modelo Claude; detecte Codex/Gemini e pergunte qual usar.

Gate: `bash .claude/skills/schematize-api/scripts/check-api.sh .` — waiver rastreável na operação:
`x-api-ok: ["<regra>: <motivo>"]`.
