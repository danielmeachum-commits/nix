#!/usr/bin/env bash
# nixos-recover.sh — Recovery script for hobbes-lap
# Run this from the NixOS live USB as root (or with sudo).
#
# Disk layout for hobbes-lap:
#   nvme0n1p1 — EFI system partition (vfat, ~260MB)       → /mnt/boot/efi
#   nvme0n1p7 — Linux /boot (ext4, ~1GB)                  → /mnt/boot
#   nvme0n1p8 — Linux root (btrfs, subvols @ and @home)   → /mnt and /mnt/home

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Partition devices (update these if your layout differs) ──────────────────
EFI_DEV="/dev/nvme0n1p1"    # vfat EFI system partition
BOOT_DEV="/dev/nvme0n1p7"   # ext4 /boot
ROOT_DEV="/dev/nvme0n1p8"   # btrfs root (subvols @ and @home)

MNT="/mnt"
REPO_URL="https://github.com/danielmeachum-commits/nix"
REPO_DIR="$MNT/etc/nixos/config"
FLAKE_TARGET="hobbes-lap"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        NixOS Recovery — hobbes-lap               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Show disk layout ──────────────────────────────────────────────────
info "Current disk layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,UUID /dev/nvme0n1
echo ""

# ── Step 2: Unmount cleanly ───────────────────────────────────────────────────
info "Unmounting $MNT if already mounted..."
umount -R "$MNT" 2>/dev/null || true
success "Clean slate."
echo ""

# ── Step 3: Mount btrfs root with subvolumes ─────────────────────────────────
info "Mounting partitions..."

# Check btrfs subvolumes exist
SUBVOLS=$(btrfs subvolume list -o "$ROOT_DEV" 2>/dev/null || true)
if ! mount -o subvol=@ "$ROOT_DEV" "$MNT" 2>/dev/null; then
  warn "Subvolume @ not found — trying to mount root btrfs flat..."
  mount "$ROOT_DEV" "$MNT" || die "Failed to mount $ROOT_DEV to $MNT"
fi
success "Mounted $ROOT_DEV (subvol=@) → $MNT"

mkdir -p "$MNT/home" "$MNT/boot" "$MNT/boot/efi"

if ! mount -o subvol=@home "$ROOT_DEV" "$MNT/home" 2>/dev/null; then
  warn "Subvolume @home not found — skipping /home mount."
else
  success "Mounted $ROOT_DEV (subvol=@home) → $MNT/home"
fi

mount "$BOOT_DEV" "$MNT/boot"     || die "Failed to mount $BOOT_DEV to $MNT/boot"
success "Mounted $BOOT_DEV → $MNT/boot"

mount "$EFI_DEV" "$MNT/boot/efi"  || die "Failed to mount $EFI_DEV to $MNT/boot/efi"
success "Mounted $EFI_DEV → $MNT/boot/efi"

echo ""
info "Mount summary:"
df -h "$MNT" "$MNT/home" "$MNT/boot" "$MNT/boot/efi"
echo ""

# ── Step 4: Set TMPDIR to SSD to avoid filling live USB RAM ──────────────────
mkdir -p "$MNT/tmp"
export TMPDIR="$MNT/tmp"
info "TMPDIR set to $TMPDIR (builds on SSD, not in RAM)"
echo ""

# ── Step 5: Clone config repo ─────────────────────────────────────────────────
info "Cloning config from $REPO_URL..."

if [[ -d "$REPO_DIR/.git" ]]; then
  warn "$REPO_DIR already exists — pulling latest instead of cloning."
  git -C "$REPO_DIR" pull --ff-only || warn "git pull failed; using existing repo state."
else
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR" || die "git clone failed. Check internet connectivity."
fi

success "Repo ready at $REPO_DIR"
echo ""

# ── Step 6: Generate hardware config and place it where the flake expects it ─
info "Generating hardware configuration for this machine..."

nixos-generate-config --root "$MNT" --dir /tmp/hwcfg-gen
success "Hardware config generated."

LAPTOP_HW_DIR="$REPO_DIR/hosts/laptop"
mkdir -p "$LAPTOP_HW_DIR"
cp /tmp/hwcfg-gen/hardware-configuration.nix "$LAPTOP_HW_DIR/hardware-configuration.nix"
success "Placed hardware config at $LAPTOP_HW_DIR/hardware-configuration.nix"

echo ""
info "Generated hardware config:"
echo "────────────────────────────────────────────"
cat "$LAPTOP_HW_DIR/hardware-configuration.nix"
echo "────────────────────────────────────────────"

# ── Step 7: Verify btrfs subvol options are present in hardware config ────────
echo ""
info "Checking btrfs subvol options in hardware config..."

HW_CFG="$LAPTOP_HW_DIR/hardware-configuration.nix"
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV")

if ! grep -q 'subvol=@"' "$HW_CFG" 2>/dev/null; then
  warn "Root subvol option missing — patching hardware config..."
  # Add subvol=@ to the / fileSystems entry
  sed -i 's|fsType = "btrfs";|fsType = "btrfs";\n      options = [ "subvol=@" "compress=zstd" "noatime" ];|' "$HW_CFG"
  success "Patched / entry with subvol=@"
fi

if ! grep -q '"/home"' "$HW_CFG" 2>/dev/null; then
  warn "/home entry missing — adding it..."
  # Append /home entry before closing }
  sed -i 's|^}$|  fileSystems."/home" = {\n    device = "/dev/disk/by-uuid/'"$ROOT_UUID"'";\n    fsType = "btrfs";\n    options = [ "subvol=@home" "compress=zstd" "noatime" ];\n  };\n}|' "$HW_CFG"
  success "Added /home entry with subvol=@home"
fi

echo ""
info "Final hardware config:"
echo "────────────────────────────────────────────"
cat "$HW_CFG"
echo "────────────────────────────────────────────"
echo ""

# ── Step 8: Install NixOS ─────────────────────────────────────────────────────
info "Running nixos-install --flake path:$REPO_DIR#$FLAKE_TARGET"
info "This will take a while on first run (Steam, JetBrains, Proton-GE are large)."
info "Subsequent rebuilds will be much faster."
echo ""

nixos-install \
  --flake "path:$REPO_DIR#$FLAKE_TARGET" \
  --no-root-passwd \
  2>&1 | tee /tmp/nixos-install.log

INSTALL_EXIT=${PIPESTATUS[0]}

echo ""
if [[ $INSTALL_EXIT -eq 0 ]]; then
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
  echo ""
  echo -e "${RED}[ERROR]${NC} nixos-install failed (exit $INSTALL_EXIT)."
  echo "Full log saved to /tmp/nixos-install.log"
  echo ""
  echo "Last 50 lines:"
  tail -50 /tmp/nixos-install.log
fi
