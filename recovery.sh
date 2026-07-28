#!/usr/bin/env bash
# recovery.sh — Recovery / reinstall helper for hobbes-lap
# Run from the NixOS live USB as root (or with sudo).
#
# Devices are selected by filesystem UUID, never by partition number. On
# 2026-07-28 a Windows update rewrote this disk's GPT and renumbered the
# partitions into start-LBA order: the btrfs root moved from slot 7 to slot 5.
# Anything hardcoding /dev/nvme0n1pN silently pointed at the wrong partition.
# UUIDs survive renumbering; partition numbers do not.
#
# Layout for hobbes-lap (matches hosts/laptop/hardware-configuration.nix):
#   ROOT_UUID (btrfs) subvol=@      → /mnt
#   ROOT_UUID (btrfs) subvol=@home  → /mnt/home
#   ESP_UUID  (vfat)                → /mnt/boot/efi
#
# NOTE: there is NO separate /boot partition. /boot lives on btrfs inside
# subvol @ so GRUB can reference kernels from /nix/store; the 260 MB OEM ESP
# holds only EFI binaries and is mounted at /boot/efi.

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Identity of this machine's filesystems (stable across repartitioning) ────
ROOT_UUID="${ROOT_UUID:-a9a72a5a-05d1-40ff-9841-a76b22fe04c8}"   # btrfs, subvols @ and @home
ESP_UUID="${ESP_UUID:-D415-6380}"                                # vfat EFI system partition

MNT="${MNT:-/mnt}"
REPO_URL="${REPO_URL:-https://github.com/danielmeachum-commits/nix}"
REPO_DIR="${REPO_DIR:-$MNT/home/hobbes/nixos}"
FLAKE_TARGET="${FLAKE_TARGET:-hobbes-lap}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  repair-boot   Mount the system and reinstall the bootloader from the
                existing generation. Fixes a stale GRUB prefix, a wiped ESP,
                or a lost UEFI boot entry. Does NOT rebuild or change config.
                This is almost always what you want.

  reinstall     Full nixos-install from the flake. Destructive to the current
                system generation and slow. Only for a genuinely broken or
                fresh root filesystem.

  mount         Just mount everything at $MNT and exit (for manual poking).

  status        Diagnose only: show layout, resolved devices, and whether the
                GRUB EFI binary's embedded partition prefix still matches
                reality. Read-only, mounts nothing.

Environment overrides: ROOT_UUID, ESP_UUID, MNT, REPO_URL, REPO_DIR, FLAKE_TARGET
EOF
}

# ── Resolve a filesystem UUID to its current device node ─────────────────────
resolve_uuid() {
  local uuid="$1" label="$2" dev=""
  if [[ -e "/dev/disk/by-uuid/$uuid" ]]; then
    dev="$(readlink -f "/dev/disk/by-uuid/$uuid")"
  else
    dev="$(blkid -U "$uuid" 2>/dev/null || true)"
  fi
  [[ -n "$dev" && -b "$dev" ]] || die "Could not find $label (UUID=$uuid). Is the right disk attached? Run '$(basename "$0") status'."
  echo "$dev"
}

# ── Partition number a device currently occupies (for the GRUB prefix check) ─
partition_number() {
  local dev="$1" sysfs="/sys/class/block/$(basename "$1")/partition"
  [[ -r "$sysfs" ]] && cat "$sysfs" || echo "?"
}

# ── The prefix baked into grubx64.efi at install time, e.g. "(,gpt5)/@/boot/grub"
grub_embedded_prefix() {
  local efi="$1"
  [[ -r "$efi" ]] || return 1
  tr -c '[:print:]' '\n' < "$efi" | grep -aoE '^\(,gpt[0-9]+\)[^ ]*' | head -1
}

require_root() { [[ $EUID -eq 0 ]] || die "Run as root (sudo $0 $*)."; }

banner() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║        NixOS Recovery — hobbes-lap               ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
  echo ""
}

# ── Mount the installed system at $MNT ───────────────────────────────────────
do_mount() {
  local root_dev esp_dev
  root_dev="$(resolve_uuid "$ROOT_UUID" "btrfs root")"
  esp_dev="$(resolve_uuid "$ESP_UUID" "EFI system partition")"

  info "btrfs root : $root_dev (partition $(partition_number "$root_dev"))"
  info "ESP        : $esp_dev (partition $(partition_number "$esp_dev"))"
  echo ""

  [[ "$(blkid -s TYPE -o value "$root_dev")" == "btrfs" ]] \
    || die "$root_dev is not btrfs — refusing to touch it."
  [[ "$(blkid -s TYPE -o value "$esp_dev")" == "vfat" ]] \
    || die "$esp_dev is not vfat — refusing to touch it."

  info "Unmounting $MNT if already mounted..."
  umount -R "$MNT" 2>/dev/null || true

  mount -o subvol=@,compress=zstd "$root_dev" "$MNT" \
    || die "Failed to mount subvol=@ from $root_dev. Is the filesystem damaged?"
  success "Mounted $root_dev (subvol=@) → $MNT"

  # Nested subvols (@/srv, @/tmp, @/var/tmp, ...) come along with @ automatically.
  mkdir -p "$MNT/home" "$MNT/boot/efi"

  mount -o subvol=@home,compress=zstd "$root_dev" "$MNT/home" \
    || die "Failed to mount subvol=@home from $root_dev."
  success "Mounted $root_dev (subvol=@home) → $MNT/home"

  mount "$esp_dev" "$MNT/boot/efi" \
    || die "Failed to mount $esp_dev at $MNT/boot/efi."
  success "Mounted $esp_dev → $MNT/boot/efi"

  echo ""
  info "Mount summary:"
  findmnt -R "$MNT" -o TARGET,SOURCE,FSTYPE
  echo ""
}

# ── Read-only diagnosis ──────────────────────────────────────────────────────
do_status() {
  info "Disk layout:"
  lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,UUID
  echo ""

  local root_dev esp_dev root_partnum
  root_dev="$(resolve_uuid "$ROOT_UUID" "btrfs root")"
  esp_dev="$(resolve_uuid "$ESP_UUID" "EFI system partition")"
  root_partnum="$(partition_number "$root_dev")"

  success "btrfs root UUID=$ROOT_UUID → $root_dev (partition $root_partnum)"
  success "ESP        UUID=$ESP_UUID → $esp_dev (partition $(partition_number "$esp_dev"))"
  echo ""

  [[ -d /sys/firmware/efi ]] \
    && success "Live system booted in UEFI mode." \
    || warn "Live system booted in LEGACY BIOS mode — reinstalling the bootloader from here will not work. Reboot the USB in UEFI mode."

  # The failure mode that broke this machine on 2026-07-28.
  info "Checking GRUB's embedded partition prefix..."
  local tmp_esp prefix want
  tmp_esp="$(mktemp -d)"
  if mount -o ro "$esp_dev" "$tmp_esp" 2>/dev/null; then
    prefix="$(grub_embedded_prefix "$tmp_esp/EFI/NixOS-boot-efi/grubx64.efi" || true)"
    if [[ -z "$prefix" ]]; then
      warn "No GRUB binary found at EFI/NixOS-boot-efi/grubx64.efi on the ESP."
      warn "The ESP may have been wiped by a Windows update. Run: $(basename "$0") repair-boot"
    else
      want="(,gpt${root_partnum})"
      echo "         embedded prefix : $prefix"
      echo "         root is now     : $want"
      if [[ "$prefix" == "$want"* ]]; then
        success "Prefix matches the current partition number. GRUB can find its config."
      else
        warn "MISMATCH — GRUB will drop to a 'grub rescue>' prompt."
        warn "The partitions were renumbered since GRUB was installed."
        warn "Fix with: $(basename "$0") repair-boot"
        echo ""
        echo "  One-time manual boot from the grub rescue> prompt:"
        echo "      set root=(hd0,gpt${root_partnum})"
        echo "      set prefix=(hd0,gpt${root_partnum})/@/boot/grub"
        echo "      insmod normal"
        echo "      normal"
      fi
    fi
    umount "$tmp_esp" 2>/dev/null || true
  else
    warn "Could not mount the ESP read-only to inspect it."
  fi
  rmdir "$tmp_esp" 2>/dev/null || true

  echo ""
  info "UEFI boot entries:"
  efibootmgr 2>/dev/null | grep -E '^(BootCurrent|BootOrder|Boot[0-9A-F]{4})' || warn "efibootmgr unavailable."
}

# ── Reinstall the bootloader from the existing generation ────────────────────
do_repair_boot() {
  do_mount

  [[ -d /sys/firmware/efi ]] \
    || die "Live USB is not booted in UEFI mode; efibootmgr cannot write boot entries. Reboot the USB in UEFI mode."
  [[ -x "$MNT/nix/var/nix/profiles/system/bin/switch-to-configuration" ]] \
    || die "No usable system generation at $MNT/nix/var/nix/profiles/system — use 'reinstall' instead."

  info "Reinstalling the bootloader from the current generation..."
  info "(This does not rebuild or change your configuration.)"
  nixos-enter --root "$MNT" -- /bin/sh -c \
    'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot' \
    || die "Bootloader reinstall failed."

  echo ""
  local root_dev prefix
  root_dev="$(resolve_uuid "$ROOT_UUID" "btrfs root")"
  prefix="$(grub_embedded_prefix "$MNT/boot/efi/EFI/NixOS-boot-efi/grubx64.efi" || true)"
  info "GRUB prefix is now: ${prefix:-<not found>} (root is partition $(partition_number "$root_dev"))"

  # Keep the removable fallback path in sync. If the firmware ever loses its
  # NVRAM entries it falls back to \EFI\Boot\bootx64.efi, which must also be GRUB.
  if [[ -r "$MNT/boot/efi/EFI/NixOS-boot-efi/grubx64.efi" ]]; then
    mkdir -p "$MNT/boot/efi/EFI/Boot"
    cp "$MNT/boot/efi/EFI/NixOS-boot-efi/grubx64.efi" "$MNT/boot/efi/EFI/Boot/bootx64.efi"
    success "Removable fallback EFI/Boot/bootx64.efi synced to GRUB."
  fi

  echo ""
  info "UEFI boot entries:"
  efibootmgr 2>/dev/null | grep -E '^(BootOrder|Boot[0-9A-F]{4})' || true

  sync
  umount -R "$MNT" 2>/dev/null || true
  echo ""
  success "Bootloader repaired. Unmounted cleanly — you can reboot."
  warn "Have your BitLocker recovery key handy for the next Windows boot."
}

# ── Full reinstall from the flake ────────────────────────────────────────────
do_reinstall() {
  warn "'reinstall' runs nixos-install and replaces the current system generation."
  warn "If you are here because GRUB dropped to a rescue prompt, use 'repair-boot' instead."
  read -r -p "Type 'reinstall' to continue: " confirm
  [[ "$confirm" == "reinstall" ]] || die "Aborted."

  do_mount

  # Build on the SSD, not in the live USB's RAM disk.
  mkdir -p "$MNT/tmp"
  export TMPDIR="$MNT/tmp"
  info "TMPDIR set to $TMPDIR (builds on SSD, not in RAM)"
  echo ""

  if [[ -d "$REPO_DIR/.git" ]]; then
    if ! git -C "$REPO_DIR" diff --quiet || ! git -C "$REPO_DIR" diff --cached --quiet; then
      warn "$REPO_DIR has uncommitted changes — using it as-is, not pulling."
    else
      info "Updating existing repo at $REPO_DIR..."
      git -C "$REPO_DIR" pull --ff-only || warn "git pull failed; using existing repo state."
    fi
  else
    info "Cloning config from $REPO_URL..."
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR" || die "git clone failed. Check internet connectivity."
  fi
  success "Repo ready at $REPO_DIR"
  echo ""

  # The committed hardware-configuration.nix is hand-tuned: it mounts the ESP at
  # /boot/efi (not /boot) so GRUB keeps its menu and kernel refs on btrfs.
  # nixos-generate-config does NOT know that and emits fileSystems."/boot" for
  # the ESP, which breaks the GRUB layout. So: generate, diff, never overwrite.
  local hw_cfg="$REPO_DIR/hosts/laptop/hardware-configuration.nix"
  if [[ -f "$hw_cfg" ]]; then
    info "Comparing committed hardware config against a freshly generated one..."
    nixos-generate-config --root "$MNT" --dir /tmp/hwcfg-gen >/dev/null 2>&1 || true
    if [[ -f /tmp/hwcfg-gen/hardware-configuration.nix ]]; then
      echo "────────────────────────────────────────────"
      diff -u "$hw_cfg" /tmp/hwcfg-gen/hardware-configuration.nix || true
      echo "────────────────────────────────────────────"
      warn "Differences above are informational. The committed file wins."
      warn "Do NOT blindly adopt the generated one: it maps the ESP to /boot"
      warn "instead of /boot/efi, which breaks the GRUB layout."
    fi
  else
    warn "No committed hardware config at $hw_cfg — generating one."
    nixos-generate-config --root "$MNT" --dir /tmp/hwcfg-gen
    mkdir -p "$(dirname "$hw_cfg")"
    cp /tmp/hwcfg-gen/hardware-configuration.nix "$hw_cfg"
    warn "Review $hw_cfg before trusting it — you will need to change"
    warn "fileSystems.\"/boot\" to fileSystems.\"/boot/efi\" for the GRUB setup."
  fi
  echo ""

  info "Running nixos-install --flake path:$REPO_DIR#$FLAKE_TARGET"
  info "This will take a while on first run (Steam, JetBrains, Proton-GE are large)."
  echo ""

  nixos-install \
    --flake "path:$REPO_DIR#$FLAKE_TARGET" \
    --no-root-passwd \
    2>&1 | tee /tmp/nixos-install.log

  local install_exit=${PIPESTATUS[0]}
  echo ""
  if [[ $install_exit -eq 0 ]]; then
    success "nixos-install succeeded!"
    echo ""
    echo -e "${GREEN}You can now reboot:${NC}  reboot"
    echo ""
    echo "After reboot, greetd/tuigreet should launch niri automatically."
    echo "If the display doesn't come up, common causes:"
    echo "  • NVIDIA modeset: cat /sys/module/nvidia_drm/parameters/modeset  (should be Y)"
    echo "  • noctalia bar missing: niri msg action spawn -- quickshell -c noctalia-shell"
    echo "  • JetBrains black screen: confirm _JAVA_AWT_WM_NONREPARENTING=1 is in printenv"
  else
    echo -e "${RED}[ERROR]${NC} nixos-install failed (exit $install_exit)."
    echo "Full log saved to /tmp/nixos-install.log"
    echo ""
    echo "Last 50 lines:"
    tail -50 /tmp/nixos-install.log
    exit "$install_exit"
  fi
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
case "${1:-}" in
  status)
    banner; do_status
    ;;
  mount)
    require_root "$@"; banner; do_mount
    success "Mounted at $MNT. Unmount with: umount -R $MNT"
    ;;
  repair-boot)
    require_root "$@"; banner; do_repair_boot
    ;;
  reinstall)
    require_root "$@"; banner; do_reinstall
    ;;
  ""|-h|--help|help)
    usage; [[ -n "${1:-}" ]] || exit 1
    ;;
  *)
    die "Unknown command: $1"$'\n'"$(usage)"
    ;;
esac
