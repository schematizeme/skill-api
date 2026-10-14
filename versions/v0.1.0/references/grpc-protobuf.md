# gRPC e protobuf — contrato binário

Mesmo princípio do REST: o `.proto` é o contrato; o código é gerado dele; a quebra é detectada por
máquina.

## 1. Estrutura e estilo

- Um diretório por serviço/versão: `proto/empresa/pedidos/v1/pedidos.proto`, `package empresa.pedidos.v1;`
  (**sufixo de versão no package**: sem ele, mudança incompatível não tem onde morar —
  `proto-pacote-sem-versao`).
- `buf.yaml` na raiz do módulo, com `lint: use: [STANDARD]` e `breaking: use: [FILE]` (ou `WIRE_JSON`
  se só importa o formato de fio).
- Nomes: mensagens `PascalCase`, campos `snake_case`, enum `PREFIXO_VALOR` em `UPPER_SNAKE`.
- **Enum com zero `*_UNSPECIFIED`** (o default da fio é 0; sem isso, "não informado" parece valor
  real — `proto-enum-sem-zero-unspecified`).
- Um par `Request`/`Response` próprio por RPC (`CriarPedidoRequest`), nunca reutilizar mensagem de
  domínio como request: evolui independente.
- Dinheiro: inteiro de menor unidade + moeda (ou `google.type.Money`); nunca `float`/`double`.
  Tempo: `google.protobuf.Timestamp`/`Duration`.

## 2. Evolução compatível

| Pode | Não pode |
|---|---|
| adicionar campo com número novo | reutilizar número de campo |
| adicionar RPC/serviço | mudar o tipo de um campo existente |
| adicionar valor de enum | renomear campo (quebra JSON/`json_name`) sem `buf breaking` aceitar |
| deprecar (`[deprecated = true]`) | remover campo sem `reserved` |

- **Removeu campo? `reserved 4; reserved "nome_antigo";`** — impede reaproveitar número/nome por engano.
- `optional` explícito quando "ausente" difere de "zero". `oneof` para exclusão mútua.
- `buf breaking --against '.git#branch=main'` no PR (via `API_PROTO_AGAINST`).

## 3. Erros e metadados

- Status canônicos do gRPC (`INVALID_ARGUMENT`, `NOT_FOUND`, `FAILED_PRECONDITION`, `ALREADY_EXISTS`,
  `RESOURCE_EXHAUSTED`, `UNAVAILABLE`...) + detalhe estruturado (`google.rpc.Status` com
  `ErrorInfo`/`BadRequest`) — o equivalente de problem+json. Nunca string livre como único contrato.
- **Deadline sempre**: todo cliente define deadline; servidor propaga. Chamada sem deadline segura
  recurso para sempre.
- **Idempotência**: RPC que cria/dispara efeito leva `idempotency_key` no request (campo), pelas mesmas
  regras de `references/idempotencia.md`. Retry automático só em RPC idempotente.
- Autenticação por metadata (`authorization: Bearer ...`) sobre TLS/mTLS; autorização por RPC
  (interceptor), nunca "se está na rede interna, passa" (`schematize-iam`).

## 4. Exposição

- gRPC-Web ou gateway (`grpc-gateway`, Connect) quando há navegador; o contrato continua sendo o
  `.proto`. Se também publica REST, **uma** fonte: gere OpenAPI do proto, ou o inverso, nunca duas à mão.
- Reflexão do servidor (`grpc.reflection`) só em não-produção.
- Limites: tamanho máximo de mensagem, `keepalive`, número de streams concorrentes.

## 5. Gate

`check-api.sh` aplica as duas regras estáticas acima e, se `buf` estiver instalado e houver `buf.yaml`,
roda `buf lint` e (com `API_PROTO_AGAINST`) `buf breaking`. `buf` ausente: **aviso explícito**.
