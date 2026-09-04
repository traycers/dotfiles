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
    awww # formerly "swww" — same project, renamed upstream/in nixpkgs

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

  # niri doesn't import WAYLAND_DISPLAY/session env into systemd on its own —
  # config.kdl needs to run `dbus-update-activation-environment --systemd
  # WAYLAND_DISPLAY XDG_CURRENT_DESKTOP` (and start graphical-session.target)
  # before these units can come up. Tracked in .scratch/nix-migration/issues/01-port-niri-config.md.
  systemd.user.services = {
    awww-daemon = {
      Unit = {
        Description = "awww (swww) wallpaper daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    xdg-desktop-portal-gnome = {
      Unit = {
        Description = "Portal service (GNOME/mutter backend — matches niri's screencast protocol)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.xdg-desktop-portal-gnome}/libexec/xdg-desktop-portal-gnome";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
