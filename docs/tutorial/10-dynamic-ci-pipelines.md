# Глава 10 — Динамический GitLab DAG-pipeline из графа Nix

Глава 09 показала общий принцип: порядок и параллелизм сборки определяет сам Nix, из графа derivations, а не CI. Эта глава — практическое применение для self-hosted GitLab CI: как получить этот граф из Nix в виде JSON, отфильтровать его до "своих" пакетов и **сгенерировать** GitLab CI YAML с одним job на узел дерева — так, чтобы независимые узлы реально собирались параллельно на разных раннерах, и чтобы это было видно в интерфейсе GitLab как DAG-pipeline.

## Зачем генерировать YAML, а не писать руками

Для дерева из трёх репозиториев (`app→libB→libC`, линейная цепочка) ручной YAML не проблема — он есть в `examples/ci/gitlab-ci.yml` из главы 09. Генерация становится нужна, когда:

- дерево реально **широкое** (не только `app→libB→libC`, но и `app→libD`, `libD` не зависящая ни от `libB`, ни от `libC`) — вручную поддерживать `needs:` для десятков узлов и не забывать его обновлять при каждом изменении `flake.nix` — источник рассинхронизации;
- вы хотите, чтобы граф в `needs:` **гарантированно совпадал** с тем, что реально соберёт Nix — единственный способ это гарантировать — вычислять `needs:` из того же графа derivations, а не дублировать его руками.

## Шаг 1 — получить граф derivations в JSON

```bash
nix derivation show -r .#app > graph.json
```

`-r`/`--recursive` — включить в вывод весь транзитивный набор input-derivations, не только прямые зависимости `app` (глава 09). Формат — JSON-объект, ключ — путь `.drv`, значение — `{ name, env, inputDrvs, inputSrcs, outputs, system, ... }`. Поле `env.pname`/`env.version` — то же, что вы явно указали в `pname`/`version` внутри `stdenv.mkDerivation` (глава 03) — по нему и будем фильтровать.

**Важно**: этот граф включает **весь** toolchain nixpkgs — `gcc`, `cmake`, `glibc`, десятки промежуточных bootstrap-пакетов. Для трёх ваших репозиториев в `graph.json` окажутся сотни записей. Следующий шаг — вырезать из этого шума именно ваши узлы.

## Шаг 2 — отфильтровать граф до своих пакетов и сгенерировать YAML

`examples/scripts/generate-dag-pipeline.sh` делает это одной командой: фильтрует записи по списку `pname` (`--names`) и для каждой из них оставляет только те `inputDrvs`, чей `pname` тоже в этом списке — то есть режет рёбра, ведущие к `gcc`/`cmake`, но оставляет рёбра между вашими репозиториями.

```bash
cd examples/app
../scripts/generate-dag-pipeline.sh \
  --installable .#app \
  --names "app,libB,libC" \
  --cache mycache \
  --out generated.yml
```

### Проверка логики без установленного Nix

Скрипт поддерживает `--graph-json <file>` вместо `--installable` — можно подать заранее посчитанный (или тестовый) JSON, минуя реальный `nix derivation show`. Мы проверили фильтрацию именно так: собрали руками JSON, имитирующий вывод `nix derivation show -r .#app` — три ваших узла (`app`, `libB`, `libC`) плюс "шумовые" `cmake`/`gcc` с перекрёстными `inputDrvs` — и прогнали через скрипт:

```bash
generate-dag-pipeline.sh --graph-json fake-graph.json \
  --names "app,libB,libC" --cache mycache --out generated.yml
```

Результат (реально полученный, не гипотетический):

```yaml
stages:
  - build

default:
  tags: [nix]
  before_script:
    - mkdir -p ~/.config/nix
    - echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    - nix run nixpkgs#cachix -- use "mycache"

build:libC:
  stage: build
  needs: []
  script:
    - nix build .#libC
    - nix run nixpkgs#cachix -- push "mycache" ./result

build:libB:
  stage: build
  needs: ["build:libC"]
  script:
    - nix build .#libB
    - nix run nixpkgs#cachix -- push "mycache" ./result

build:app:
  stage: build
  needs: ["build:libB"]
  script:
    - nix build .#app
    - nix run nixpkgs#cachix -- push "mycache" ./result
```

Ровно 3 job'а (не 5 — `gcc`/`cmake` корректно отрезаны), `needs:` верно отражает цепочку. Если бы в дереве был четвёртый узел `libD`, не зависящий ни от `libB`, ни от `libC`, в выводе появился бы `build:libD` с `needs: []` — GitLab запустит его параллельно с `build:libC` на любом свободном раннере, без дополнительной настройки с вашей стороны.

## Шаг 3 — подключить как dynamic child pipeline

Сгенерированный `generated.yml` не редактируется руками — он результат вычисления, actual source of truth — граф Nix. В основном `.gitlab-ci.yml` репозитория `app` он подключается через child pipeline:

```yaml
stages:
  - generate
  - trigger

generate-pipeline:
  stage: generate
  image: nixos/nix:latest
  before_script:
    - mkdir -p ~/.config/nix
    - echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    - nix-env -iA nixpkgs.jq   # jq нужен скрипту-генератору
  script:
    - ./examples/scripts/generate-dag-pipeline.sh
        --installable .#app
        --names "app,libB,libC"
        --cache mycache
        --out generated.yml
  artifacts:
    paths: [generated.yml]

trigger-build:
  stage: trigger
  trigger:
    include:
      - artifact: generated.yml
        job: generate-pipeline
    strategy: depend   # родительский pipeline ждёт завершения дочернего и наследует его статус
```

`generate-pipeline` вычисляет граф и публикует `generated.yml` как артефакт; `trigger-build` запускает его как **child pipeline** — именно это делает граф видимым в GitLab UI как отдельный, визуализированный DAG (вкладка pipeline, граф зависимостей между job'ами), а не как последовательный список шагов одного job.

## Обязательное условие: binary cache между job'ами

Отдельные GitLab-раннеры не делят `/nix/store`. Без `nix run nixpkgs#cachix -- use "$CACHE"` в `before_script` (уже вставлено генератором в `default:`) job `build:app` на другом раннере просто пересоберёт `libB`/`libC` с нуля — весь смысл распределения по раннерам теряется. `cachix use` настраивает `substituter`+`trusted-public-key` за одну команду — тот же эффект, что ручное редактирование `nix.conf` из главы 09, но без явного файла.

## Проверка себя

- Прогоните `generate-dag-pipeline.sh --graph-json ...` на собственном тестовом графе с добавленным независимым узлом `libD` — убедитесь, что он получает `needs: []`, как `libC`.
- Объясните, почему `generate-pipeline` (шаг, вычисляющий граф) должен идти **раньше** стадии `trigger`, а не быть частью одного job.
- Объясните, что произойдёт, если убрать `cachix use` из `before_script` сгенерированного pipeline — что изменится в поведении `build:app`, но не в его успешности (сборка всё равно завершится, просто медленнее).
- (Опционально) Подключите реальный Cachix-кеш и прогоните полный цикл: `generate-pipeline` → `trigger-build` → убедитесь в GitLab UI, что pipeline отображается как граф, а не как линейный список.

Следующая, заключительная глава — список более продвинутых тем для дальнейшего самостоятельного изучения.
