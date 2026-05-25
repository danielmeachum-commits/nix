{ config, pkgs, lib, ... }:

{
  programs.firefox = {
    enable = true;
    profiles.default.extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
      onepassword-password-manager
    ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html"                = "firefox.desktop";
      "x-scheme-handler/http"   = "firefox.desktop";
      "x-scheme-handler/https"  = "firefox.desktop";
      "x-scheme-handler/about"  = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      "application/xhtml+xml"   = "firefox.desktop";
    };
  };
}
