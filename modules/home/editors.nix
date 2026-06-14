{ config, pkgs, lib, ... }:

{
  options.custom.editors.enable = lib.mkEnableOption "editor suite (VSCode, JetBrains, Neovim)";

  config = lib.mkIf config.custom.editors.enable {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;

      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          # Languages
          ms-python.python
          ms-python.vscode-pylance
          ms-python.debugpy
          rust-lang.rust-analyzer
          golang.go
          bbenoist.nix
          jnoortheen.nix-ide

          # Tooling
          ms-azuretools.vscode-docker     # works with podman via DOCKER_HOST
          eamodio.gitlens
          github.copilot
          github.copilot-chat
          github.vscode-pull-request-github

          # UX
          usernamehw.errorlens
          editorconfig.editorconfig
          esbenp.prettier-vscode
          dbaeumer.vscode-eslint
          ms-vscode-remote.remote-ssh

          # Themes / icons
          catppuccin.catppuccin-vsc
          pkief.material-icon-theme
        ];

        userSettings = {
          "editor.fontFamily" = "'JetBrainsMono Nerd Font', monospace";
          "editor.fontSize" = 13;
          "editor.fontLigatures" = true;
          "editor.formatOnSave" = true;
          "editor.minimap.enabled" = false;
          "editor.bracketPairColorization.enabled" = true;
          "editor.guides.bracketPairs" = "active";
          "editor.cursorSmoothCaretAnimation" = "on";
          "editor.smoothScrolling" = true;
          "files.trimTrailingWhitespace" = true;
          "files.insertFinalNewline" = true;
          "terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font'";
          "terminal.integrated.defaultProfile.linux" = "zsh";
          "workbench.colorTheme" = "Catppuccin Mocha";
          "workbench.iconTheme" = "material-icon-theme";
          "window.titleBarStyle" = "custom";

          "docker.dockerPath" = "${pkgs.podman}/bin/podman";

          # Native Wayland.
          "window.experimental.useSandbox" = false;

          # Nix
          "nix.enableLanguageServer" = true;
          "nix.serverPath" = "${pkgs.nil}/bin/nil";
          "[nix]"."editor.formatOnSave" = true;
          "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";

          # Python
          "python.defaultInterpreterPath" = "${pkgs.python3}/bin/python";
          "python.terminal.activateEnvironment" = true;
          "[python]"."editor.defaultFormatter" = "charliermarsh.ruff";
        };
      };
    };

    home.packages = with pkgs; [
      jetbrains.idea-oss
      jetbrains-toolbox
      nil
      nixpkgs-fmt
    ];

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      extraPackages = with pkgs; [
        # LSPs
        nil
        pyright
        ruff
        gopls
        rust-analyzer
        typescript-language-server
        lua-language-server

        # tools
        tree-sitter
        ripgrep
        fd
      ];
      plugins = with pkgs.vimPlugins; [
        lazy-nvim
        catppuccin-nvim
        telescope-nvim
        nvim-treesitter.withAllGrammars
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        gitsigns-nvim
        which-key-nvim
      ];
      initLua = ''
        vim.opt.number = true
        vim.opt.relativenumber = true
        vim.opt.expandtab = true
        vim.opt.shiftwidth = 2
        vim.opt.tabstop = 2
        vim.opt.signcolumn = "yes"
        vim.opt.termguicolors = true
        vim.opt.clipboard = "unnamedplus"
        vim.g.mapleader = " "
        vim.cmd.colorscheme("catppuccin-mocha")
      '';
    };
  };
}
