# Contrato REST — OpenAPI 3.1+ contract-first

A spec é o produto. O servidor e o cliente são derivados dela ou validados contra ela; quem
mantém spec e código à mão, em paralelo, está construindo o próximo incidente de "a doc mentia".

## 1. Contract-first

1. **Escreva a spec antes do handler.** Mudança de API começa por um PR na spec (revisável por quem
   consome), depois o código. Onde o framework só sabe gerar spec do código, a spec gerada é commitada
   e o CI falha se a gerada divergir da commitada (drift). Um dos dois é derivado do outro; nunca os dois à mão.
2. **OpenAPI 3.1 ou 3.2** (JSON Schema 2020-12, `webhooks`, `type: [string, "null"]`). 3.0 é legado
   (versões em `references/stack-versoes.md`).
3. **`operationId` único e estável** em toda operação: é o nome do método no cliente gerado e a
   chave do diff de breaking. Renomear `operationId` é breaking para o SDK.
4. **Exemplos validam** contra os próprios schemas (o lint de exemplos é parte do gate de CI).
5. **`additionalProperties`**: em resposta, o cliente tolera campo novo (a spec não fecha o objeto);
   em requisição, rejeite campo desconhecido com 400 para pegar typo. Documente a regra.

## 2. Recursos, métodos, status

| Quer | Método | Sucesso | Notas |
|---|---|---|---|
| ler | `GET` | 200 | sem efeito colateral, cacheável |
| criar | `POST /colecao` | 201 + `Location` | exige idempotência (`references/idempotencia.md`) |
| substituir | `PUT /colecao/{id}` | 200/204 | idempotente por definição; exige `If-Match` |
| alterar parcial | `PATCH /colecao/{id}` | 200 | JSON Merge Patch (RFC 7396) ou JSON Patch (RFC 6902); declare qual |
| remover | `DELETE /colecao/{id}` | 204 | repetir devolve 204 ou 404, documente qual |
| ação sem substantivo | `POST /colecao/{id}/cancelamento` | 202/200 | verbo vira sub-recurso; assíncrono devolve 202 + recurso de status |

- **Nomes**: substantivo no plural, `kebab-case` no caminho, `camelCase` ou `snake_case` no corpo
  (um só, escolhido no projeto). Datas em RFC 3339 UTC; dinheiro em inteiro de menor unidade +
  moeda (nunca `float`); identificadores opacos em `string`.
- **Operação longa** devolve `202 Accepted` + `Location` do recurso de status; nunca segure a
  conexão. O cliente consulta o status ou recebe webhook.
- **Filtro/ordenação** por parâmetros tipados e enumerados (`ordem=-criadoEm`); lista fechada de
  campos ordenáveis, todos indexados (`schematize-database`).
- **Tamanho**: defina `maxLength`/`maximum`/`maxItems` em todo campo de entrada. Schema sem teto é
  um vetor de abuso (`schematize-pentest`).

## 3. Segurança no contrato (a divisa com IAM)

- `components.securitySchemes` declarado e **toda operação cobre** (global ou por operação).
  Pública de propósito é `security: []` explícito, nunca omissão.
- **Escopos/permissões por operação** aparecem no `security` (`oauth2: [pedidos:escrever]`): o
  contrato diz o que cada rota exige. **Como** identidade, token, passkey e ReBAC funcionam é da
  `schematize-iam` (broker `auth.<domínio>`); o piso base está em
  `schematize-engineering → references/iam.md`. Aqui só se declara, e o gate confere que declarou.
- **Autorização por objeto** (BOLA/IDOR) é validada no handler, não no contrato; o teste ofensivo é
  da `schematize-pentest`. O contrato ajuda ao **não** expor id sequencial previsível.
- **TLS** sempre: `servers` com `http://` fora de loopback reprova.
- Token só em header `Authorization`, nunca em query string (vaza em log e `Referer`).

## 4. Publicação e lint

- Publicar a referência (Redoc/Scalar/Swagger UI), changelog por versão e SemVer da superfície:
  `schematize-docs → references/api-versionamento.md` (`/docs-api`). Esta skill é dona do
  **conteúdo do contrato**; a docs, do formato e da publicação.
- Regras de estilo próprias do time via Spectral (`.spectral.yaml`), no CI ao lado de
  `scripts/check-api.sh`. O gate da casa cobre o piso; o Spectral, o gosto.
