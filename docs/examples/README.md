# Examples — дерево `app → libB → libC`

Рабочий код, сопровождающий `../tutorial/`. Три учебных CMake C++ проекта, имитирующих дерево зависимостей из отдельных git-репозиториев:

```
libC/   — листовая библиотека (см. tutorial/05-cpp-single-project.md)
libB/   — зависит от libC (см. tutorial/06-multi-repo-dependency-tree.md)
app/    — исполняемый проект, зависит от libB, транзитивно от libC
scripts/select-branch.sh — branch-fallback логика (см. tutorial/07-branch-override-fallback.md)
ci/     — шаблоны пайплайнов (см. tutorial/09-ci-and-caching.md)
```

## Запуск как есть (локальные `path:` inputs)

Сейчас `libB/flake.nix` и `app/flake.nix` ссылаются друг на друга через `path:../libB` / `path:../libC` — то есть три "репозитория" на самом деле лежат рядом на диске и трактуются Nix как если бы это были три соседних чекаута реальных git-репозиториев. Это специально сделано так, чтобы можно было собрать всё дерево прямо здесь, без пуша в GitHub/GitLab:

```bash
cd app
nix build
./result/bin/app
# hello from libC (base) -> оборачивается libB -> печатается app
```

## Перенос в реальные GitHub/GitLab репозитории

Когда вы будете переносить этот пример (или свои реальные проекты) в настоящие отдельные git-репозитории:

1. Каждая директория (`libC/`, `libB/`, `app/`) становится **отдельным git-репозиторием** со своим `flake.nix`, закоммиченным `flake.lock` после первого `nix build`.
2. В `libB/flake.nix` и `app/flake.nix` замените:
   ```nix
   libC.url = "path:../libC";
   ```
   на реальный адрес:
   ```nix
   libC.url = "github:your-org/libC/special";
   # или для GitLab:
   libC.url = "git+https://gitlab.com/your-org/libC.git?ref=special";
   ```
3. Сохраните структуру `inputs.libB.inputs.libC.follows = "libC";` в `app/flake.nix` — без неё дерево может резолвить два разных `libC` (глава 06).
4. Убедитесь, что `access-tokens`/SSH настроены, если репозитории приватные (глава 06, раздел "Аутентификация").
5. Для branch-fallback по custom-ветке во всём дереве — используйте `scripts/select-branch.sh` с `repos.txt`, перечисляющим реальные URL (глава 07).

## Проверка каждого шага отдельно

```bash
cd libC && nix build && ls result/lib/cmake/libC   # должен быть libCConfig.cmake
cd ../libB && nix build && ls result/lib             # libB.a/.so + cmake/libB/libBConfig.cmake
cd ../app && nix build && ./result/bin/app          # финальный исполняемый файл, использующий обе библиотеки
```

Если Nix ещё не установлен на вашей машине — сначала пройдите `tutorial/01-install-and-basics.md`.
