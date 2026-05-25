{ config, pkgs, lib, ... }:

{
  options.custom.lidarr = {
    enable = lib.mkEnableOption "Lidarr (plugins build) via podman container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/hotio/lidarr:pr-plugins";
      description = ''
        Container image to run. hotio's `pr-plugins` tag tracks the
        upstream Lidarr `plugins` branch, which is what TrevTV's Tidal
        plugin requires.
      '';
    };

    musicFolder = lib.mkOption {
      type = lib.types.path;
      default = config.custom.navidrome.musicFolder or "/home/music";
      description = ''
        Host path mounted into the container as `/music`. Defaults to
        the same folder Navidrome indexes so downloads show up there.
      '';
    };

    tidalConfigFolder = lib.mkOption {
      type = lib.types.path;
      default = "/home/tidal";
      description = ''
        Host path mounted into the container as `/data/tidal-config`.
      '';
    };

    downloadFolder = lib.mkOption {
      type = lib.types.path;
      default = "/home/downloads";
      description = ''
        Host path mounted into the container as `/downloads`. Staging
        folder where the download client writes; Lidarr then imports
        from here into the library. Keep it on the same filesystem as
        `musicFolder` so Lidarr can hardlink instead of copy.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/lidarr-plugins";
      description = "Host path for the container's `/config` volume.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8686;
      description = "Host port to expose the Lidarr web UI on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the firewall for Lidarr's port.";
    };
  };

  config = lib.mkIf config.custom.lidarr.enable {
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    # hobbes is uid 1000 / gid 100 (NixOS defaults for the first normal
    # user). Running the container as that uid/gid means downloads land
    # in `/home/music` already owned by hobbes:users, which Navidrome
    # (DynamicUser) can read.
    systemd.tmpfiles.rules = [
      "d ${config.custom.lidarr.stateDir} 0755 1000 100 -"
      "d ${config.custom.lidarr.tidalConfigFolder} 0755 1000 100 -"
      "d ${config.custom.lidarr.downloadFolder} 0755 1000 100 -"
    ];

    virtualisation.oci-containers.containers.lidarr-plugins = {
      image = config.custom.lidarr.image;
      autoStart = true;

      environment = {
        PUID = "1000";
        PGID = "100";
        UMASK = "002";
        TZ = config.time.timeZone;
      };

      volumes = [
        "${config.custom.lidarr.stateDir}:/config"
        "${toString config.custom.lidarr.musicFolder}:/music"
        "${toString config.custom.lidarr.tidalConfigFolder}:/data/tidal-config"
        "${toString config.custom.lidarr.downloadFolder}:/downloads"
      ];

      ports = [
        "${toString config.custom.lidarr.port}:8686"
      ];
    };

    networking.firewall.allowedTCPPorts =
      lib.mkIf config.custom.lidarr.openFirewall [ config.custom.lidarr.port ];
  };
}
