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
      cachyEspUuid = lib.mkOption {
        type = lib.types.str;
        default = "8955-10D9";
        description = "Filesystem UUID of the boot partition (p9, label CACHYBOOT) holding the CachyOS Limine bootloader.";
      };
      cachyRootUuid = lib.mkOption {
        type = lib.types.str;
        default = "d8c37f97-0618-47fe-90db-30c52c0de712";
        description = "Filesystem UUID of the CachyOS btrfs root (p8), used by the direct-kernel fallback entry.";
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

        # CachyOS replaced Pop!_OS on p8/p9 in 2026-08. It keeps its kernels and
        # its bootloader (Limine, not systemd-boot) on its own 4GiB partition
        # p9, so nothing here has to fit on the 260MiB p1 alongside Windows.
        # Chainload Limine rather than hardcoding kernel paths, so CachyOS
        # kernel updates need no change here.
        menuentry "CachyOS" --class cachyos --class arch --hotkey=c {
          insmod part_gpt
          insmod fat
          insmod chain
          search --no-floppy --fs-uuid --set=root ${cfg.grub.cachyEspUuid}
          chainloader /EFI/limine/limine_x64.efi
        }

        # Fallback in case the Limine chainload misbehaves: boot the CachyOS
        # kernel directly. pacman keeps these two paths stable across kernel
        # updates, so this entry does not need maintenance either. Delete it
        # once the chainload entry above is confirmed working.
        menuentry "CachyOS (direct kernel)" --class cachyos --class arch {
          insmod part_gpt
          insmod fat
          search --no-floppy --fs-uuid --set=root ${cfg.grub.cachyEspUuid}
          linux /vmlinuz-linux-cachyos root=UUID=${cfg.grub.cachyRootUuid} rw rootflags=subvol=/@ quiet nowatchdog splash
          initrd /amd-ucode.img /initramfs-linux-cachyos.img
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
