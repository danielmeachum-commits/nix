{ pkgs, ... }:

{
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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

  # NVIDIA RTX 5070 Mobile (dGPU) + AMD Radeon 890M (iGPU) hybrid.
  # Bus IDs come from `lspci`: NVIDIA at 64:00.0 -> 0x64 = 100,
  # AMD iGPU at 65:00.0 -> 0x65 = 101.
  custom.nvidia.enable = true;
  custom.nvidia.prime.nvidiaBusId = "PCI:100:0:0";
  custom.nvidia.prime.otherBusId  = "PCI:101:0:0";

  # llama.cpp with CUDA, exposed via llama-swap on localhost:9292.
  custom.llama.enable = true;
  custom.llama.cuda.enable = true;
  custom.llama.swap.enable = true;

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
