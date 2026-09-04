{
  description = "libB — зависит от libC, сама является зависимостью app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Для локальной разработки удобно ссылаться на соседнюю директорию.
    # В реальном дереве репозиториев замените на:
    #   libC.url = "git+https://github.com/your-org/libC.git?ref=special";
    #   libC.url = "git+https://gitlab.com/your-org/libC.git?ref=special";
    # (подробности аутентификации и выбора ветки — главы 06 и 07)
    libC.url = "path:../libC";
  };

  outputs = { self, nixpkgs, libC, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems f;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "libB";
            version = "1.0.0";
            src = self;

            nativeBuildInputs = [ pkgs.cmake ];
            # propagatedBuildInputs (не buildInputs!) — libC должен быть виден и в
            # CMAKE_PREFIX_PATH, и в rpath у ВСЕХ, кто зависит от libB (например app),
            # потому что libB.hpp транзитивно включает libC.hpp и libBConfig.cmake
            # делает find_dependency(libC). Подробности — глава 06.
            propagatedBuildInputs = [ libC.packages.${system}.default ];
          };
        }
      );

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.cmake pkgs.gcc pkgs.gdb ];
            buildInputs = [ libC.packages.${system}.default ];
          };
        }
      );
    };
}
