{ config, lib, ... }:

{
  options.custom.networking = {
    enable = lib.mkEnableOption "networking configuration";
    tailscale = {
      enable = lib.mkEnableOption "Tailscale VPN" // { default = true; };
      exitNode = lib.mkEnableOption "Tailscale exit node mode" // { default = false; };
      authKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing Tailscale auth key";
      };
    };
  };

  config = lib.mkIf config.custom.networking.enable {
    networking = {
      networkmanager = {
        enable = true;

        # Connectivity checking: NM periodically fetches this URL and inspects
        # the response. On a captive-portal network the fetch is redirected, so
        # NM flips state to "portal" — which is what makes GNOME Shell pop the
        # "Log in to network" window automatically, both on connect and when a
        # session later expires. Without this, portals are invisible to GNOME.
        settings.connectivity = {
          uri = "http://nmcheck.gnome.org/check_network_status.txt";
          interval = 300;
        };
      };

      firewall = lib.mkIf config.custom.networking.tailscale.enable {
        trustedInterfaces = [ "tailscale0" ];
        allowedUDPPorts = [ config.services.tailscale.port ];
      };
    };

    # Enable IP forwarding for exit node
    boot.kernel.sysctl = lib.mkIf config.custom.networking.tailscale.exitNode {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    services.tailscale = {
      enable = config.custom.networking.tailscale.enable;

      authKeyFile = lib.mkIf (config.custom.networking.tailscale.authKeyFile != null)
        config.custom.networking.tailscale.authKeyFile;

      extraUpFlags = lib.mkIf config.custom.networking.tailscale.exitNode [
        "--advertise-exit-node"
      ];
    };
  };
}
