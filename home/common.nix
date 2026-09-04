{ pkgs, ... }:

{
  home.username = "aldishu";
  home.homeDirectory = "/home/aldishu";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    alacritty
    neovim
    nerd-fonts.iosevka

    # CLI tools
    tmux
    fzf
    ripgrep
    yazi
    fd
    curl
    dust
    bat
    jq

    # GUI, non-DE-specific
    vscode
    firefox
    ffmpeg
    gimp
    obs-studio
  ];

  fonts.fontconfig.enable = true;

  programs.home-manager.enable = true;
}
