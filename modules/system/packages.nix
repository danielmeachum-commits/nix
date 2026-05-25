{ config, pkgs, lib, ... }:

{
  options.custom.packages = {
    enable = lib.mkEnableOption "system packages management";

    core.enable = lib.mkEnableOption "core system packages" // { default = true; };
    devTools.enable = lib.mkEnableOption "development tools" // { default = true; };
    systemTools.enable = lib.mkEnableOption "system administration tools" // { default = true; };
    monitoring.enable = lib.mkEnableOption "system monitoring tools" // { default = true; };
    guiTools.enable = lib.mkEnableOption "GUI applications" // { default = false; };
    comparison.enable = lib.mkEnableOption "comparison and analysis tools" // { default = false; };
  };

  config = lib.mkIf config.custom.packages.enable {
    environment.systemPackages = with pkgs;
      (lib.optionals config.custom.packages.core.enable [
        # Core system utilities
        vim # https://www.vim.org/
        wget # https://www.gnu.org/software/wget/
        git # https://git-scm.com/
        github-cli # https://cli.github.com/ - Git Hub CLI
        curl # https://curl.se/
        file # https://darwinsys.com/file/
        openssl # https://www.openssl.org/ - SSL/TLS toolkit
        cacert # CA certificate bundle
      ])
      ++ (lib.optionals config.custom.packages.systemTools.enable [
        # System administration and hardware tools
        pciutils # https://mf.kernel.org/~paulus/pciutils/ - PCI device information
        usbutils # https://linux-usb.sourceforge.io/ - USB device information
        lshw # https://ezix.org/project/wiki/HardwareLiSter - hardware information
        pstree # https://www.kernel.org/doc/html/latest/admin-guide/sysctl/kernel.html - process tree
        fd # https://github.com/sharkdp/fd - find alternative
        eza # https://github.com/eza-community/eza - ls alternative
      ])
      ++ (lib.optionals config.custom.packages.devTools.enable [
        # Development tools
        git # https://git-scm.com/
        meson # https://mesonbuild.com/ - build system
        bazel_7 # https://bazel.build/ - build system
        niv # https://github.com/nmattia/niv - Nix dependency manager
        claude-code # https://github.com/anthropics/claude-code - Claude Code CLI
        _1password-cli # https://1password.com/ - password manager CLI
      ])
      ++ (lib.optionals config.custom.packages.monitoring.enable [
        # System monitoring and performance tools
        htop # https://htop.dev/ - interactive process viewer
        btop # https://github.com/aristocratos/btop - resource monitor
        ripgrep # https://github.com/BurntSushi/ripgrep - fast search tool
        amdgpu_top # https://github.com/Umio-Yasuno/amdgpu_top - AMD GPU monitoring
        perf # https://perf.wiki.kernel.org/ - performance analysis
      ])
      ++ (lib.optionals config.custom.packages.guiTools.enable [
        # GUI applications
        gnome-tweaks # https://wiki.gnome.org/Apps/Tweaks - GNOME settings editor
        _1password-gui # https://1password.com/ - password manager GUI
        mumble # https://www.mumble.info/ - Voice chat client
        supersonic # https://github.com/dweymouth/supersonic - Subsonic/Navidrome client
      ])
      ++ (lib.optionals config.custom.packages.comparison.enable [
        # Comparison and analysis tools
        bcompare # https://www.scootersoftware.com/ - file/folder comparison
      ]);
  };
}
