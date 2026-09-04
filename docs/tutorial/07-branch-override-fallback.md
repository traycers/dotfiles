# Глава 07 — Override сборки по ветке с fallback (ключевая глава)

Задача: у вас есть дерево репозиториев (`app → libB → libC`, как в главе 06). В каждом репозитории может существовать ветка `special-123123_add_feature`. Если она есть — собирать проект из неё. Если её нет в конкретном репозитории — собирать из базовой ветки `special`. Причём это должно работать **согласованно по всему дереву одновременно**, а не только для верхнего репозитория.

## Почему это не решается одной строкой в `flake.nix`

В главе 01 и 03 мы установили: Nix-сборка (`nix build` в обычном pure-режиме) не имеет доступа к сети внутри evaluation, а resolution `ref` (имя ветки) → конкретный коммит для flake-inputs происходит **до** запуска чистой части, на этапе, который сам по себе требует сети и не является частью deterministic evaluation. `flake.nix` не может внутри себя написать "если на GitLab существует ветка X, возьми её, иначе Y" — сам вопрос "существует ли X" требует сетевого запроса в момент, когда еще ничего не резолвлено, а этот момент — вне чистой модели evaluation, которой подчиняется код внутри `outputs = ...`.

Следствие: логика "проверить существование ветки" **обязана** жить либо (а) снаружи Nix, в обычном shell/CI, который явно управляет `flake.lock`, либо (б) внутри Nix, но в явно помеченном impure-контексте (`--impure`, `builtins.fetchGit` без `rev`). Оба варианта разобраны ниже — первый рекомендуется для flake-based деревьев (как в этом tutorial), второй полезен знать для не-flake `callPackage`-композиций.

## Паттерн 1 (рекомендуемый): shell-скрипт + `--override-input`

Идея: `git ls-remote` — обычная, ничем не ограниченная сетевая операция **вне** Nix. Прогоняем её по всем репозиториям дерева, для каждого решаем "custom или base", затем говорим Nix явно, зафиксировав результат: `nix flake lock --override-input <name> "git+<url>?ref=<resolved-branch>"`. Сама Nix-сборка (`nix build`) после этого остаётся полностью чистой и детерминированной — она просто строит из уже резолвленного, зафиксированного набора коммитов.

Это ровно то, что делает `../examples/scripts/select-branch.sh`. Ключевая часть:

```bash
if git ls-remote --exit-code --heads "$url" "refs/heads/$CUSTOM_BRANCH" >/dev/null 2>&1; then
  branch="$CUSTOM_BRANCH"
else
  branch="$BASE_BRANCH"
fi
override_args+=(--override-input "$name" "git+${url}?ref=${branch}")
```

`git ls-remote --exit-code --heads <url> <ref>` возвращает код `0`, если ветка найдена, и `2`, если нет (без `--exit-code` пустой результат тоже даёт код `0`, что для проверки "существует ли" неудобно — поэтому флаг обязателен). Никакой Nix-специфики здесь нет — это обычная git-операция, работающая для GitHub и GitLab одинаково (и для self-hosted GitLab тоже, если URL — обычный git-URL, а не GitHub/GitLab REST API).

### Важное условие: дерево должно быть "выпрямлено" через `follows`

`--override-input` работает **только для input'ов верхнего уровня** того flake, для которого вы вызываете `nix flake lock`. Если в главе 06 вы настроили `inputs.libB.inputs.libC.follows = "libC";` в `app`, то `libC` виден как top-level input у `app`, и `--override-input libC ...`, вызванный из `app`, реально повлияет на весь `libB` тоже (потому что `libB` "follows" именно этот `libC`). Без `follows` `libC` был бы виден только как вложенный input внутри `libB`, и override с уровня `app` до него бы не достал — пришлось бы отдельно резолвить `libB`'s `flake.lock` до пуша, что ломает атомарность вашего требования "весь граф согласованно".

**Практический вывод**: если у вас реальное дерево из многих репозиториев, первым шагом (до написания branch-fallback скрипта) убедитесь, что *все* узлы дерева "подняты" в top-level inputs корневого flake через цепочку `follows` — иначе override с одной точки не покроет весь граф.

### Полный прогон

```bash
cd examples/app

# файл repos.txt (не в примерах — создаётся под ваше реальное дерево):
cat > repos.txt <<'EOF'
libB https://gitlab.com/your-org/libB.git
libC https://gitlab.com/your-org/libC.git
EOF

../scripts/select-branch.sh \
  --custom-branch special-123123_add_feature \
  --base-branch special \
  --repos repos.txt \
  -- .#default
```

Скрипт распечатает, какая ветка выбрана для каждого репозитория, вызовет `nix flake lock` со всеми `--override-input` сразу (это обновляет `flake.lock` **локально**, обычно не коммитится в CI-сценарии — см. главу 09) и затем `nix build .#default`.

### `--dry-run` — проверка логики без сети/Nix

Чтобы отладить саму логику выбора ветки без реального обращения к GitHub/GitLab и без установленного Nix, в скрипте есть `--dry-run` — он выполняет реальный `git ls-remote` (сеть нужна), но не запускает `nix flake lock`/`nix build`, просто печатает, что бы выполнилось. Мы проверили это на **полностью локальных** git-репозиториях (без сети вообще) командой:

```bash
# создаём два локальных репозитория: один с custom-веткой, другой без
git init -b special /tmp/repoWithCustom  && cd /tmp/repoWithCustom  && git commit --allow-empty -m base && git checkout -b special-123123_add_feature && git commit --allow-empty -m custom
git init -b special /tmp/repoWithoutCustom && cd /tmp/repoWithoutCustom && git commit --allow-empty -m base

cat > /tmp/repos.txt <<EOF
repoA file:///tmp/repoWithCustom
repoB file:///tmp/repoWithoutCustom
EOF

examples/scripts/select-branch.sh \
  --custom-branch special-123123_add_feature --base-branch special \
  --repos /tmp/repos.txt --dry-run
```

Ожидаемый (и реально проверенный при подготовке этого tutorial) вывод:

```
select-branch: repoA -> special-123123_add_feature  (file:///tmp/repoWithCustom)
select-branch: repoB -> special  (file:///tmp/repoWithoutCustom)
```

— то есть `repoA` (где custom-ветка существует) получает её, `repoB` (где её нет) падает обратно на `special`. Это именно та инвариантность, которая нужна для вашего сценария: "если ветки нет в конкретном репозитории — используем базовую **для этого конкретного репозитория**", не блокируя остальное дерево.

## Паттерн 2 (альтернативный): чистый Nix-трюк для non-flake `callPackage`-композиций

Если вы **не** используете flakes (классический `callPackage`/`default.nix`-стиль, глава 01), можно сделать branch-resolution прямо внутри `.nix`-выражения, но обязательно с явным `--impure`, потому что `builtins.fetchGit` без зафиксированного `rev` — impure операция (глава 03, fixed-output derivations):

```nix
let
  tryRef = { url, ref }:
    builtins.tryEval (builtins.fetchGit { inherit url ref; });

  fetchWithFallback = { url, customRef, baseRef }:
    let attempt = tryRef { inherit url; ref = customRef; };
    in if attempt.success
       then attempt.value
       else builtins.fetchGit { inherit url; ref = baseRef; };
in
fetchWithFallback {
  url = "https://gitlab.com/your-org/libB.git";
  customRef = "special-123123_add_feature";
  baseRef = "special";
}
```

`builtins.tryEval` перехватывает **ошибку evaluation** (в т.ч. ошибку из `fetchGit`, если удалённой ветки не существует) и возвращает `{ success = false; value = false; }` вместо аварийного завершения. Обязательное условие — запуск с `--impure`:

```bash
nix build --impure -f fallback-example.nix
```

Без `--impure` `fetchGit` с нефиксированным `ref` откажется работать вовсе (или потребует `allow-dirty`/`NIX_CONFIG` трюков), поэтому Nix явно заставляет вас признать, что тут есть сетевой side-effect в eval-time.

**Когда предпочесть паттерн 2**: если у вас нет flakes и/или вы строите динамическое дерево пакетов через `callPackage` (например, генерируете список зависимостей программно, а не декларативно в `inputs`). **Когда предпочесть паттерн 1**: почти всегда для flake-based деревьев (как в этом tutorial) — он не требует `--impure` вообще для самой сборки, оставляет `flake.lock` как явный, коммитируемый (или CI-артефактный) источник правды о том, что было реально собрано, и легко читается в логах CI (глава 09).

## Проверка себя

- Прогоните `select-branch.sh --dry-run` на собственных локальных тестовых репозиториях (как показано выше) — воспроизведите вывод самостоятельно.
- Объясните, почему `--override-input`, вызванный из `app`, не подействовал бы на `libC`, если бы в главе 06 не был настроен `follows`.
- Объясните, почему паттерну 2 обязательно требуется `--impure`, а паттерну 1 — нет (для самого `nix build`; сеть в паттерне 1 используется только в обычном shell-скрипте до вызова Nix).
- (Опционально) Замените в примере `app`/`libB`/`libC` `path:` inputs на реальные ваши GitHub/GitLab URL, создайте на них ветку `special-123123_add_feature` в одном репозитории и не создавайте в другом — прогоните `select-branch.sh` без `--dry-run` и убедитесь, что итоговая сборка взяла нужный код из каждого репозитория.

Следующая глава — общий механизм переопределений в nixpkgs (`overrideAttrs`, overlays), не про ветки, а про версии/патчи — важно не путать эти два разных вида "override".
