# Глава 04 — Flakes

## Зачем flakes

Классический Nix (`nix-build`, `<nixpkgs>`, channels) не фиксирует версии зависимостей нигде, кроме глобального состояния канала пользователя — воспроизводимость "по факту", а не гарантированная. Flakes добавляют:

- явный список `inputs` (откуда брать зависимости — nixpkgs, другие flakes, git-репозитории);
- `flake.lock` — файл, фиксирующий **точные** ревизии всех inputs (аналог `package-lock.json`/`Cargo.lock`);
- стандартизированную форму `outputs` (что этот flake предоставляет — пакеты, devShells, приложения...).

Для вашего кейса (дерево C++ репозиториев, требующее воспроизводимости и явного контроля версий) flakes — правильный выбор именно из-за `flake.lock` и `inputs.follows` (ниже).

## Анатомия `flake.nix`

```nix
{
  description = "Пример flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system}.default = pkgs.hello;

      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.cmake pkgs.gcc ];
      };
    };
}
```

- **`inputs`** — attrset, где ключ — произвольное имя, значение — либо `{ url = "..."; }`, либо просто строка-URL (сахар). Схема URL: `github:owner/repo/ref`, `gitlab:owner/repo/ref`, `git+https://...`, `git+ssh://...`, `path:../relative`.
- **`outputs`** — функция от attrset входов (имена = имена из `inputs`, плюс `self` — сам этот flake) к attrset "того, что flake предоставляет". Здесь напрямую применяется всё из главы 02: это обычная функция с деструктуризацией аргумента.
- **Стандартные output-схемы**, которые понимает `nix` CLI:
  - `packages.<system>.<name>` — то, что собирается через `nix build .#<name>` (`default` — то, что собирается через просто `nix build`).
  - `devShells.<system>.<name>` — окружение для `nix develop`.
  - `apps.<system>.<name>` — то, что запускается через `nix run .#<name>`.
  - `checks.<system>.<name>` — тесты/проверки для `nix flake check`.

## `flake.lock`

Первый `nix build`/`nix flake lock` создаёт `flake.lock` — JSON с точным `rev` (коммит), `narHash` (хеш контента) для каждого input. Дальнейшие сборки используют **зафиксированные** версии из `flake.lock`, а не "текущий HEAD ветки", даже если в `inputs` указан `ref` на ветку (например `github:org/libB/special`) — ветка резолвится в конкретный коммит **один раз**, при генерации/обновлении lock-файла.

Это критично для главы 07: если вы просто укажете `ref = "special"` в `inputs`, обычный `nix build` **не** будет каждый раз проверять, обновилась ли ветка — он возьмёт коммит из `flake.lock`. Чтобы обновить — явно:

```bash
nix flake lock --update-input libB       # обновить именно libB на актуальный HEAD её ref
nix flake update                          # обновить вообще все inputs
```

`flake.lock` должен коммититься в git репозитория — это часть контракта воспроизводимости: у любого, кто клонирует репозиторий, будет тот же самый набор зависимостей, что и у автора, пока кто-то явно не обновит lock.

## `inputs.follows` — унификация версий

Когда `app` зависит от `libB`, а `libB` сама зависит от `libC`, у `app` в её `inputs` может появиться *своя, независимая* копия `libC` (через транзитивный `inputs` внутри `libB`), которая может не совпадать с тем `libC`, который использует сам `app` напрямую (если он тоже зависит от неё напрямую). Diamond-dependency проблема — та же самая, что в npm/cargo с разными версиями одного пакета в дереве.

`follows` заставляет input использовать **тот же** input, что и другой узел графа:

```nix
inputs = {
  libC.url = "github:org/libC";

  libB = {
    url = "github:org/libB";
    inputs.libC.follows = "libC";   # заставить libB использовать НАШ libC, а не свой собственный
  };
};
```

Подробный пример с реальным деревом `app → libB → libC` — в главе 06, где это будет применено к настоящим C++ flakes, а не к абстрактному примеру.

## `path:` inputs для локальной разработки

```nix
inputs.libB.url = "path:../libB";
```

Полезно, когда вы разрабатываете несколько репозиториев одновременно на одной машине и не хотите пушить каждое изменение в git, чтобы проверить сборку целиком. `path:` input **не** зафиксирован в `flake.lock` детерминированно content-hash'ем внешнего репозитория — Nix просто читает файлы с диска. Это удобно для разработки, но не должно попадать в финальную конфигурацию, которую вы разворачиваете в CI (там нужны настоящие `github:`/`gitlab:`/`git+https:` ссылки — см. `examples/README.md` и главу 06).

## Основные команды

```bash
nix flake show               # показать дерево outputs без сборки
nix flake check               # прогнать checks + убедиться, что все outputs evaluable
nix flake lock                 # создать/обновить flake.lock без сборки
nix flake metadata             # показать resolved inputs (какие именно rev зафиксированы)
nix build .#foo               # собрать outputs.packages.<system>.foo
nix develop                   # войти в outputs.devShells.<system>.default
nix run .#foo                 # собрать и сразу запустить outputs.apps.<system>.foo
```

## Проверка себя

- Создайте минимальный `flake.nix` с `packages.default = pkgs.hello;`, соберите `nix build`, проверьте `./result/bin/hello`.
- Откройте сгенерированный `flake.lock`, найдите поле `rev` для `nixpkgs` — убедитесь, что это конкретный git-коммит, а не имя ветки.
- Объясните своими словами: почему `nix build` на чужой машине с тем же `flake.lock` детерминированно даст тот же результат (с точностью до содержимого store), а без `flake.lock` — не гарантированно.

Следующая глава — первый реальный C++ пример, `examples/libC`.
