{ config, pkgs, lib, ... }:

{
  options.custom.nix-ld.enable = lib.mkEnableOption "nix-ld dynamic linker for FHS-style binaries";

  config = lib.mkIf config.custom.nix-ld.enable {
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      # Core
      stdenv.cc.cc.lib
      zlib
      glib
      dbus
      libsecret
      libnotify
      expat

      # Fonts / rendering
      fontconfig
      freetype
      libGL

      # X / Wayland
      libxkbcommon
      libx11
      libxrender
      libxrandr
      libxtst
      libxi
      libxext
      libxcursor
      libxcomposite
      libxdamage
      libxfixes
      libxcb

      # Audio
      alsa-lib

      # NSS (used by embedded Chromium in JetBrains IDEs)
      nss
      nspr
    ];
  };
}
