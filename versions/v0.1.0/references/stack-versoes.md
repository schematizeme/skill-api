# Anexo volátil — versões, drafts e ferramental (API)

> Parte da skill **schematize-api**. **Fonte volátil:** número de versão, status de draft IETF e
> comportamento de ferramenta mudam. O corpo normativo diz **princípio**; o número mora aqui, com
> data e fonte.
>
> **Verificado em: 2026-10-14.** Cadência: revisão trimestral e antes de cada release da skill.
> Método: API de releases do GitHub (`gh api repos/<org>/<repo>/releases/latest`), datatracker do
> IETF (`datatracker.ietf.org/api/v1/doc/document/<draft>/`) e cabeçalho dos RFCs em `rfc-editor.org`.

## Especificações

| Item | Estado em 2026-10-14 | Fonte | Nota |
|---|---|---|---|
| **OpenAPI** | **3.2.1** (2026-09-10); 3.2.0 (2025-09-19); 3.1.2 (2025-09-19) | `OAI/OpenAPI-Specification` releases | A casa exige **3.1 ou 3.2** (JSON Schema 2020-12, `webhooks`). 3.0.x é legado: o gate avisa. Qual gerador/validador suporta 3.2 <!-- reverificar --> |
| **RFC 9457** Problem Details | RFC publicado, **obsoleta a RFC 7807** | rfc-editor.org | `application/problem+json`; registro de tipos de problema |
| **RFC 9745** header `Deprecation` | RFC, Standards Track | rfc-editor.org | complementa o `Sunset` |
| **RFC 8594** header `Sunset` | RFC, **Informational** | rfc-editor.org | data HTTP de desligamento |
| **RFC 9110/9111** semântica e cache HTTP | RFCs vigentes | rfc-editor.org | `ETag`, `If-Match`, `If-None-Match`, 412/428 |
| **RFC 9421** HTTP Message Signatures | RFC, Standards Track | rfc-editor.org | alternativa à assinatura HMAC de corpo; adoção por PSPs/plataformas varia |
| **RateLimit headers** | **Internet-Draft ativo** `draft-ietf-httpapi-ratelimit-headers-11` (2026-05-23, expira 2026-11-24). **NÃO é RFC** | datatracker IETF | campos `RateLimit-Policy` e `RateLimit`. O formato mudou entre drafts (o antigo `RateLimit-Limit/-Remaining/-Reset` e o `X-RateLimit-*` de fato são anteriores). Trate como convenção em evolução e pin a revisão no contrato |
| **Idempotency-Key header** | **Internet-Draft EXPIRADO** `draft-ietf-httpapi-idempotency-key-header-07` (2026-04-18) | datatracker IETF | sem RFC; a convenção de fato (Stripe e outros) é o que vale. Documente o comportamento no contrato, não "o padrão IETF" |
| **Standard Webhooks** | **v1.0.2** (2026-02-18) | `standard-webhooks/standard-webhooks` releases | headers `webhook-id`, `webhook-timestamp`, `webhook-signature`; assinatura HMAC-SHA256 de `id.timestamp.corpo`. Especificação comunitária, não IETF |

## Ferramentas

| Ferramenta | Corrente (2026-10-14) | Fonte | Uso |
|---|---|---|---|
| **buf** | **v1.73.0** (2026-09-11) | `bufbuild/buf` | `buf lint`, `buf breaking --against`, `buf generate` |
| **oasdiff** | **v1.33.0** (2026-10-01) | `oasdiff/oasdiff` | `oasdiff breaking base.yaml nova.yaml --fail-on ERR` |
| **Spectral** | **v6.17.0** (2026-10-01) | `stoplightio/spectral` | lint de ruleset OpenAPI (`.spectral.yaml`) |
| `actions/checkout` | v7.0.1 = `3d3c42e5aac5ba805825da76410c181273ba90b1` | `gh api repos/actions/checkout/commits/v7.0.1` | pin por SHA no CI de referência |

## O que foi executado nesta máquina

- `scripts/check-api.test.sh` (vermelho e verde plantados; `oasdiff` e `buf` com stub, porque não
  estão instalados aqui). `scripts/check-api.sh` sobre `assets/exemplos/openapi-minimo.yaml`: 0 erros.
- **Não executado:** `oasdiff` e `buf` reais, `spectral`, geração de clientes. O gate avisa quando a
  ferramenta falta; nunca declara verde por omissão.

## Não verificado

- Suporte de cada gerador de código (openapi-generator, oapi-codegen, progenitor, etc.) a OpenAPI 3.2 <!-- reverificar -->.
- Se algum PSP/plataforma já adotou RFC 9421 em vez de HMAC de corpo <!-- reverificar -->.
