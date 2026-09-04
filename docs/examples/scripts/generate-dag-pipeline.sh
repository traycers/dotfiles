#!/usr/bin/env bash
set -euo pipefail

# generate-dag-pipeline.sh — берёт полный граф derivations из Nix (nix derivation
# show -r), отфильтровывает его до "своих" пакетов (отбрасывая весь toolchain
# nixpkgs — gcc/cmake/glibc/...) и генерирует GitLab CI YAML с одним job на узел
# дерева и корректными needs:, чтобы GitLab сам развёл независимые узлы по
# разным раннерам. См. tutorial/10-dynamic-ci-pipelines.md.
#
# Использование (реальный прогон, требует установленный Nix):
#   ./generate-dag-pipeline.sh --installable .#app --names "app,libB,libC" \
#       --cache mycache --out generated.yml
#
# Использование для тестирования логики без Nix (граф уже посчитан заранее,
# см. tutorial/10-dynamic-ci-pipelines.md):
#   ./generate-dag-pipeline.sh --graph-json fake-graph.json --names "app,libB,libC" \
#       --cache mycache --out generated.yml
#
# Формат --names: имена pname (не pname-version!) через запятую — ровно те,
# что стоят в `pname = "...";` в flake.nix каждого узла дерева.

usage() {
  cat >&2 <<'EOF'
Usage: generate-dag-pipeline.sh (--installable <flake-ref> | --graph-json <file>)
                                 --names "name1,name2,..." --cache <cachix-cache-name>
                                 --out <file.yml>
EOF
}

INSTALLABLE=""
GRAPH_JSON=""
NAMES=""
CACHE=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --installable) INSTALLABLE="$2"; shift 2 ;;
    --graph-json) GRAPH_JSON="$2"; shift 2 ;;
    --names) NAMES="$2"; shift 2 ;;
    --cache) CACHE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "generate-dag-pipeline.sh: unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ ( -z "$INSTALLABLE" && -z "$GRAPH_JSON" ) || -z "$NAMES" || -z "$CACHE" || -z "$OUT" ]]; then
  usage
  exit 1
fi

names_json=$(printf '%s\n' "$NAMES" | tr ',' '\n' | jq -R . | jq -s .)

if [[ -n "$GRAPH_JSON" ]]; then
  if [[ ! -f "$GRAPH_JSON" ]]; then
    echo "generate-dag-pipeline.sh: graph file not found: $GRAPH_JSON" >&2
    exit 1
  fi
  graph_file="$GRAPH_JSON"
else
  graph_file="$(mktemp)"
  trap 'rm -f "$graph_file"' EXIT
  # -r/--recursive: включить в вывод весь транзитивный набор input-derivations,
  # не только прямые зависимости installable (см. главу 09).
  nix derivation show -r "$INSTALLABLE" > "$graph_file"
fi

# Отбираем только записи, чей env.pname входит в --names, и для каждой —
# только те inputDrvs, чей env.pname ТОЖЕ входит в --names (тем самым режем
# всю ветку toolchain'а: gcc/cmake/glibc остаются "невидимыми" рёбрами).
nodes_json=$(jq --argjson names "$names_json" '
  . as $graph
  | ($names | map({(.): true}) | add) as $wanted
  | to_entries
  | map(select(.value.env.pname as $p | $wanted[$p] // false))
  | map(
      .key as $drv
      | .value.env.pname as $name
      | {
          name: $name,
          drv: $drv,
          deps: (
            [ (.value.inputDrvs | keys[]) as $depDrv
              | ($graph[$depDrv].env.pname // null)
            ]
            | map(select(. != null and ($wanted[.] // false)))
            | unique
          )
        }
    )
' "$graph_file")

node_count=$(echo "$nodes_json" | jq 'length')
if [[ "$node_count" -eq 0 ]]; then
  echo "generate-dag-pipeline.sh: no nodes matched --names '$NAMES' in the graph — проверьте pname в flake.nix каждого узла" >&2
  exit 1
fi

{
  echo "stages:"
  echo "  - build"
  echo
  echo "default:"
  echo "  tags: [nix]"
  echo "  before_script:"
  echo "    - mkdir -p ~/.config/nix"
  echo "    - echo \"experimental-features = nix-command flakes\" >> ~/.config/nix/nix.conf"
  echo "    - nix run nixpkgs#cachix -- use \"$CACHE\""
  echo

  echo "$nodes_json" | jq -c '.[]' | while IFS= read -r node; do
    name=$(echo "$node" | jq -r '.name')
    deps=$(echo "$node" | jq -c '.deps | map("build:" + .)')
    echo "build:${name}:"
    echo "  stage: build"
    echo "  needs: ${deps}"
    echo "  script:"
    echo "    - nix build .#${name}"
    echo "    - nix run nixpkgs#cachix -- push \"$CACHE\" ./result"
    echo
  done
} > "$OUT"

echo "generate-dag-pipeline: wrote ${node_count} job(s) to $OUT" >&2
