---
description: schematize-api — desenha ou revisa webhook emitido ou recebido (assinatura, replay, retry, dedupe, SSRF).
argument-hint: "<emitir|receber> <evento ou provedor>"
---

# /api-webhook — efeito externo com contrato

Alvo: `${ARGUMENTS}`. Carregue `references/webhooks.md`. Webhook é efeito externo nos dois sentidos.

**Se EMITIR:**
1. Evento: tipo, `versao`, `id`, `criadoEm`, `dados` (gordo ou fino, decidido e documentado).
2. Headers `webhook-id`, `webhook-timestamp`, `webhook-signature` (HMAC-SHA256 sobre
   `id.timestamp.corpo`), segredo **por endpoint**, rotação com sobreposição.
3. Outbox na mesma transação do fato; worker entrega; retry com backoff e jitter, teto, **DLQ** com
   reenvio manual; `410` desativa.
4. **SSRF**: https, DNS resolvido e revalidado, IP privado/loopback/link-local/metadata bloqueado, sem
   redirect, timeout e tamanho limitados.
5. **Fora de prd vai para sink** (rota nula), nunca para endpoint real de cliente.

**Se RECEBER:**
1. Corpo **cru** → timestamp dentro da janela (5 min) → HMAC com comparação em tempo constante →
   dedupe por `webhook-id` (UNIQUE + TTL) → `2xx` rápido e processamento assíncrono.
2. Trate ordem (versão do recurso) e **não autorize pelo payload**: confirme o estado na API do emissor.

Declare o webhook em `webhooks:` da OpenAPI e rode
`bash .claude/skills/schematize-api/scripts/check-api.sh .` até verde. Entregue com o teste que prova:
(a) assinatura inválida é rejeitada, (b) replay fora da janela é rejeitado, (c) mesmo `webhook-id` duas
vezes produz **um** efeito.

Webhook de bot de chat (Discord, Telegram, Slack, WhatsApp): assinatura e prazo próprios em `schematize-bots → references/transporte-e-assinatura.md`.
