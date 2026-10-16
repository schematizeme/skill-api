#!/usr/bin/env bash
# check-api.sh — gate estático da schematize-api. Lê o CONTRATO (OpenAPI 3.x, .proto), não o código.
#
# Motivo: o que mais machuca numa API publicada (erro sem formato, POST que cobra duas vezes,
# paginação por offset, webhook sem assinatura, rota "deprecada" sem data) é visível no texto da
# spec, antes de qualquer cliente depender dela. Depois de publicado, vira dívida de compatibilidade.
# Como funciona: acha as specs OpenAPI (JSON/YAML com `openapi:` na raiz) e os `*.proto` sob o
# alvo e aplica as regras abaixo com python3 (stdlib; usa PyYAML se existir, senão um leitor YAML
# mínimo de estilo bloco). Heurística de contrato: o que ela não prova, o spectral/oasdiff/buf provam.
# Entrada: $1 = diretório ou arquivo (default .).
# Env: API_BASE=<spec antiga>  roda `oasdiff breaking` contra ela (se oasdiff instalado; senão aviso)
#      API_PROTO_AGAINST=<ref>  roda `buf breaking --against` (se buf instalado; senão aviso)
# Saída: achados `arquivo:local: [ERRO|AVISO regra] mensagem`.
#        exit 0 passa · 1 reprova · 2 NADA para verificar (não é aprovação).
#
# Regras OpenAPI (id): spec-ilegivel · versao-openapi · sem-seguranca-declarada ·
#   operacao-sem-seguranca · servidor-sem-tls · operacao-sem-id · sem-resposta-de-erro ·
#   erro-sem-problem-json · post-sem-idempotencia · paginacao-offset · lista-sem-cursor ·
#   429-sem-ratelimit · escrita-sem-concorrencia · deprecada-sem-sunset · webhook-sem-assinatura ·
#   webhook-sem-id-ou-timestamp · breaking-change (oasdiff).
# Regras proto (id): proto-pacote-sem-versao · proto-enum-sem-zero-unspecified · buf-breaking.
# Waiver rastreável (OpenAPI): na operação, `x-api-ok: ["<regra>: <motivo>"]` (ou string).
#   Operação pública de propósito: `security: []` explícito (é decisão, não omissão).
set -euo pipefail

ALVO="${1:-.}"
[ -e "$ALVO" ] || { echo "check-api: '$ALVO' não existe" >&2; exit 2; }
if ! command -v python3 >/dev/null 2>&1; then
  echo "check-api: AVISO python3 ausente — nada verificado (isto NÃO é aprovação)" >&2
  exit 2
fi

ACHADOS="$(mktemp)"
trap 'rm -f "$ACHADOS"' EXIT INT TERM
: >"$ACHADOS"

python3 -I - "$ALVO" >"$ACHADOS" <<'PY'
import json, os, re, sys

alvo = sys.argv[1]
METODOS = ("get", "put", "post", "delete", "options", "head", "patch", "trace")
achados = []


def emit(arq, local, sev, regra, msg):
    achados.append("%s:%s: [%s %s] %s" % (arq, local, sev, regra, msg))


# ---------------------------------------------------------------- leitor YAML mínimo (estilo bloco)
def _sem_comentario(s):
    saida, asp, dup = [], False, False
    for i, c in enumerate(s):
        if c == "'" and not dup:
            asp = not asp
        elif c == '"' and not asp and (i == 0 or s[i - 1] != "\\"):
            dup = not dup
        elif c == "#" and not asp and not dup and (i == 0 or s[i - 1] in " \t"):
            break
        saida.append(c)
    return "".join(saida).rstrip()


def _escalar(v):
    v = v.strip()
    if v == "" or v in ("~", "null", "Null", "NULL"):
        return None
    if v[0] == '"' and v[-1] == '"' and len(v) > 1:
        try:
            return json.loads(v)
        except ValueError:
            return v[1:-1]
    if v[0] == "'" and v[-1] == "'" and len(v) > 1:
        return v[1:-1].replace("''", "'")
    if v in ("true", "True", "TRUE"):
        return True
    if v in ("false", "False", "FALSE"):
        return False
    if v[0] in "[{":
        return _fluxo(v)
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if re.fullmatch(r"-?\d+\.\d+", v):
        return float(v)
    return v


def _parte_fluxo(s):
    partes, prof, atual, asp, dup = [], 0, [], False, False
    for c in s:
        if c == "'" and not dup:
            asp = not asp
        elif c == '"' and not asp:
            dup = not dup
        if not asp and not dup:
            if c in "[{":
                prof += 1
            elif c in "]}":
                prof -= 1
            elif c == "," and prof == 0:
                partes.append("".join(atual))
                atual = []
                continue
        atual.append(c)
    if "".join(atual).strip():
        partes.append("".join(atual))
    return partes


def _fluxo(v):
    v = v.strip()
    if v[0] == "[" and v[-1] == "]":
        return [_escalar(p) for p in _parte_fluxo(v[1:-1])]
    if v[0] == "{" and v[-1] == "}":
        d = {}
        for p in _parte_fluxo(v[1:-1]):
            k, _, val = p.partition(":")
            d[_escalar(k)] = _escalar(val)
        return d
    return v


def yaml_minimo(texto):
    linhas = []
    for bruta in texto.splitlines():
        if bruta.strip() in ("---", "...") or not bruta.strip() or bruta.lstrip().startswith("#"):
            if linhas and linhas[-1][2] is not None:
                linhas.append((None, None, None, bruta))  # vazia: preserva para bloco literal
            continue
        linhas.append((len(bruta) - len(bruta.lstrip(" ")), _sem_comentario(bruta.strip()), 0, bruta))
    linhas = [l for l in linhas if l[0] is not None]
    pos = [0]

    def bloco(ind):
        if pos[0] >= len(linhas):
            return None
        i, txt = linhas[pos[0]][0], linhas[pos[0]][1]
        if txt.startswith("- ") or txt == "-":
            return seq(i)
        return mapa(i)

    def valor_apos(chave_ind, resto, eh_seq_item=False):
        resto = resto.strip()
        if resto in ("|", ">", "|-", ">-", "|+", ">+"):
            buf = []
            while pos[0] < len(linhas) and linhas[pos[0]][0] > chave_ind:
                buf.append(linhas[pos[0]][1])
                pos[0] += 1
            return "\n".join(buf)
        if resto != "":
            return _escalar(resto)
        if pos[0] < len(linhas):
            i, txt = linhas[pos[0]][0], linhas[pos[0]][1]
            if i > chave_ind or (i == chave_ind and (txt.startswith("- ") or txt == "-") and not eh_seq_item):
                return bloco(i)
        return None

    def mapa(ind):
        d = {}
        while pos[0] < len(linhas) and linhas[pos[0]][0] == ind and not linhas[pos[0]][1].startswith("- "):
            txt = linhas[pos[0]][1]
            m = re.match(r"""^("[^"]*"|'[^']*'|[^:]+?)\s*:(?:\s+(.*)|$)""", txt)
            if not m:
                pos[0] += 1
                continue
            k = _escalar(m.group(1))
            pos[0] += 1
            d[k] = valor_apos(ind, m.group(2) or "")
        return d

    def seq(ind):
        out = []
        while pos[0] < len(linhas) and linhas[pos[0]][0] == ind and (linhas[pos[0]][1].startswith("- ") or linhas[pos[0]][1] == "-"):
            txt = linhas[pos[0]][1]
            resto = txt[1:].strip()
            if resto and re.match(r"""^("[^"]*"|'[^']*'|[^:\s][^:]*?)\s*:(?:\s|$)""", resto) and resto[0] not in "[{\"'" or (resto and resto[0] in "\"'" and re.match(r"""^("[^"]*"|'[^']*')\s*:(?:\s|$)""", resto)):
                # item é um mapa inline: reescreve a linha como mapa recuado
                novo_ind = ind + 2
                linhas[pos[0]] = (novo_ind, resto, 0, "")
                out.append(mapa(novo_ind))
            else:
                pos[0] += 1
                out.append(valor_apos(ind, resto, True))
        return out

    return bloco(linhas[0][0]) if linhas else None


def carregar(caminho):
    with open(caminho, encoding="utf-8") as f:
        texto = f.read()
    if caminho.endswith(".json"):
        return json.loads(texto)
    try:
        import yaml  # noqa: PLC0415
        return yaml.safe_load(texto)
    except ImportError:
        return yaml_minimo(texto)


# ---------------------------------------------------------------- descoberta
def acha_arquivos(base):
    specs, protos = [], []
    if os.path.isfile(base):
        (protos if base.endswith(".proto") else specs).append(base)
        return specs, protos
    for raiz, dirs, nomes in os.walk(base):
        dirs[:] = [d for d in dirs if d not in (".git", "node_modules", "versions", ".terraform", "vendor", "target")]
        for n in nomes:
            p = os.path.join(raiz, n)
            if n.endswith(".proto"):
                protos.append(p)
            elif n.endswith((".yaml", ".yml", ".json")):
                try:
                    with open(p, encoding="utf-8") as f:
                        cab = f.read(4096)
                except (OSError, UnicodeDecodeError):
                    continue
                if re.search(r'(^|[\n{,])\s*["\']?openapi["\']?\s*:\s*["\']?3', cab):
                    specs.append(p)
    return sorted(specs), sorted(protos)


def deref(spec, no, prof=0):
    """Resolve $ref local (#/...) até 5 níveis; o que não resolve volta como está."""
    while isinstance(no, dict) and "$ref" in no and prof < 5:
        ref = no["$ref"]
        if not (isinstance(ref, str) and ref.startswith("#/")):
            return no
        cur = spec
        for parte in ref[2:].split("/"):
            parte = parte.replace("~1", "/").replace("~0", "~")
            cur = cur.get(parte) if isinstance(cur, dict) else None
            if cur is None:
                return no
        no = cur
        prof += 1
    return no


def waivers(op):
    w = op.get("x-api-ok") if isinstance(op, dict) else None
    if w is None:
        return set()
    itens = w if isinstance(w, list) else [w]
    return {str(i).split(":", 1)[0].strip() for i in itens if ":" in str(i) and str(i).split(":", 1)[1].strip()}


def nomes_params(spec, op, item):
    nomes = []
    for p in (item.get("parameters") or []) + (op.get("parameters") or []):
        p = deref(spec, p)
        if isinstance(p, dict):
            nomes.append((str(p.get("name", "")).lower(), str(p.get("in", "")).lower(), p))
        else:
            nomes.append(("", "", {}))
    return nomes


def refs_nomes(op, item):
    """$ref de parâmetros não resolvidos viram o nome do componente (fallback de nome)."""
    out = []
    for p in (item.get("parameters") or []) + (op.get("parameters") or []):
        if isinstance(p, dict) and isinstance(p.get("$ref"), str):
            out.append(p["$ref"].rsplit("/", 1)[-1].lower())
    return out


def tem_problem_json(spec, resp):
    resp = deref(spec, resp)
    cont = resp.get("content") if isinstance(resp, dict) else None
    if not isinstance(cont, dict):
        return False
    return any("problem+json" in str(k).lower() for k in cont)


def cabecalhos_resp(spec, resp):
    resp = deref(spec, resp)
    h = resp.get("headers") if isinstance(resp, dict) else None
    return {str(k).lower() for k in h} if isinstance(h, dict) else set()


def schema_resposta_lista(spec, resp):
    resp = deref(spec, resp)
    cont = resp.get("content") if isinstance(resp, dict) else None
    if not isinstance(cont, dict):
        return False
    for mt in cont.values():
        sch = deref(spec, (mt or {}).get("schema")) if isinstance(mt, dict) else None
        if not isinstance(sch, dict):
            continue
        if sch.get("type") == "array":
            return True
        props = deref(spec, sch).get("properties") or {}
        for nome in ("items", "data", "results"):
            sub = deref(spec, props.get(nome))
            if isinstance(sub, dict) and sub.get("type") == "array":
                return True
    return False


# ---------------------------------------------------------------- regras OpenAPI
def checa_spec(arq):
    try:
        spec = carregar(arq)
    except Exception as e:  # noqa: BLE001
        emit(arq, 1, "ERRO", "spec-ilegivel", "não consegui ler a spec: %s" % str(e)[:80])
        return
    if not isinstance(spec, dict):
        emit(arq, 1, "ERRO", "spec-ilegivel", "a raiz da spec não é um objeto")
        return
    ver = str(spec.get("openapi", ""))
    if not re.match(r"^3\.(1|2)\.", ver):
        emit(arq, 1, "AVISO", "versao-openapi", "openapi %s: use 3.1 ou 3.2 (JSON Schema 2020-12 nativo)" % (ver or "?"))

    comps = spec.get("components") or {}
    esquemas = comps.get("securitySchemes") or {}
    seg_global = spec.get("security")
    if not esquemas:
        emit(arq, "components", "ERRO", "sem-seguranca-declarada", "components.securitySchemes ausente: a spec não diz como autenticar")

    for s in spec.get("servers") or []:
        url = str(s.get("url", "")) if isinstance(s, dict) else ""
        if url.startswith("http://") and not re.match(r"^http://(localhost|127\.|\[::1\]|0\.0\.0\.0)", url):
            emit(arq, "servers", "ERRO", "servidor-sem-tls", "servidor %s sem TLS (http fora de loopback)" % url)

    # operações de paths e de webhooks
    grupos = [("paths", spec.get("paths") or {}, False), ("webhooks", spec.get("webhooks") or {}, True)]
    for nome_grupo, tabela, eh_webhook in grupos:
        if not isinstance(tabela, dict):
            continue
        for caminho, item in tabela.items():
            item = deref(spec, item)
            if not isinstance(item, dict):
                continue
            for metodo in METODOS:
                op = item.get(metodo)
                if not isinstance(op, dict):
                    continue
                local = "%s.%s.%s" % (nome_grupo, caminho, metodo)
                ok = waivers(op)

                def r(sev, regra, msg, _local=local, _ok=ok):
                    if regra not in _ok:
                        emit(arq, _local, sev, regra, msg)

                if eh_webhook:
                    checa_webhook(spec, op, item, r)
                    continue

                if not op.get("operationId"):
                    r("AVISO", "operacao-sem-id", "operationId ausente (necessário para gerar clientes e rastrear breaking)")

                if "security" not in op and seg_global is None:
                    r("ERRO", "operacao-sem-seguranca", "sem `security` na operação nem global (use `security: []` se for pública de propósito)")

                resps = op.get("responses") or {}
                erros = {str(c): v for c, v in resps.items() if str(c)[:1] in ("4", "5") or str(c).lower() == "default"}
                if not erros:
                    r("ERRO", "sem-resposta-de-erro", "nenhuma resposta 4xx/5xx/default documentada")
                elif not any(tem_problem_json(spec, v) for v in erros.values()):
                    r("ERRO", "erro-sem-problem-json", "respostas de erro sem `application/problem+json` (RFC 9457)")

                nomes = nomes_params(spec, op, item)
                nomes_ref = refs_nomes(op, item)
                so_nomes = {n for n, _, _ in nomes}
                if metodo == "post":
                    idem = any(("idempotency" in n) for n in so_nomes) or any("idempotency" in n for n in nomes_ref)
                    if not idem:
                        r("ERRO", "post-sem-idempotencia", "POST sem header Idempotency-Key documentado (declare, ou `x-api-ok: [\"post-sem-idempotencia: <motivo>\"]` se a operação é naturalmente idempotente)")

                if metodo == "get":
                    off = {"offset", "page", "page_number", "pagenumber", "skip"} & so_nomes
                    if off:
                        r("ERRO", "paginacao-offset", "paginação por offset/página (%s): use cursor opaco" % ", ".join(sorted(off)))
                    cursor = {"cursor", "after", "before", "page_token", "pagetoken", "starting_after", "next_token", "page[after]"}
                    eh_colecao = not str(caminho).rstrip("/").endswith("}")
                    lista = any(schema_resposta_lista(spec, v) for c, v in resps.items() if str(c).startswith("2"))
                    if eh_colecao and lista and not off and not (cursor & so_nomes) and not any("cursor" in n or "pagetoken" in n for n in nomes_ref):
                        r("AVISO", "lista-sem-cursor", "coleção sem paginação por cursor (cursor/after/page_token) e sem limite máximo")

                if "429" in {str(c) for c in resps}:
                    h = cabecalhos_resp(spec, resps.get(429, resps.get("429")))
                    if not (h & {"retry-after", "ratelimit", "ratelimit-policy", "x-ratelimit-limit"}):
                        r("AVISO", "429-sem-ratelimit", "429 sem `Retry-After`/`RateLimit` documentados nos headers da resposta")

                if metodo in ("put", "patch", "delete") and str(caminho).rstrip("/").endswith("}"):
                    if not (({"if-match"} & so_nomes) or any("ifmatch" in n or "if_match" in n for n in nomes_ref)):
                        r("AVISO", "escrita-sem-concorrencia", "%s em recurso sem `If-Match`/ETag: escrita concorrente sobrescreve em silêncio" % metodo.upper())

                if op.get("deprecated") is True:
                    hs = set()
                    for v in resps.values():
                        hs |= cabecalhos_resp(spec, v)
                    if "sunset" not in hs:
                        r("ERRO", "deprecada-sem-sunset", "operação `deprecated: true` sem header `Sunset` documentado (deprecar sem data não é deprecar)")


def checa_webhook(spec, op, item, r):
    nomes = {n for n, _, _ in nomes_params(spec, op, item)} | set(refs_nomes(op, item))
    corpo = op.get("requestBody")
    hs = set()
    if isinstance(corpo, dict):
        pass
    if not any("signature" in n or "assinatura" in n for n in nomes):
        r("ERRO", "webhook-sem-assinatura", "webhook sem header de assinatura (ex.: webhook-signature) documentado")
    if not (any(("id" in n.split("-") or n.endswith("-id") or n.endswith("_id")) for n in nomes) and any("timestamp" in n for n in nomes)):
        r("AVISO", "webhook-sem-id-ou-timestamp", "webhook sem id de entrega e timestamp documentados (idempotência do receptor e janela de replay)")
    _ = hs


# ---------------------------------------------------------------- regras proto
def checa_proto(arq):
    with open(arq, encoding="utf-8", errors="replace") as f:
        linhas = f.read().splitlines()
    pacote_ok = None
    enum_aberto, primeiro = None, True
    for i, bruta in enumerate(linhas, 1):
        l = re.sub(r"//.*$", "", bruta).strip()
        m = re.match(r"^package\s+([\w.]+)\s*;", l)
        if m:
            pacote_ok = bool(re.search(r"\.v\d+((alpha|beta)\d*)?$", m.group(1)))
            if not pacote_ok and "proto-ok" not in bruta:
                emit(arq, i, "AVISO", "proto-pacote-sem-versao", "package %s sem sufixo de versão (.v1): mudança incompatível não tem onde morar" % m.group(1))
        m = re.match(r"^enum\s+(\w+)\s*\{", l)
        if m:
            enum_aberto, primeiro = m.group(1), True
            continue
        if enum_aberto:
            if l.startswith("}"):
                enum_aberto = None
                continue
            m2 = re.match(r"^(\w+)\s*=\s*(-?\d+)", l)
            if m2 and primeiro:
                primeiro = False
                if m2.group(2) != "0" or not m2.group(1).endswith("UNSPECIFIED"):
                    if "proto-ok" not in bruta:
                        emit(arq, i, "ERRO", "proto-enum-sem-zero-unspecified", "enum %s: o valor 0 deve ser *_UNSPECIFIED (default da fio = 'não informado')" % enum_aberto)


specs, protos = acha_arquivos(alvo)
for s in specs:
    checa_spec(s)
for p in protos:
    checa_proto(p)

print("\n".join(achados))
print("META\tspecs\t%d" % len(specs))
print("META\tprotos\t%d" % len(protos))
for s in specs:
    print("META\tspec\t%s" % s)
for p in protos:
    print("META\tproto\t%s" % p)
PY

N_SPECS="$(awk -F'\t' '$1=="META"&&$2=="specs"{print $3}' "$ACHADOS")"
N_PROTOS="$(awk -F'\t' '$1=="META"&&$2=="protos"{print $3}' "$ACHADOS")"
LISTA_SPECS="$(awk -F'\t' '$1=="META"&&$2=="spec"{print $3}' "$ACHADOS")"
LISTA_PROTOS="$(awk -F'\t' '$1=="META"&&$2=="proto"{print $3}' "$ACHADOS")"
SAIDA="$(grep -v '^META' "$ACHADOS" | grep -v '^$' || true)"

if [ "${N_SPECS:-0}" = "0" ] && [ "${N_PROTOS:-0}" = "0" ]; then
  echo "check-api: nenhuma spec OpenAPI nem .proto em '$ALVO' — nada verificado (isto NÃO é aprovação)" >&2
  exit 2
fi

# Ferramentas externas: ausência vira AVISO explícito, nunca falso verde.
EXTRA=""
if [ -n "${API_BASE:-}" ]; then
  if command -v oasdiff >/dev/null 2>&1; then
    while IFS= read -r spec; do
      [ -n "$spec" ] || continue
      if ! out="$(oasdiff breaking "$API_BASE" "$spec" --fail-on ERR 2>&1)"; then
        EXTRA+="$spec:breaking: [ERRO breaking-change] oasdiff achou quebra contra $API_BASE: $(printf '%s' "$out" | head -n 3 | tr '\n' ' ')"$'\n'
      fi
    done <<<"$LISTA_SPECS"
  else
    EXTRA+="-:oasdiff: [AVISO breaking-change] oasdiff ausente — quebra de compatibilidade NÃO verificada (instale: github.com/oasdiff/oasdiff)"$'\n'
  fi
fi
if [ -n "${LISTA_PROTOS}" ]; then
  if command -v buf >/dev/null 2>&1; then
    if [ -f "$ALVO/buf.yaml" ] || [ -f "$ALVO/buf.work.yaml" ]; then
      if ! out="$(cd "$ALVO" && buf lint 2>&1)"; then
        EXTRA+="$ALVO:buf-lint: [ERRO buf-lint] $(printf '%s' "$out" | head -n 3 | tr '\n' ' ')"$'\n'
      fi
      if [ -n "${API_PROTO_AGAINST:-}" ] && ! out="$(cd "$ALVO" && buf breaking --against "$API_PROTO_AGAINST" 2>&1)"; then
        EXTRA+="$ALVO:buf-breaking: [ERRO buf-breaking] $(printf '%s' "$out" | head -n 3 | tr '\n' ' ')"$'\n'
      fi
    else
      EXTRA+="$ALVO:buf.yaml: [AVISO buf-lint] .proto sem buf.yaml na raiz — buf lint/breaking não rodou"$'\n'
    fi
  else
    EXTRA+="-:buf: [AVISO buf-lint] buf ausente — lint e breaking de protobuf NÃO verificados (instale: buf.build)"$'\n'
  fi
fi

SAIDA="$(printf '%s\n%s' "$SAIDA" "$EXTRA" | grep -v '^$' || true)"
NE=0; NA=0
if [ -n "$SAIDA" ]; then
  printf '%s\n' "$SAIDA"
  NE="$(printf '%s\n' "$SAIDA" | grep -c '\[ERRO ' || true)"
  NA="$(printf '%s\n' "$SAIDA" | grep -c '\[AVISO ' || true)"
fi
echo "check-api: ${N_SPECS:-0} spec(s), ${N_PROTOS:-0} proto(s): $NE erro(s), $NA aviso(s)"
[ "$NE" = "0" ]
