{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  # niri and the rest of the wlroots-based desktop stack — home machine only.
  home.packages = with pkgs; [
    fuzzel
  ];
}
