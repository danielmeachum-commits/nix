{ config, pkgs, lib, ... }:

{
  options.custom.hobbes.enable = lib.mkEnableOption "hobbes user account";

  config = lib.mkIf config.custom.hobbes.enable {
    users.users.hobbes = {
      isNormalUser = true;
      description = "Hobbes";
      shell = pkgs.zsh;
      extraGroups = [
        "wheel"          # sudo
        "networkmanager"
        "video"
        "audio"
        "input"
        "render"
        "podman"
        "kvm"
        "libvirtd"
      ];
    };
  };
}
