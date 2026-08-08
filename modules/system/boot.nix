{ config, pkgs, lib, ... }:

let
  cfg = config.custom.boot;
in
{
  options.custom.boot = {
    enable = lib.mkEnableOption "system boot config";

    grub = {
      enable = lib.mkEnableOption "themed GRUB instead of systemd-boot (Windows dual-boot menu)";
      windowsEspUuid = lib.mkOption {
        type = lib.types.str;
        default = "D415-6380";
        description = "Filesystem UUID of the EFI partition containing the Windows boot manager.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.efi.canTouchEfiVariables = true;
    # With GRUB the ESP lives at /boot/efi; /boot stays on the root fs so
    # install-grub references kernels from /nix/store instead of copying
    # them onto the tiny ESP (it force-copies when /boot is a separate fs).
    boot.loader.efi.efiSysMountPoint = lib.mkIf cfg.grub.enable "/boot/efi";

    boot.loader.systemd-boot = lib.mkIf (!cfg.grub.enable) {
      enable = true;
      configurationLimit = 20;
    };

    boot.loader.grub = lib.mkIf cfg.grub.enable {
      enable = true;
      device = "nodev";
      efiSupport = true;
      configurationLimit = 4;
      theme = pkgs.catppuccin-grub;
      # Render the menu at 1080p instead of native panel resolution so the
      # text is legible on the HiDPI display; falls back if unsupported.
      gfxmodeEfi = "1920x1080,auto";
      extraEntries = ''
        menuentry "Windows" --class windows --hotkey=w {
          insmod part_gpt
          insmod fat
          insmod chain
          search --no-floppy --fs-uuid --set=root ${cfg.grub.windowsEspUuid}
          chainloader /EFI/Microsoft/Boot/bootmgfw.efi
        }
      '';
    };

    boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    boot.plymouth.enable = true;
    boot.kernelParams = [ "quiet" "splash" ];

    boot.tmp.cleanOnBoot = true;

    zramSwap.enable = true;
  };
}
