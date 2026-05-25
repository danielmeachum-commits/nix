{ config, pkgs, lib, ... }:

{
  options.custom.fonts.enable = lib.mkEnableOption "system fonts";

  config = lib.mkIf config.custom.fonts.enable {
    fonts = {
      enableDefaultPackages = true;

      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        liberation_ttf
        dejavu_fonts
        inter
        roboto
        jetbrains-mono
        fira-code
        fira-code-symbols
        font-awesome
        material-design-icons
        material-symbols
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
        nerd-fonts.symbols-only
      ];

      fontconfig = {
        enable = true;
        defaultFonts = {
          serif     = [ "Noto Serif" ];
          sansSerif = [ "Inter" "Noto Sans" ];
          monospace = [ "JetBrainsMono Nerd Font" ];
          emoji     = [ "Noto Color Emoji" ];
        };
      };
    };
  };
}
