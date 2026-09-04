{
  description = "aldishu dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
          "vscode"
        ];
      };
    in
    {
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
    };
}
