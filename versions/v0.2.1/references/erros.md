# Erros — RFC 9457 (`application/problem+json`)

Erro é parte do contrato, não detalhe de implementação. Um cliente que precisa de regex na mensagem
para decidir o que fazer está acoplado ao texto, e o texto vai mudar.

## 1. O formato

```http
HTTP/1.1 422 Unprocessable Content
Content-Type: application/problem+json
Content-Language: pt-BR

{
  "type": "https://api.exemplo.org/problemas/saldo-insuficiente",
  "title": "Saldo insuficiente",
  "status": 422,
  "detail": "A conta tem R$ 10,00 e o pedido exige R$ 25,00.",
  "instance": "/pedidos/9f2c/pagamento",
  "codigo": "SALDO_INSUFICIENTE",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

- **`type`**: URI estável que **identifica o tipo** de problema; é a chave que o cliente testa. Pode
  resolver para uma página de documentação. Sem `type` equivale a `about:blank` (só o status).
- **`title`**: curto, **igual para o mesmo `type`**, não muda por ocorrência.
- **`status`**: igual ao status HTTP da resposta (conveniência para quem repassa o corpo).
- **`detail`**: específico desta ocorrência, legível por humano. **Nunca** stack trace, SQL, caminho
  de arquivo, host interno ou dado de outro usuário.
- **`instance`**: identifica esta ocorrência (URI do recurso ou id do erro).
- **Extensões**: campos próprios por `type` (`codigo`, `erros[]` de validação, `trace_id`). O
  `trace_id` liga o erro ao trace (`schematize-observability`) sem expor interno.

## 2. Validação

`400`/`422` com lista por campo, apontando por JSON Pointer:

```json
{ "type": ".../validacao", "title": "Dados inválidos", "status": 422,
  "erros": [ { "campo": "/itens/0/quantidade", "codigo": "MIN", "detail": "deve ser >= 1" } ] }
```

Escolha 400 **ou** 422 para validação semântica e use sempre o mesmo (registre no README da API).

## 3. Status que contam (e os que as pessoas erram)

| Situação | Status |
|---|---|
| corpo malformado | 400 |
| sem credencial/credencial inválida | 401 + `WWW-Authenticate` |
| autenticado sem permissão | 403 (ou 404 quando revelar a existência já é vazamento) |
| não existe | 404 |
| estado não permite (pedido já cancelado) | 409 |
| `If-Match` não bate | 412 (e **428** se exigiu `If-Match` e veio sem) |
| `Idempotency-Key` reutilizada com corpo diferente | 422 (ou 409 se a original está em curso) |
| corpo grande demais / tipo não suportado | 413 / 415 |
| limite de taxa | 429 + `Retry-After` |
| erro nosso | 500; dependência fora 502/503/504 + `Retry-After` quando souber |

Nunca `200` com `{"erro": ...}` no corpo: quebra cache, métrica e retry de todo cliente.

## 4. Regras do gate

`check-api.sh` reprova: operação **sem nenhuma** resposta de erro documentada (`sem-resposta-de-erro`)
e operação cujas respostas de erro **não** declaram `application/problem+json`
(`erro-sem-problem-json`). `default: { $ref: "#/components/responses/Erro" }` reaproveitado em toda
operação é o jeito barato de ficar verde.
