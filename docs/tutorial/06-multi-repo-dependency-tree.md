# Глава 06 — Дерево репозиториев: `app → libB → libC`

Это глава, которая напрямую отвечает на ваш реальный кейс: несколько отдельных git-репозиториев (GitHub/GitLab), каждый — свой C++ проект, зависящие друг от друга. Разбираем `../examples/{libC,libB,app}`.

> Nix сейчас не установлен на этой машине (`nix: command not found`), поэтому примеры в этой главе написаны и логически проверены, но не прогнаны через `nix build`. Как только установите Nix (глава 01), выполните раздел "Собрать всё дерево" ниже и сверьтесь с ожидаемым выводом.

## Граф зависимостей

```
app  --(inputs.libB)-->  libB  --(inputs.libC)-->  libC
 \                                                    ^
  \--(inputs.libC, через follows)---------------------/
```

`app` зависит от `libB` напрямую. `libB` зависит от `libC` напрямую. `app` **транзитивно** зависит от `libC` — и именно здесь возникает вопрос, который часто ломает голову новичкам: "чей именно `libC` в итоге использует `app` — свой или тот, что притащила `libB`?"

## `buildInputs` vs `propagatedBuildInputs` — вторая критичная пара после `nativeBuildInputs`/`buildInputs`

В `examples/libB/flake.nix`:

```nix
propagatedBuildInputs = [ libC.packages.${system}.default ];
```

а не `buildInputs`. Разница:

- **`buildInputs`** — зависимость видна **только во время сборки самого этого пакета**. Если `app` зависит от `libB` через `buildInputs`, а `libB` использует `libC` через `buildInputs`, то при конфигурации `app` его CMake **не увидит** `libC` в `CMAKE_PREFIX_PATH` — а `libBConfig.cmake` внутри делает `find_dependency(libC)`, которая упадёт.
- **`propagatedBuildInputs`** — зависимость "протекает" (propagate) дальше, ко всем, кто зависит от текущего пакета. Nix добавит `libC` в `CMAKE_PREFIX_PATH`/окружение и у `libB`, и у всех, кто зависит от `libB` (то есть у `app`), а также включит `libC` в rpath/closure финального бинарника автоматически.

Практическое правило для C++ библиотек, оформляемых как Nix-пакеты: если библиотека **выставляет** зависимость наружу через заголовки/линковку (public dependency в терминах CMake `target_link_libraries(... PUBLIC ...)`), она должна быть `propagatedBuildInputs`, а не просто `buildInputs`. Если зависимость нужна только внутри (`PRIVATE` в CMake) — обычный `buildInputs` достаточен.

## `inputs.follows` — почему он обязателен в дереве с общими зависимостями

Без `follows` в `examples/app/flake.nix`:

```nix
inputs.libB.url = "path:../libB";
```

`libB` внутри себя резолвит **свой собственный** `libC` (согласно `libB/flake.lock`), а `app` резолвит **свой** `libC` — это могут быть два разных коммита/версии `libC`, если репозитории обновлялись не синхронно. Получится два разных `libC` в одном дереве сборки — в лучшем случае лишняя пересборка, в худшем — конфликт ABI/ODR, если оба попадут в один бинарник.

С `follows`:

```nix
libB = {
  url = "path:../libB";
  inputs.libC.follows = "libC";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

`app` явно говорит: "когда `libB` просит свой `libC`, дай ей МОЙ `libC`". Теперь во всём дереве ровно один `libC`. Тот же приём применяется к `nixpkgs` — без `follows.nixpkgs` каждый repo может тащить свою версию `nixpkgs`, а это лишние гигабайты пересборок и потенциально другая версия компилятора/системных библиотек на разных узлах дерева.

**Правило масштабирования**: чем больше репозиториев в дереве, тем важнее централизовать `nixpkgs` и общие библиотеки через `follows` на самом верхнем flake — иначе граф `flake.lock` разрастается экспоненциально с дублирующимися версиями.

## Git-источники: GitHub, GitLab, публичные и приватные

В примерах используется `path:../libB` для локальной разработки. В реальном дереве репозиториев на GitHub/GitLab:

```nix
# GitHub, публичный репозиторий, конкретная ветка
libB.url = "github:your-org/libB/special";

# То же самое явной git+https-схемой (нужно для GitLab, т.к. у "gitlab:" схемы есть нюансы с self-hosted)
libB.url = "git+https://gitlab.com/your-org/libB.git?ref=special";

# Приватный репозиторий по SSH — использует ваш локальный ssh-agent/known_hosts
libB.url = "git+ssh://git@gitlab.com/your-org/libB.git?ref=special";

# Зафиксировать точный коммит вместо ветки (максимально воспроизводимо руками, без flake.lock resolution)
libB.url = "git+https://gitlab.com/your-org/libB.git?rev=8f14e45fceea167a5a36dedd4bea2543";
```

### Аутентификация к приватным репозиториям

Nix резолвит git-inputs через обычный `git`, поэтому аутентификация настраивается на уровне git/SSH, а не внутри `flake.nix`:

- **SSH** (`git+ssh://`) — работает "из коробки", если у вас настроен `ssh-agent` с ключом, у которого есть доступ к репозиторию, и хост есть в `~/.ssh/known_hosts`. Для CI — см. главу 09 (deploy keys, `ssh-agent` в job).
- **HTTPS + Personal Access Token** (`git+https://`) — два варианта:
  1. `~/.netrc`:
     ```
     machine gitlab.com
     login your-username
     password glpat-xxxxxxxxxxxxxxxxxxxx
     ```
     Git (и, соответственно, Nix при резолве `git+https` input) автоматически подхватит эти креды.
  2. Настройка `access-tokens` прямо в `nix.conf` (полезно, когда `.netrc` не хочется трогать, либо для GitHub API rate-limit токена):
     ```
     # ~/.config/nix/nix.conf
     access-tokens = github.com=ghp_xxxxxxxxxxxxxxxxxxxx gitlab.com=glpat-xxxxxxxxxxxxxxxxxxxx
     ```

- Для чисто публичных репозиториев (как в вашем случае — "Публичные репозитории" были одним из ответов) аутентификация не нужна вовсе, `github:`/`gitlab:`/`git+https://` работают анонимно, с ограничением по rate-limit у GitHub API для схемы `github:` (у `git+https://` через обычный git clone таких лимитов нет).

## Собрать всё дерево

```bash
cd examples/app
nix build
./result/bin/app
# ожидаемый вывод: "libB says: [hello from libC (base)]"
```

Если хотите проверить именно межрепозиторную композицию (а не просто одну сборку), временно измените `examples/libC/src/libC.cpp` (например, поменяйте текст в `greet()`), затем в `examples/app`:

```bash
nix flake lock --update-input libC   # т.к. path: input не обновляется автоматически как git ref
nix build
./result/bin/app                      # текст должен измениться
```

Это наглядно показывает: `app` не хардкодит `libC` — он получает её через `libB` (`propagatedBuildInputs`) и `follows`, и любое изменение в `libC` протекает по всему дереву при обновлении lock-файлов.

## Проверка себя

- Объясните, почему `libB` использует `propagatedBuildInputs`, а не `buildInputs`, для `libC`.
- Объясните, что изменится в дереве `flake.lock`, если убрать `inputs.libB.inputs.libC.follows = "libC";` из `app`.
- Напишите (на бумаге, не обязательно выполняя) команду `nix flake lock --override-input libB ...`, которая заставит `app` использовать другую ветку `libB` без правки `flake.nix` — это прямой мостик к следующей главе.

Следующая глава — то, ради чего, скорее всего, был весь этот tutorial: автоматический выбор custom-ветки во всём дереве с fallback на базовую.
