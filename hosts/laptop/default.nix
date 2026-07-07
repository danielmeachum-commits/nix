{ config, pkgs, lib, ... }:

{
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # KDE Plasma 6 available alongside GNOME — pick via the gear icon on the GDM password prompt.
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [ darkly-qt5 darkly ];
  qt.platformTheme = "qt5ct";

  # GNOME and Plasma both set programs.ssh.askPassword (seahorse vs ksshaskpass);
  # force GNOME's since it's the primary session.
  programs.ssh.askPassword = lib.mkForce "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

  environment.gnome.excludePackages = with pkgs; [
    epiphany  # GNOME Web — using Firefox instead
  ];

  # Clipboard manager with history (CLI: gpaste-client history)
  programs.gpaste.enable = true;

  # Remap mouse side buttons to horizontal scroll (GUI: input-remapper-gtk)
  services.input-remapper.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  custom.packages.guiTools.enable = true;

  custom.vmdev.enable = true;

  # Themed GRUB (replaces systemd-boot on this host): shows the last 4
  # generations, Catppuccin theme, and 'w' hotkey to boot Windows.
  custom.boot.grub.enable = true;

  # NVIDIA RTX 5070 Mobile (dGPU) + AMD Radeon 890M (iGPU) hybrid.
  # Bus IDs come from `lspci`: NVIDIA at 64:00.0 -> 0x64 = 100,
  # AMD iGPU at 65:00.0 -> 0x65 = 101.
  custom.nvidia.enable = true;
  custom.nvidia.prime.offload = false;
  custom.nvidia.prime.sync = true;
  custom.nvidia.prime.nvidiaBusId = "PCI:100:0:0";
  custom.nvidia.prime.otherBusId  = "PCI:101:0:0";

  # llama.cpp with CUDA, exposed via llama-swap on localhost:9292.
  custom.llama.enable = true;
  custom.llama.cuda.enable = true;
  custom.llama.swap.enable = true;

  # The Fresco/ASMedia xHCI controllers behind the Strix Halo USB4 bridge
  # (0000:00:01.1) come back as "Controller not ready at resume -19" after
  # s2idle, killing every USB device on the laptop until reboot. This system
  # only exposes s2idle (no S3), so the practical fix is to PCI-remove those
  # controllers before suspend and rescan after resume. The on-SoC AMD xHCIs
  # live under 0000:00:08.* and aren't touched.
  systemd.services.usb-xhci-resume-fix = {
    description = "Re-enumerate add-on xHCI controllers around s2idle";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "usb-xhci-suspend" ''
        removed=0
        for dev in /sys/bus/pci/drivers/xhci_hcd/0000:*:*.*; do
          [ -e "$dev" ] || continue
          case "$(readlink "$dev")" in
            */0000:00:01.1/*)
              bdf=$(basename "$dev")
              echo "usb-xhci-resume-fix: removing $bdf"
              echo 1 > "/sys/bus/pci/devices/$bdf/remove"
              removed=1
              ;;
          esac
        done
        # The removals fire a hotplug storm (USB disconnects, DP-tunnel HDA
        # wakeup on the dGPU, desktop audio re-routing) that keeps landing for
        # a couple of seconds after the writes return. If suspend starts while
        # those events are still arriving, the kernel sees them as pending
        # wakeups, aborts the freeze, and logind's instant retry hangs the
        # machine with the Thunderbolt topology half torn down (2026-07-06).
        # Drain the queue and give stragglers time to land before sleep.target
        # is allowed to continue.
        if [ "$removed" = 1 ]; then
          ${config.systemd.package}/bin/udevadm settle --timeout=10 || true
          ${pkgs.coreutils}/bin/sleep 3
        fi
      '';
      ExecStop = pkgs.writeShellScript "usb-xhci-resume" ''
        echo "usb-xhci-resume-fix: rescanning PCI bus"
        echo 1 > /sys/bus/pci/rescan
      '';
    };
  };

  # Open WebUI as the chat front-end. Bound to 0.0.0.0 so it's reachable
  # over Tailscale (tailscale0 is in trustedInterfaces), but openFirewall
  # is left off so the port stays closed on LAN/WiFi. Hit it from any
  # tailnet device at http://hobbes-lap:8080
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    environment = {
      # Telemetry off (matches the upstream module's defaults).
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";

      # We don't run ollama — skip the probes.
      ENABLE_OLLAMA_API = "False";

      # Point at llama-swap's OpenAI-compatible endpoint.
      OPENAI_API_BASE_URL = "http://127.0.0.1:9292/v1";
      OPENAI_API_KEY = "sk-no-auth-needed";

      # Keep auth on — first signup becomes admin. Useful even on a
      # private tailnet so other devices can't accidentally drive it.
      WEBUI_AUTH = "True";
    };
  };
}
