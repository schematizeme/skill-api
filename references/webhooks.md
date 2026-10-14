# Webhooks — emitir e receber sem duplicar nem falsificar

Webhook é um **efeito externo** que sai do seu sistema para um endpoint que você não controla (ou
entra de um sistema que você não controla). Os dois lados têm pisos.

> Convenção de assinatura adotada como base: **Standard Webhooks** (comunitária, não IETF; versão em
> `references/stack-versoes.md`). RFC 9421 (HTTP Message Signatures) é a alternativa padronizada.

## 1. Emitir

1. **Envelope e headers** em toda entrega:
   - `webhook-id`: id estável da **entrega lógica** (o mesmo em todo retry);
   - `webhook-timestamp`: segundos desde a época, no momento do envio de **cada tentativa**;
   - `webhook-signature`: `v1,<base64(HMAC-SHA256(segredo, "<id>.<timestamp>.<corpo-cru>"))>`; aceite
     várias assinaturas separadas por espaço (rotação de segredo sem janela de quebra).
2. **Segredo por endpoint** (não global), aleatório, ≥ 32 bytes, guardado no cofre
   (`schematize-infra → references/segredos.md`); o cliente o vê **uma vez** e há rotação com
   sobreposição.
3. **Corpo mínimo e versionado**: `{ "tipo": "pedido.pago", "versao": "1", "id": "...", "criadoEm": "...",
   "dados": {...} }`. Evento "gordo" vaza dado; evento "fino" (id + tipo) obriga o receptor a buscar na
   API, o que reduz vazamento e problema de ordem. Escolha e documente.
4. **Semântica at-least-once**: nunca prometa exactly-once. Ordem **não** é garantida; o evento traz
   `criadoEm`/versão do recurso para o receptor descartar o obsoleto.
5. **Retry**: backoff exponencial com jitter (ex.: 5 s, 30 s, 2 min, 10 min, 1 h, 6 h), teto de
   tentativas (ex.: 24 h), depois **DLQ** visível ao dono do endpoint com **reenvio manual**. Sucesso é
   `2xx` em até N s (ex.: 10 s); resto é falha. `410 Gone` desativa o endpoint; endpoint que falha
   por dias é suspenso com aviso (não bombardeie).
6. **Outbox**: grave o evento na mesma transação do fato de negócio e entregue de um worker
   (`schematize-engineering → references/dados-eventos.md`). Disparar webhook dentro do handler perde
   evento em crash e dispara evento de transação que deu rollback.
7. **SSRF**: o endpoint do cliente é URL fornecida por terceiro. Valide `https`, resolva DNS e **bloqueie
   IP privado/loopback/link-local/metadata** (e revalide no connect, contra DNS rebinding), sem seguir
   redirect, com timeout curto e tamanho de resposta limitado. Teste ofensivo: `schematize-pentest`.
8. **Fora de produção, webhook de saída vai para sink** (rota nula), nunca para o endpoint real do
   cliente (`schematize-engineering → references/efeitos-externos.md`).
9. **Observabilidade**: log de cada tentativa (id, status, latência, tentativa nº), métrica de taxa de
   sucesso e idade da fila (`schematize-observability`), sem logar corpo com dado pessoal.

## 2. Receber

Ordem obrigatória no handler:

1. **Leia o corpo CRU** (bytes) — a assinatura é sobre os bytes; parsear e reserializar quebra.
2. **Verifique o timestamp**: rejeite se `|agora - timestamp| > janela` (5 min). Isso mata *replay*.
3. **Recompute o HMAC** com o segredo e compare com **comparação em tempo constante** (nunca `==`);
   assinatura inválida: `401`/`400` sem detalhe.
4. **Deduplique por `webhook-id`** (tabela com `UNIQUE`, TTL > janela de retry): já visto ⇒ `2xx` sem
   reprocessar.
5. **Responda `2xx` rápido e processe depois** (enfileire). Handler lento causa retry e duplicata.
6. **Trate ordem**: compare versão/`criadoEm` do evento com o estado local; descarte o obsoleto.
7. **Nunca confie no payload para autorizar**: o webhook é uma *dica*; para decisão sensível (liberar
   produto, marcar pago) confirme o estado na API do emissor.

Esqueleto de verificação (bash + openssl, para teste e depuração; produção usa a lib da linguagem):

```bash
# esperado = base64( HMAC-SHA256( segredo, "<id>.<timestamp>.<corpo>" ) )
printf '%s.%s.%s' "$ID" "$TS" "$CORPO" \
  | openssl dgst -sha256 -hmac "$SEGREDO" -binary | base64
```

## 3. No contrato OpenAPI

Declare em `webhooks:` (OpenAPI 3.1+) a operação com os três headers acima e o schema do evento. O gate
`check-api.sh` reprova `webhook-sem-assinatura` e avisa `webhook-sem-id-ou-timestamp`. Webhook de
pagamento: o específico do PSP (conciliação, estados do pagamento) é da `schematize-payments` (`schematize-payments → references/webhooks-idempotencia.md`); o genérico é daqui.

## 4. Anti-padrões

- Segredo único para todos os clientes; segredo no corpo ou na URL (`?token=`).
- Verificar assinatura sobre o JSON reserializado.
- Comparar HMAC com `==`.
- Sem janela de timestamp (replay eterno) ou janela de horas.
- Handler que processa síncrono antes de responder.
- Retry sem teto e sem jitter (tempestade de retry derruba o receptor).
- Webhook de teste batendo em endpoint de cliente real.

Assinatura específica de plataforma de chat (Discord, Telegram, Slack, WhatsApp): `schematize-bots → references/transporte-e-assinatura.md`; aqui só o piso genérico.
