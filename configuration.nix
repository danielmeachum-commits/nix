# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  imports =
    [
      ./modules/users/hobbes.nix
      ./modules/system/boot.nix
      ./modules/system/fonts.nix
      ./modules/system/vm.nix
      ./modules/system/packages.nix
      ./modules/system/networking.nix
      ./modules/system/navidrome.nix
      ./modules/system/lidarr.nix
      ./modules/system/cac.nix
      ./modules/system/nvidia.nix
      ./modules/system/llama.nix
      ./modules/system/nix-ld.nix
      ./modules/system/memory.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];


   # High-DPI console
  console = {
    font = lib.mkDefault "${pkgs.terminus_font}/share/consolefonts/ter-u28n.psf.gz";
    keyMap = "us";
    # prevents `systemd-vconsole-setup` failing during systemd initrd
    earlySetup = true;
  };
  systemd.services.systemd-vconsole-setup.unitConfig.After = "local-fs.target";

  # Cap the shutdown hang from GUI apps (e.g. WebStorm/JetBrains) that ignore
  # SIGTERM. Their transient app scopes otherwise stall shutdown for the full
  # 90s DefaultTimeoutStopSec before systemd SIGKILLs them. System services keep
  # the default 90s.
  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=10s
  '';


  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable SSH
  services.openssh.enable = true;

  # Use zsh
  programs.zsh.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  custom.networking.enable = true;
  custom.networking.tailscale.exitNode = true;
  custom.networking.tailscale.authKeyFile = "/etc/tailscale/authkey";

  custom.boot.enable = true;
  custom.fonts.enable = true;
  custom.hobbes.enable = true;
  custom.vm.enable = true;    # set gpuPassthrough = true once you have PCI IDs

  # Configure system packages via the packages module
  custom.packages.enable = true;
  custom.packages.core.enable = true;
  custom.packages.devTools.enable = true;
  custom.packages.systemTools.enable = true;
  custom.packages.monitoring.enable = true;
  custom.packages.comparison.enable = true;
  custom.packages.guiTools.enable = true;

  custom.cac.enable = true;
  custom.nix-ld.enable = true;
  custom.memory.enable = true;

  # Populate /bin and /usr/bin with symlinks to executables on PATH so
  # FHS-style scripts with hardcoded shebangs (e.g. JetBrains Toolbox's
  # generated /bin/bash launchers) run. Complements nix-ld, which only
  # fixes dynamic linking of ELF binaries, not interpreter paths.
  services.envfs.enable = true;
}
