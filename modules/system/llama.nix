{ config, pkgs, lib, ... }:

let
  cfg = config.custom.llama;

  llamaCpp =
    if cfg.cuda.enable then
      pkgs.llama-cpp.override { cudaSupport = true; }
    else if cfg.vulkan.enable then
      pkgs.llama-cpp.override { vulkanSupport = true; }
    else
      pkgs.llama-cpp;

  swapConfigFile = pkgs.writeText "llama-swap.yaml" cfg.swap.config;
in {
  options.custom.llama = {
    enable = lib.mkEnableOption "llama.cpp + llama-swap stack";

    cuda.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Build llama.cpp with the CUDA backend (for NVIDIA).";
    };

    vulkan.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Build llama.cpp with the Vulkan backend instead of CUDA. Useful if you
        want to target the AMD iGPU (or both GPUs simultaneously). Mutually
        exclusive with cuda.enable.
      '';
    };

    swap = {
      enable = lib.mkEnableOption "llama-swap systemd proxy service";

      port = lib.mkOption {
        type = lib.types.port;
        default = 9292;
        description = "TCP port for the llama-swap HTTP API.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address llama-swap binds to. Use 0.0.0.0 for LAN/Tailscale access.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open the firewall on llama-swap's port.";
      };

      modelsDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/llama-swap/models";
        description = "Directory the service expects GGUF files in. Created on boot.";
      };

      config = lib.mkOption {
        type = lib.types.lines;
        description = ''
          llama-swap YAML config. Reference: https://github.com/mostlygeek/llama-swap
          Use ''${PORT} as a placeholder for the upstream port llama-swap will
          assign each model.
        '';
        default = ''
          healthCheckTimeout: 120
          logLevel: info

          models:
            # gpt-oss-20b — OpenAI's 21B MoE (~3.6B active params), native MXFP4.
            # File ~12GB; download from https://huggingface.co/ggml-org/gpt-oss-20b-GGUF
            # to ${cfg.swap.modelsDir}/gpt-oss-20b-mxfp4.gguf
            #
            # On the 5070 Mobile's 8GB VRAM the full weights don't fit, so we
            # keep the MoE expert tensors on CPU (--cpu-moe). Only the active
            # path (attention + 4-of-32 experts/token) hits the GPU, which is
            # the right tradeoff for sparse MoE.
            "gpt-oss-20b":
              aliases: ["gpt-4o-mini", "gpt-4"]
              cmd: |
                llama-server
                  --model ${cfg.swap.modelsDir}/gpt-oss-20b-mxfp4.gguf
                  --host 127.0.0.1 --port ''${PORT}
                  -ngl 99
                  --cpu-moe
                  -fa on
                  --ctx-size 8192
                  --jinja
              ttl: 600
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = !(cfg.cuda.enable && cfg.vulkan.enable);
      message = "custom.llama: cuda.enable and vulkan.enable are mutually exclusive.";
    }];

    environment.systemPackages = [ llamaCpp ]
      ++ lib.optional cfg.swap.enable pkgs.llama-swap;

    # State + models dir owned by the service user.
    systemd.tmpfiles.rules = lib.optionals cfg.swap.enable [
      "d /var/lib/llama-swap        0750 llama llama -"
      "d ${cfg.swap.modelsDir}      0755 llama llama -"
    ];

    users.groups.llama = lib.mkIf cfg.swap.enable {};
    users.users.llama = lib.mkIf cfg.swap.enable {
      isSystemUser = true;
      group = "llama";
      home = "/var/lib/llama-swap";
      # `video` + `render` give access to /dev/nvidia* and /dev/dri/*.
      extraGroups = [ "video" "render" ];
    };

    systemd.services.llama-swap = lib.mkIf cfg.swap.enable {
      description = "llama-swap: model-switching HTTP proxy in front of llama.cpp";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # llama-swap spawns `llama-server` (and friends) from PATH.
      path = [ llamaCpp ];

      environment = {
        HOME = "/var/lib/llama-swap";
        # Make the dGPU visible to CUDA even when PRIME offload is on.
        # (Compute apps power the GPU up via nvidia-uvm regardless of X.)
        NVIDIA_VISIBLE_DEVICES = "all";
      };

      serviceConfig = {
        ExecStart = "${pkgs.llama-swap}/bin/llama-swap"
          + " -config ${swapConfigFile}"
          + " -listen ${cfg.swap.listenAddress}:${toString cfg.swap.port}"
          + " -watch-config";
        Restart = "on-failure";
        RestartSec = "5s";

        User = "llama";
        Group = "llama";
        SupplementaryGroups = [ "video" "render" ];

        WorkingDirectory = "/var/lib/llama-swap";
        StateDirectory = "llama-swap";

        # Sandboxing — relaxed enough for GPU device access.
        PrivateDevices = false;        # need /dev/nvidia*
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/llama-swap" ];
        NoNewPrivileges = true;
        RestrictSUIDSGID = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.optional (cfg.swap.enable && cfg.swap.openFirewall) cfg.swap.port;
  };
}
