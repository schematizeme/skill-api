# Paginação, filtro e ordenação

## 1. Cursor, não offset

`offset`/`page` quebra de duas formas: **custo** (`OFFSET 100000` varre e descarta 100 mil linhas) e
**correção** (inserção entre uma página e outra duplica ou pula item). Coleção que cresce usa
**paginação por cursor** (keyset).

```http
GET /pedidos?limite=25&cursor=eyJ0IjoiMjAyNi0xMC0xNFQxMjowMDowMFoiLCJpIjoiOWYyYyJ9
200 OK
{ "itens": [ ... ], "proximo": "eyJ0IjoiLi4uIn0" }   // null quando acabou
```

- O **cursor é opaco** (base64 de `{chave_de_ordem, id}`, de preferência assinado ou cifrado): o cliente
  não constrói, não interpreta, só devolve. Isso deixa você trocar a implementação sem breaking.
- **Ordem total e estável**: `ORDER BY criado_em DESC, id DESC` e predicado
  `(criado_em, id) < ($1, $2)`. Ordenar por coluna não única sem desempate pula/duplica.
- Índice composto na ordem do `ORDER BY` (`schematize-database`).
- `limite` com **máximo** no schema (`maximum: 100`) e default; sem teto é negação de serviço.
- Total (`count(*)`) é caro: ofereça só sob demanda (`?incluir=total`) ou aproximado.
- Link `Link: <...>; rel="next"` é opcional; o corpo com `proximo` é o contrato.
- Offset só se a coleção é pequena, limitada e estável; registre a exceção com motivo
  (`x-api-ok: ["paginacao-offset: <motivo>"]`).

## 2. Filtro e ordenação

- Filtros por **parâmetros tipados e enumerados**, documentados no schema; nada de `filtro=<SQL>`.
- Ordenação com **lista fechada** de campos (`ordem=-criadoEm`), todos indexados.
- Busca textual é recurso próprio (`/pedidos/busca`), com seu contrato e limites.
- Campos sensíveis nunca são filtráveis (permite inferência por oráculo).

## 3. Regras do gate

`paginacao-offset` (erro): GET com `offset`, `page`, `page_number` ou `skip`. `lista-sem-cursor` (aviso):
GET de coleção cuja resposta é array e sem `cursor`/`after`/`page_token`.
