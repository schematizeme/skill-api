# Rate limit e concorrência otimista

## 1. Rate limit

Limite protege o serviço e é parte do contrato: o cliente precisa saber **quanto**, **quanto resta** e
**quando volta**.

- **Responda `429`** (problem+json) com `Retry-After` (segundos ou data HTTP). O cliente bem-feito
  respeita e aplica backoff com jitter; documente isso para o seu SDK.
- **Headers de quota**: o IETF trabalha em `RateLimit-Policy` e `RateLimit` (campos estruturados), mas
  o documento é um **Internet-Draft ativo, não RFC** — o formato já mudou entre revisões
  (`references/stack-versoes.md`). Duas posturas válidas, escolha e registre em ADR:
  1. emitir o draft vigente (pin da revisão no contrato) e `Retry-After`;
  2. emitir só `Retry-After` + `X-RateLimit-*` documentados como convenção própria.
  O gate exige ao menos `Retry-After` ou `RateLimit*` declarados no `429` (`429-sem-ratelimit`, aviso).
- **Chave do limite**: por credencial/tenant (não só por IP: NAT e CGNAT punem inocentes e IP rotativo
  escapa). Limites distintos para leitura, escrita e operações caras. Cota por plano.
- **Algoritmo**: token bucket ou janela deslizante; contador em Redis/gateway, não em memória de uma
  instância. Em falha do contador, decida **fail-open ou fail-closed** por rota e documente.
- **Defesa em profundidade**: o limite do gateway não substitui timeout, tamanho máximo de corpo,
  profundidade de JSON e limite de paginação no serviço.
- Autenticação (login, recuperação de conta, OTP) tem limite próprio e mais duro, atrelado à conta
  (`schematize-iam`).

## 2. Concorrência otimista (ETag / If-Match)

Dois clientes leem o recurso, ambos editam, o último `PUT` apaga a edição do primeiro. Sem controle,
escrita concorrente vira perda silenciosa de dado.

1. `GET /recurso/{id}` devolve `ETag: "v7"` (hash do conteúdo ou número de versão da linha).
2. `PUT`/`PATCH`/`DELETE` exigem `If-Match: "v7"`.
3. Servidor compara (na mesma transação do `UPDATE ... WHERE id=$1 AND versao=$2`): bate ⇒ aplica e
   devolve novo ETag; não bate ⇒ **`412 Precondition Failed`** (problem+json); veio sem `If-Match` ⇒
   **`428 Precondition Required`**.
4. ETag **forte** para escrita; fraco (`W/`) só para cache. `If-None-Match` + `304` economiza banda em GET.
5. Na coluna: `versao integer NOT NULL` incrementada a cada escrita, ou `xmin` (Postgres) com cuidado.

O gate avisa `escrita-sem-concorrencia` para `PUT`/`PATCH`/`DELETE` em `/{id}` sem `If-Match` declarado.
Recurso que genuinamente não tem edição concorrente (log de auditoria imutável) fica de fora por
`x-api-ok` com motivo.
