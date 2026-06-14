{ config, pkgs, lib, ... }:

let
  cfg = config.custom.nvidia;
in {
  options.custom.nvidia = {
    enable = lib.mkEnableOption "NVIDIA proprietary driver + CUDA stack";

    prime = {
      offload = lib.mkEnableOption "PRIME render offload (dGPU on demand)" // { default = true; };

      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        description = "PCI bus ID of the NVIDIA dGPU (e.g. PCI:100:0:0).";
      };

      otherBusId = lib.mkOption {
        type = lib.types.str;
        description = "PCI bus ID of the iGPU driving the display (e.g. PCI:101:0:0).";
      };

      otherBusIsAmd = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the non-NVIDIA GPU is AMD (sets amdgpuBusId vs intelBusId).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Mesa + Vulkan loaders, 32-bit shims for Steam/wine if ever needed.
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Tells X/Wayland to load nvidia.
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia = {
      # Blackwell (RTX 50-series) needs a recent driver. `production` on
      # nixos-unstable is 570+ which supports GB20x.
      package = config.boot.kernelPackages.nvidiaPackages.production;

      # Open kernel module is required for Turing+ on modern drivers and
      # is the only supported path for Blackwell.
      open = true;

      modesetting.enable = true;

      # Lets the dGPU suspend when idle; pairs with PRIME offload.
      powerManagement.enable = true;
      powerManagement.finegrained = cfg.prime.offload;

      nvidiaSettings = true;

      prime = lib.mkIf cfg.prime.offload ({
        offload = {
          enable = true;
          enableOffloadCmd = true;  # installs `nvidia-offload` wrapper
        };
        nvidiaBusId = cfg.prime.nvidiaBusId;
      } // (if cfg.prime.otherBusIsAmd
            then { amdgpuBusId = cfg.prime.otherBusId; }
            else { intelBusId  = cfg.prime.otherBusId; }));
    };

    # CUDA build cache so we don't compile cuda-anything from source.
    nix.settings = {
      substituters = [ "https://cuda-maintainers.cachix.org" ];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };
  };
}
