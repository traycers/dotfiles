# Глава 05 — Один CMake C++ проект как flake

Разбираем `../examples/libC` — самый нижний узел будущего дерева `app → libB → libC`. Это классическая CMake-библиотека, экспортирующая нормальный `find_package`-конфиг, — то есть построена так, как строится настоящая C++ библиотека, а не учебный "плоский" пример.

## Структура

```
examples/libC/
  CMakeLists.txt         — сборка + install + экспорт CMake package config
  libCConfig.cmake.in     — шаблон конфига для find_package(libC)
  include/libC/libC.hpp   — публичный заголовок
  src/libC.cpp            — реализация
  flake.nix               — Nix-обёртка
```

## Почему CMake package config, а не просто "скопировать файлы"

`install(EXPORT libCTargets ...)` + `configure_package_config_file` генерируют `libCConfig.cmake` — файл, который умеет ответить на `find_package(libC REQUIRED)` из **другого** CMake-проекта, включая правильные include-пути и флаги линковки, без хардкода абсолютных путей. Это именно то, что понадобится `libB` в главе 06, чтобы подключить `libC` не через ручные `-I`/`-L`, а штатным CMake-механизмом — ровно так это делается в реальных проектах с внешними зависимостями (Boost, OpenSSL, protobuf и т.п. предоставляют такие же конфиги).

## `flake.nix` построчно

```nix
packages.${system}.default = pkgs.stdenv.mkDerivation {
  pname = "libC";
  version = "1.0.0";
  src = self;
  nativeBuildInputs = [ pkgs.cmake ];
};
```

- `src = self;` — `self` в контексте flake — это сам этот flake, то есть весь репозиторий `examples/libC` (с точностью до `.gitignore`-подобной фильтрации, если используется `git`-источник — Nix копирует только то, что попало под git tracking, если flake взят из git-репозитория; при локальной разработке через `path:` копируется всё, что не проигнорировано).
- `nativeBuildInputs = [ pkgs.cmake ];` — как в главе 03: `cmake` **выполняется** во время сборки, значит это `nativeBuildInputs`, не `buildInputs`.
- Ни `configurePhase`, ни `buildPhase`, ни `installPhase` не переопределены явно — `stdenv.mkDerivation` **автоматически определяет CMake-проект** по наличию `CMakeLists.txt` в `src` и подставляет `cmake`/`cmake --build`/`cmake --install` фазы сам, благодаря setup-hook, который приносит с собой `pkgs.cmake`. Это стандартное поведение nixpkgs-обёртки cmake, а не что-то, что вы должны писать руками каждый раз.

## Собрать и проверить

```bash
cd examples/libC
nix build
ls result/lib
ls result/lib/cmake/libC          # тут окажется libCConfig.cmake — то, что подключит libB
```

`nix build` без аргументов собирает `packages.${system}.default`. `result` — симлинк на store-путь (GC root, см. главу 01) — удобно, чтобы быстро смотреть содержимое последней сборки.

## devShell — окружение для разработки без пересборки через Nix каждый раз

```bash
nix develop
cmake -B build && cmake --build build
```

`devShells.${system}.default` не собирает пакет — он просто даёт shell с `cmake`/`gcc`/`gdb` в `PATH`, чтобы вы могли работать с проектом привычным способом (в IDE, с быстрыми инкрементальными пересборками), а `nix build` использовать только для финальной, воспроизводимой сборки — например, перед коммитом или в CI.

## Проверка себя

- Соберите `examples/libC` через `nix build`, убедитесь, что `result/lib/cmake/libC/libCConfig.cmake` существует.
- Измените текст в `greet()` (`src/libC.cpp`), пересоберите — убедитесь, что `result` теперь указывает на **новый** store-путь (`readlink result` до и после).
- Зайдите в `nix develop` и соберите проект обычным `cmake`/`make`, минуя `nix build` — убедитесь, что разница понятна: `nix build` — воспроизводимо и изолированно, `nix develop` + `cmake` руками — быстрая итерация при разработке.

Следующая глава — подключаем `libC` как зависимость из `libB`, а `libB` — из `app`, формируя настоящее дерево репозиториев.
