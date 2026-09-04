# Глава 03 — Derivations и `stdenv.mkDerivation`

## Что такое derivation "снизу"

`builtins.derivation` — низкоуровневый примитив, из которого всё строится:

```nix
derivation {
  name = "hello";
  system = builtins.currentSystem;
  builder = "/bin/sh";
  args = [ "-c" "echo hi > $out" ];
}
```

Это описывает: запустить `/bin/sh -c "echo hi > $out"` в песочнице, положить результат в новый store-путь, доступный внутри builder-а через переменную `$out`. Практически никто не пишет `derivation {}` напрямую — вместо этого используют `stdenv.mkDerivation`, который добавляет вокруг этого примитива стандартный жизненный цикл сборки (распаковка исходников, `./configure`, `make`, `make install` и т.п.) и десятки удобств.

## `stdenv.mkDerivation` и фазы

```nix
{ stdenv, cmake }:

stdenv.mkDerivation {
  pname = "hello-cpp";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [ cmake ];
}
```

По умолчанию `mkDerivation` выполняет последовательность **фаз**, каждая — переопределяемый shell-хук:

| Фаза | Что делает по умолчанию |
|------|--------------------------|
| `unpackPhase` | распаковывает/копирует `src` в `$TMPDIR`, `cd` туда |
| `patchPhase` | применяет `patches`, если заданы |
| `configurePhase` | если есть `CMakeLists.txt` — запускает `cmake`; если `configure` — запускает его |
| `buildPhase` | `make` (или `cmake --build .`, если stdenv определил CMake-проект) |
| `checkPhase` | тесты, только если `doCheck = true;` |
| `installPhase` | `make install` (обычно требует явного `installPhase`, если Makefile не поддерживает `install`) |
| `fixupPhase` | пост-обработка: strip, патчинг rpath и т.д. |

Каждую фазу можно переопределить целиком (`installPhase = '' ... '';`) или дополнить хуками `preConfigure`/`postInstall` и т.п. — это стандартный способ "подсунуть" произвольную shell-логику в процесс сборки.

## `buildInputs` vs `nativeBuildInputs`

Это разделение — одна из самых частых точек путаницы у новичков, и оно принципиально для C++ с кросс-компиляцией (даже если вы её пока не используете):

- **`nativeBuildInputs`** — инструменты, которые **выполняются во время сборки** на машине-сборщике: компилятор, `cmake`, `pkg-config`, `make`. Их платформа (`system`) — платформа **сборщика**.
- **`buildInputs`** — библиотеки, с которыми линкуется/от которых зависит **результат**: `boost`, `zlib`, ваша `libB`. Их платформа — платформа **цели** (host).

При обычной (не кросс-) сборке разница незаметна — обе категории имеют одну и ту же платформу. Она становится критичной при кросс-компиляции (глава 11): `nativeBuildInputs` всегда собраны "как для сборщика", `buildInputs` — "как для целевой платформы". Если положить `cmake` в `buildInputs` вместо `nativeBuildInputs`, в кросс-сборке Nix попытается собрать `cmake` **для целевой платформы**, что почти наверняка не нужно и может не работать вовсе.

Практическое правило: если пакет нужен, чтобы **запустить** его во время сборки — `nativeBuildInputs`. Если он нужен, чтобы **слинковаться/подключить заголовки** — `buildInputs`.

## Fixed-output derivations (FOD)

Обычная derivation собирается в полностью изолированной песочнице без сети. Но что, если сборке **нужна** сеть — например, `fetchurl`, `fetchGit` с фиксированным `rev`? Для этого есть особая категория — fixed-output derivation: Nix заранее знает **хеш ожидаемого результата** (`sha256`/`hash`) и разрешает сеть внутри такой derivation, потому что после сборки хеш результата всё равно проверяется — если он не совпал, сборка считается упавшей. Purity не нарушается: результат детерминирован не изоляцией процесса, а проверкой хеша.

Это именно то, что происходит внутри `fetchFromGitHub`/`fetchFromGitLab`/`fetchGit` с зафиксированным `rev` — сеть внутри FOD разрешена, потому что нужный content-hash уже известен заранее. Это важно держать в голове для главы 07: когда `rev` (коммит) не зафиксирован явно, а указан лишь `ref` (имя ветки) — Nix не может заранее знать хеш результата, и такая операция **не** является FOD, а требует `--impure` (обычный сетевой side-effect, а не детерминированный fetch).

## Ручная практика: собрать один `.cpp`-файл через `mkDerivation` без flake

Создайте временную директорию (не обязательно внутри `examples/` — это чисто учебное упражнение):

```
mkdir -p /tmp/nix-hello && cd /tmp/nix-hello
cat > hello.cpp <<'EOF'
#include <iostream>
int main() { std::cout << "hello from nix\n"; }
EOF

cat > default.nix <<'EOF'
{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  pname = "hello-manual";
  version = "1.0";
  src = ./.;

  dontUnpack = true;   # src уже лежит рядом, не архив — отключаем unpackPhase

  buildPhase = ''
    g++ -O2 -o hello ${./hello.cpp}
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp hello $out/bin/
  '';
}
EOF

nix-build default.nix
./result/bin/hello
```

Здесь используется классический `nix-build` (не flake) специально, чтобы увидеть механику без слоя flakes сверху — `$out` — это переменная, которую подставляет Nix, указывающая на итоговый store-путь; всё, что должно попасть "в результат", нужно явно скопировать туда в `installPhase`.

Если получили `hello from nix` — значит вы только что вручную прошли через `configurePhase`(пропущена, т.к. нет CMake/configure) → `buildPhase` → `installPhase`, то есть именно то, что `cmake`-обёртка будет делать автоматически в главе 05.

## Проверка себя

- Объясните своими словами, зачем `nativeBuildInputs` разделён от `buildInputs`, если на вашей машине разницы не видно.
- Объясните, почему `fetchGit { url = ...; ref = "main"; }` (без `rev`) требует `--impure`, а `fetchGit { url = ...; rev = "abcdef..."; }` — не требует.
- Соберите пример выше, затем измените `hello.cpp` и повторите `nix-build` — убедитесь, что появился **новый** путь в `/nix/store`, а старый остался (до `nix-collect-garbage`).
