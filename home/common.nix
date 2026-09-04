{ pkgs, ... }:

{
  home.username = "aldishu";
  home.homeDirectory = "/home/aldishu";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    alacritty
    neovim
    nerd-fonts.iosevka
  ];

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
}
