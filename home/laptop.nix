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
    brightnessctl
    swww

    # niri speaks the same screencast/remote-desktop D-Bus interfaces as
    # GNOME/mutter — this is the portal it actually needs, not
    # xdg-desktop-portal-wlr. Required for OBS Studio screen capture.
    xdg-desktop-portal-gnome

    # Usually already provided by the distro's own bluetoothd/NetworkManager/
    # pipewire session — uncomment only if `which bluetoothctl nmcli wpctl`
    # comes back empty on this machine.
    # bluez
    # networkmanager
    # wireplumber
  ];
}
