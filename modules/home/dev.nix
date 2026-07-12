{ config, pkgs, lib, ... }:

{
  options.custom.dev.enable = lib.mkEnableOption "developer tooling";
  options.custom.vmdev.enable = lib.mkEnableOption "developer tooling for virtual machines";

  config = lib.mkMerge [
    (lib.mkIf config.custom.dev.enable {
      # pnpm needs somewhere to put global installs; without this it fails
      # with ERR_PNPM_NO_GLOBAL_BIN_DIR the first time it's asked to install
      # something globally (e.g. `pnpm add -g` or corepack).
      home.sessionVariables.PNPM_HOME = "$HOME/.local/share/pnpm";
      home.sessionPath = [ "$HOME/.local/share/pnpm" ];

      home.packages = with pkgs; [
        # ---- Core CLI ----
        ripgrep
        fd
        sd                  # sed alternative
        jq
        yq-go
        httpie
        xh                  # faster httpie alternative
        curl
        wget
        tree
        tokei               # LoC stats
        hyperfine           # benchmarking
        watchexec
        entr
        just                # task runner
        pre-commit
        cmake
        gnumake
        pkg-config

        # ---- Compilers / build ----
        clang
        clang-tools

        # ---- Python ----
        python3
        python3Packages.pip
        python3Packages.virtualenv
        python3Packages.ipython
        uv
        poetry
        ruff
        mypy
        black

        # ---- Node ----
        nodejs_25
        pnpm
        yarn
        bun
        typescript

        # ---- Rust ----
        rustup

        # ---- Go ----
        go
        gopls
        golangci-lint
        delve

        # ---- DBs / data ----
        sqlite-interactive
        postgresql_16
        duckdb

        # ---- Cloud / infra ----
        opentofu
        ansible

        # ---- Network / debug ----
        nmap
        iperf3
        mtr
        bandwhich
        tcpdump

        # ---- VMs (GUI client + viewer; daemon lives in custom.vm) ----
        virt-manager
        virt-viewer
        spice-gtk

        # ---- Misc ----
        unzip
        zip
        p7zip
        rsync
        ffmpeg
        imagemagick
        yt-dlp
        pandoc
      ];
    })

    (lib.mkIf config.custom.vmdev.enable {
      home.packages = with pkgs; [
        podman
        podman-tui
        podman-compose
        k9s
        helm
        minikube
      ];

      systemd.user.tmpfiles.rules = [
        "d %h/pods 0755 - - -"
      ];
    })
  ];
}
