{ config, pkgs, lib, ... }:

{
  options.custom.gnome.enable = lib.mkEnableOption "GNOME extensions and configuration";

  config = lib.mkIf config.custom.gnome.enable {
    home.packages = with pkgs; [
      gnomeExtensions.paperwm
    ];

    dconf.settings = {
      "org/gnome/shell" = {
        enabled-extensions = [
          "paperwm@paperwm.github.com"
          "GPaste@gnome-shell-extensions.gnome.org"
        ];
        favorite-apps = [ "firefox.desktop" "org.gnome.Nautilus.desktop" "kitty.desktop" ];
      };

      "org/gnome/desktop/peripherals/mouse" = {
        natural-scroll = true;
      };

      "org/gnome/shell/extensions/paperwm" = {
        gesture-enabled = true;
        gesture-horizontal-fingers = 3;
        gesture-workspace-fingers = 4;
      };

      "org/gnome/desktop/interface" = {
        scaling-factor = lib.hm.gvariant.mkUint32 2;
      };
    };
  };
}
