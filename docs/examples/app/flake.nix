{
  description = "app — вершина дерева: зависит от libB, транзитивно от libC";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # В реальном дереве репозиториев замените path: на:
    #   libB.url = "git+https://gitlab.com/your-org/libB.git?ref=special";
    #   libC.url = "git+https://gitlab.com/your-org/libC.git?ref=special";
    libC.url = "path:../libC";

    libB = {
      url = "path:../libB";
      # Без follows у libB был бы СВОЙ независимый libC input — возможен diamond
      # dependency (два разных build'а libC в одном дереве). follows заставляет
      # libB использовать РОВНО ТОТ ЖЕ libC, который резолвит app. См. главу 04/06.
      inputs.libC.follows = "libC";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, libB, libC, ... }:
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
            pname = "app";
            version = "1.0.0";
            src = self;

            nativeBuildInputs = [ pkgs.cmake ];
            # libC сюда явно не добавлен — он приходит транзитивно через
            # propagatedBuildInputs libB (глава 06).
            buildInputs = [ libB.packages.${system}.default ];
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/app";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [ pkgs.cmake pkgs.gcc pkgs.gdb ];
            buildInputs = [ libB.packages.${system}.default ];
          };
        }
      );
    };
}
