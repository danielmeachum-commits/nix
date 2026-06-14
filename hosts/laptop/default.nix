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
}
