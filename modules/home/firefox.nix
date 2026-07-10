{ config, pkgs, lib, ... }:

{
  programs.firefox = {
    enable = true;
    profiles.default.extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
      onepassword-password-manager
    ];

    profiles.default.settings = {
      # Captive-portal survival. Firefox's DNS-over-HTTPS (TRR) resolves names
      # over an encrypted channel that bypasses the portal's DNS hijack, so the
      # login page never loads. Mode 2 keeps DoH but falls back to the OS
      # resolver when the DoH endpoint is unreachable (as it is behind a portal).
      "network.trr.mode" = 2;

      # Let Firefox run its own portal probe and show the in-browser
      # "Log in to network" banner instead of silently failing to load pages.
      "network.captive-portal-service.enabled" = true;
      "network.connectivity-service.enabled" = true;
    };
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
