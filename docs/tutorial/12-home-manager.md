# Глава 12 — home-manager

Отдельная от основной серии (01–11) тема: там речь шла о **сборке C++ проектов** через Nix. Здесь — про **управление пользовательским окружением** (пакеты, dotfiles, шрифты) на не-NixOS машине. Это именно то, что использовано в корне этого репозитория: `flake.nix`, `home/common.nix`, `home/laptop.nix`, `home/work.nix` — рабочий пример, не абстрактный.

## Зачем home-manager, если не NixOS

На NixOS всей системой — включая пользовательское окружение — управляет один системный конфиг (`/etc/nixos/configuration.nix`) через модуль `home-manager.users.<name>`. На обычном дистрибутиве (Ubuntu, любой другой) системой управляет её штатный пакетный менеджер (`apt` и т.п.), а Nix стоит поверх как *дополнительный* пакетный менеджер — только для пользователя, без прав на системные файлы.

home-manager в **standalone**-режиме — это способ декларативно описать:

- какие пакеты доступны пользователю (`home.packages`), не трогая `apt`;
- конфиги приложений в `$HOME` (`programs.*`), не трогая `/etc`;
- шрифты, переменные окружения, dotfiles — всё, что раньше делалось руками или скриптом вроде старого `install.sh` + `stow`.

Ключевое отличие от голого `nix profile install`: home-manager версионирует **весь набор** как одну сущность (generation) — можно откатить разом всё, а не гадать, какой пакет был установлен когда.

## `homeManagerConfiguration` в standalone-режиме

Без NixOS home-manager вызывается не как модуль системы, а как отдельная функция `home-manager.lib.homeManagerConfiguration`, которой нужно явно передать `pkgs` (в NixOS-варианте `pkgs` берётся из системного конфига автоматически):

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";   # см. главу 04 — унификация версий
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."<имя>" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
```

`homeConfigurations.<имя>` — не стандартная flake output-схема вроде `packages`/`devShells` из главы 04 (`nix` CLI её не знает "из коробки"), это соглашение самого home-manager: команда `home-manager switch --flake .#<имя>` ищет именно этот путь.

## Анатомия `home.nix`

```nix
# home/common.nix (реальный файл этого репозитория)
{ pkgs, ... }:
{
  home.username = "aldishu";
  home.homeDirectory = "/home/aldishu";
  home.stateVersion = "24.11";   # версия схемы опций — см. ниже

  home.packages = with pkgs; [
    alacritty
    neovim
    tmux
    fzf
    ripgrep
  ];

  fonts.fontconfig.enable = true;
  programs.home-manager.enable = true;
}
```

- **`home.stateVersion`** — не версия home-manager и не версия nixpkgs, а "версия поведения" опций на момент, когда вы начали использовать home-manager. Фиксируется один раз при первой установке и **не меняется** при обновлениях — так home-manager знает, какое поведение конкретной опции ожидать, даже если апстрим позже поменял дефолты. Смотреть текущее актуальное значение для новых конфигов — в релиз-нотах home-manager.
- **`home.packages`** — список пакетов, которые появятся в `$HOME`-профиле пользователя (аналог `environment.systemPackages` в NixOS, но per-user и без root).
- **`programs.<name>.enable = true`** — модули более высокого уровня, чем просто "поставить пакет": они и ставят программу, и генерируют её конфиг-файл из Nix-опций. Например, `programs.git.enable = true; programs.git.userName = "...";` сам сгенерирует `~/.gitconfig` — не нужно ни stow, ни ручного symlink'а. `home.packages` этого не делает — только кладёт бинарник в `PATH`.
- **`programs.home-manager.enable = true`** — включает саму утилиту `home-manager` как пакет в профиле, чтобы дальше можно было вызывать `home-manager switch` не через `nix run home-manager/master`, а напрямую.

## Несколько машин из одного flake

Реальный кейс этого репозитория: домашний ноут на niri (wlroots-стек), рабочая машина на Ubuntu + GNOME. Общее выносится в `common.nix`, различия — в отдельные host-файлы, которые импортируют общее:

```
home/
  common.nix   — пакеты и настройки, нужные везде (nvim, tmux, fzf, шрифты...)
  laptop.nix   — imports common.nix + niri, waybar, mako, fuzzel, swaylock...
  work.nix     — imports common.nix, ничего сверху (GNOME остаётся системным)
```

```nix
# home/laptop.nix
{ pkgs, ... }:
{
  imports = [ ./common.nix ];
  home.packages = with pkgs; [ niri fuzzel waybar mako swappy swayidle swaylock ];
}
```

Важная деталь механики (глава 02 — модульная система): `home.packages`, объявленный и в `common.nix`, и в `laptop.nix`, **не конфликтует** и не перезаписывается — опции типа "список" (`listOf`) при подключении нескольких модулей **сливаются** (конкатенация списков), а не берут последнее значение. Это отличается от опций-скаляров (`home.stateVersion`, `home.username`), где повторное определение в двух модулях — ошибка (`error: The option ... has conflicting definitions`), если явно не обёрнуто в `lib.mkForce`/`lib.mkDefault`.

В `flake.nix` каждому host-файлу соответствует свой `homeConfigurations`:

```nix
homeConfigurations = {
  "aldishu-laptop" = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [ ./home/laptop.nix ];
  };
  "aldishu-work" = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [ ./home/work.nix ];
  };
};
```

## Активация и generations

```bash
# первый запуск на новой машине — без предустановленного home-manager
nix run home-manager/master -- switch --flake .#aldishu-laptop

# дальше, когда programs.home-manager.enable уже применился:
home-manager switch --flake .#aldishu-laptop

home-manager generations          # список предыдущих состояний с датами
/nix/store/.../activate           # у каждой generation свой activation-скрипт — так делается откат
```

Как и generations в NixOS, каждое применение home-manager — новый, независимый снимок всего окружения в Nix store. Откат — не "накатить старый конфиг заново", а просто активировать старую generation; ничего не пересобирается.

## Unfree-пакеты

По умолчанию `nixpkgs` отказывается собирать пакеты с несвободной лицензией (`error: ... has an unfree license`). Разрешать стоит точечно, а не глобально — `config.allowUnfreePredicate` вместо `config.allowUnfree = true`:

```nix
pkgs = import nixpkgs {
  inherit system;
  config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
    "vscode"
  ];
};
```

Так `vscode` соберётся, а любой другой случайно затянутый unfree-пакет — по-прежнему упадёт с ошибкой, а не тихо установится.

## Что НЕ входит в home-manager

home-manager управляет только тем, что живёт в `$HOME` и не требует root. Он не может:

- поставить системный демон с systemd-юнитом (Docker Engine, printer daemon) — это `apt`/системный менеджер;
- зарегистрировать сессию в display manager'е (`/usr/share/wayland-sessions/*.desktop` для niri) — тоже системный уровень;
- управлять программами с собственным автообновлятелем, не совместимым с неизменяемым `/nix/store` (Yandex Browser и подобные Chromium-форки) — их логичнее ставить нативно.

Граница простая: если действию нужен `sudo` или запись вне `$HOME` — это не задача home-manager.

## Проверка себя

- Объясните разницу между `home.packages = [ pkgs.git ]` и `programs.git.enable = true` — когда какой вариант нужен.
- Почему `home.packages`, определённый в двух разных модулях (`common.nix` и `laptop.nix`), не считается конфликтом, а `home.stateVersion` в двух модулях — считается?
- Что произойдёт, если поменять `home.stateVersion` на более новую версию на уже настроенной машине — почему это не всегда безопасно "просто сделать"?
- Соберите `nix build .#homeConfigurations.<имя>.activationPackage` без применения (`home-manager switch` его тоже собирает, но эта команда — только сборка, без активации) — так проверяется, что конфиг вообще evaluable, прежде чем реально накатывать его на машину.

Дальше по теме — официальный manual: <https://nix-community.github.io/home-manager/options.xhtml> (полный список опций `programs.*`) и `man home-configuration.nix` после первой установки.
