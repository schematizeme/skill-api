# Idempotência — `Idempotency-Key`, retry seguro

Rede falha entre o commit do servidor e a resposta ao cliente. O cliente repete. Se o POST não é
idempotente, o cliente cobra duas vezes, cria dois pedidos, envia dois e-mails. Idempotência é o
que torna **retry** uma operação segura, e retry é inevitável.

> Status do padrão: o header `Idempotency-Key` é convenção de mercado; o draft do IETF **expirou**
> sem virar RFC (`references/stack-versoes.md`). Por isso o comportamento é **especificado no
> contrato da API**, não delegado a um padrão que não existe.

## 1. Quem precisa

| Método | Idempotente por natureza? | Ação |
|---|---|---|
| GET, HEAD, PUT, DELETE | sim (RFC 9110) | nada, mas `PUT` exige `If-Match` |
| **POST** que cria ou dispara efeito | **não** | `Idempotency-Key` obrigatório |
| PATCH | depende (`incrementar` não é) | trate como POST se não for |

POST naturalmente idempotente (upsert por id natural) pode se isentar com `x-api-ok` e motivo escrito
(waiver do gate). **Efeito externo** (cobrança, e-mail, SMS, webhook de saída) nunca é isentado.

## 2. Contrato do header

- Cliente gera uma chave **por tentativa lógica** (UUID v4 ou 128 bits aleatórios), reaproveitando-a
  em todo retry daquela tentativa; nova intenção, nova chave.
- Servidor guarda `(escopo, chave) -> fingerprint do corpo + estado + resposta` por um TTL (24 h é
  comum; documente). **Escopo = o principal autenticado** (chave de A não colide com a de B).
- Mesma chave + mesmo corpo: devolve **a mesma resposta** (mesmo status e corpo), sem reexecutar.
  Marque a repetição (`Idempotent-Replayed: true`).
- Mesma chave + corpo diferente: **422** (problem+json) — é bug do cliente, não retry.
- Mesma chave com a primeira ainda em curso: **409** com `Retry-After` (ou bloqueie e espere).
- Falha **antes** de efeito (validação 4xx) pode liberar a chave; falha **depois** de efeito grava o
  resultado. Defina e documente qual.

## 3. Implementação (o que dá errado)

1. **Reserva atômica**: `INSERT ... ON CONFLICT DO NOTHING` na tabela de chaves **na mesma transação**
   do efeito de banco. Sem isso, duas requisições simultâneas passam juntas.
2. **Efeito externo** (chamada a PSP, e-mail) não cabe na transação: use a chave como chave de
   idempotência **da chamada seguinte** (repasse ao PSP) e/ou o padrão outbox
   (`schematize-engineering → references/dados-eventos.md`).
3. **Fingerprint** do corpo canonicalizado (hash), não o corpo cru, para detectar reuso indevido.
4. **Limpeza** por TTL; tabela particionada se o volume pedir (`schematize-database`).
5. **Teste**: duas requisições concorrentes com a mesma chave produzem **um** efeito; é um teste
   obrigatório, com vermelho plantado (`schematize-qa`).

## 4. Consumidor de evento/webhook

O mesmo vale do outro lado: entrega *at-least-once* ⇒ o receptor deduplica por id de entrega
(`references/webhooks.md`). Idempotência no consumidor não é opcional.

## 5. Regra do gate

`post-sem-idempotencia`: POST sem parâmetro de header `Idempotency-Key` (ou `$ref` de nome equivalente)
reprova. Isenção só por `x-api-ok: ["post-sem-idempotencia: <motivo>"]`.
