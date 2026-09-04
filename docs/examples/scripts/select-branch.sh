#!/usr/bin/env bash
set -euo pipefail

# select-branch.sh — для каждого репозитория дерева зависимостей проверяет,
# существует ли custom-ветка на remote; если да — использует её, иначе падает
# обратно на базовую ветку. Затем подставляет результат как --override-input
# для `nix flake lock` и запускает `nix build`.
#
# Вся "нечистая" (сетевая) логика живёт здесь, в shell — сам flake.nix
# остаётся чистым и детерминированным (см. tutorial/07-branch-override-fallback.md).
#
# Использование:
#   ./select-branch.sh --custom-branch special-123123_add_feature \
#                       --base-branch special \
#                       --repos repos.txt \
#                       [--dry-run] \
#                       [-- <доп. аргументы для nix build, напр. .#app>]
#
# Формат файла repos.txt — одна строка на входной flake, разделитель — пробел:
#   <input-name> <git-url-без-схемы-git+>
# Пример:
#   libB https://gitlab.com/your-org/libB.git
#   libC https://gitlab.com/your-org/libC.git
# Для SSH используйте полный URL со схемой: ssh://git@gitlab.com/your-org/libB.git
#
# Важно: --override-input работает только для ВЕРХНЕУРОВНЕВЫХ inputs текущего
# flake. Чтобы override дошёл до всех узлов дерева, каждый уровень должен быть
# "поднят" наверх через inputs.follows (см. главу 06) — иначе вложенный input
# нужно переопределять отдельно, внутри соответствующего под-репозитория.

usage() {
  cat >&2 <<'EOF'
Usage: select-branch.sh --custom-branch <name> --base-branch <name> --repos <file> [--dry-run] [-- <nix build args>]
EOF
}

CUSTOM_BRANCH=""
BASE_BRANCH=""
REPOS_FILE=""
DRY_RUN=0
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --custom-branch)
      CUSTOM_BRANCH="$2"; shift 2 ;;
    --base-branch)
      BASE_BRANCH="$2"; shift 2 ;;
    --repos)
      REPOS_FILE="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --)
      shift; EXTRA_ARGS=("$@"); break ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "select-branch.sh: unknown argument: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$CUSTOM_BRANCH" || -z "$BASE_BRANCH" || -z "$REPOS_FILE" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$REPOS_FILE" ]]; then
  echo "select-branch.sh: repos file not found: $REPOS_FILE" >&2
  exit 1
fi

override_args=()

while read -r name url; do
  # пропускаем пустые строки и комментарии
  [[ -z "${name:-}" || "$name" == \#* ]] && continue

  if git ls-remote --exit-code --heads "$url" "refs/heads/$CUSTOM_BRANCH" >/dev/null 2>&1; then
    branch="$CUSTOM_BRANCH"
  else
    branch="$BASE_BRANCH"
  fi

  echo "select-branch: $name -> $branch  ($url)" >&2
  override_args+=(--override-input "$name" "git+${url}?ref=${branch}")
done < "$REPOS_FILE"

if [[ "${#override_args[@]}" -eq 0 ]]; then
  echo "select-branch.sh: repos file '$REPOS_FILE' had no valid entries" >&2
  exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "select-branch: dry-run — would execute:" >&2
  printf 'nix flake lock'; printf ' %q' "${override_args[@]}"; printf '\n'
  printf 'nix build'; printf ' %q' "${EXTRA_ARGS[@]}"; printf '\n'
  exit 0
fi

nix flake lock "${override_args[@]}"
nix build "${EXTRA_ARGS[@]}"
