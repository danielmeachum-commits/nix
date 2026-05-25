{ config, pkgs, lib, ... }:

{
  options.custom.boot.enable = lib.mkEnableOption "system boot config";

  config = lib.mkIf config.custom.boot.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.configurationLimit = 20;

    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    boot.plymouth.enable = true;
    boot.kernelParams = [ "quiet" "splash" ];

    boot.tmp.cleanOnBoot = true;

    zramSwap.enable = true;
  };
}
