{ pkgs, ... }:

{
  imports = [ ./common.nix ];

  # niri and the rest of the wlroots-based desktop stack — home machine only.
  home.packages = with pkgs; [
    niri
    fuzzel
    waybar
    mako
    swappy
    swayidle
    swaylock

    # support tools the niri keybinds/waybar modules shell out to
    grim
    slurp
    wl-clipboard
    cliphist
    libnotify

    # Usually already provided by the distro's own bluetoothd/NetworkManager/
    # pipewire session — uncomment only if `which bluetoothctl nmcli wpctl`
    # comes back empty on this machine.
    # bluez
    # networkmanager
    # wireplumber
  ];
}
