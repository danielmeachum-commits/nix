{ config, lib, ... }:

{
  options.custom.navidrome = {
    enable = lib.mkEnableOption "Navidrome music streaming server";

    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = "/home/music";
      description = "Path to the music library Navidrome should index.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4533;
      description = "Port for the Navidrome web UI / Subsonic API.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the firewall for Navidrome's port.";
    };
  };

  config = lib.mkIf config.custom.navidrome.enable {
    # The Navidrome service runs under DynamicUser, so the library path
    # needs to be world-readable. Owned by hobbes so the user can drop
    # files in without sudo.
    systemd.tmpfiles.rules = [
      "d ${config.custom.navidrome.musicFolder} 0755 hobbes users -"
    ];

    services.navidrome = {
      enable = true;
      openFirewall = config.custom.navidrome.openFirewall;

      settings = {
        MusicFolder = config.custom.navidrome.musicFolder;

        # Listen on all interfaces so the server is reachable on the LAN
        # / over Tailscale, not just localhost.
        Address = "0.0.0.0";
        Port = config.custom.navidrome.port;

        # Rescan the library every hour and watch for filesystem changes
        # in between so new music shows up without a manual trigger.
        ScanSchedule = "@every 1h";

        # Useful Subsonic-client features.
        EnableSharing = true;
        EnableDownloads = true;
        EnableCoverAnimation = true;

        # Pick up .m3u/.m3u8 files that live alongside the music.
        AutoImportPlaylists = true;

        # Recursively follow symlinks inside the library, handy if you
        # stitch the collection together from multiple mounts later.
        FollowSymlinks = true;

        LogLevel = "info";
      };
    };
  };
}
