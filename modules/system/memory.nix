{ config, pkgs, lib, ... }:

{
  options.custom.memory.enable = lib.mkEnableOption "memory pressure protection (systemd-oomd + zram-aware swappiness)";

  config = lib.mkIf config.custom.memory.enable {
    # systemd-oomd is already enabled by default in nixpkgs, but every slice
    # ships ManagedOOM* = "auto", which means "only act if something opts in" —
    # and nothing does. The result is a daemon that runs forever and never
    # fires. Verified on 2026-07-28 after a runaway Next.js dev server reached
    # 11 GB RSS: /proc/pressure/memory hit full avg300=50.64 (i.e. EVERY task
    # stalled ~50% of each second, so the compositor could not service input)
    # while `journalctl -u systemd-oomd` had no entries at all.
    #
    # enableUserSlices sets ManagedOOMMemoryPressure=kill on user.slice and
    # user@.slice, so a runaway under the desktop session gets its cgroup killed
    # at sustained 80% pressure instead of freezing the machine. The system
    # slice is deliberately left alone — killing sshd/NetworkManager to save a
    # dev server is a worse outcome than the stall.
    systemd.oomd = {
      enable = true;
      enableUserSlices = true;
    };

    # Swap here is zram (see zramSwap in ./boot.nix) — compressed RAM, not disk.
    # The stock swappiness of 60 is tuned for a spinning disk, where swapping is
    # expensive and should be a last resort. With zram the opposite holds: a
    # swap-out is a fast in-memory zstd compression that RECLAIMS RAM, so the
    # kernel should prefer it over evicting the page cache. 180 is the value the
    # zram documentation recommends once swap is backed by RAM.
    boot.kernel.sysctl."vm.swappiness" = 180;
  };
}
