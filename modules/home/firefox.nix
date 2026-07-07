{ config, pkgs, lib, ... }:

{
  programs.firefox = {
    enable = true;
    profiles.default.extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
      onepassword-password-manager
    ];
    policies = {
      # Register OpenSC so Firefox prompts for the CAC on client-cert auth sites.
      SecurityDevices = {
        "CAC (OpenSC)" = "${pkgs.opensc}/lib/opensc-pkcs11.so";
      };
      # Trust roots from the system store (/etc/ssl/certs) — picks up DoD roots
      # added via security.pki.certificateFiles in modules/system/cac.nix.
      Certificates = {
        ImportEnterpriseRoots = true;
      };
    };
  };

  # GNOME/Plasma rewrite mimeapps.list at runtime, so every activation wants to
  # back the live file up — and fails once a stale .hm-backup exists (this broke
  # home-manager-hobbes.service on every boot/rebuild). Our declared associations
  # are the source of truth; overwrite instead of backing up.
  xdg.configFile."mimeapps.list".force = true;

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
