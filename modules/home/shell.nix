{ config, pkgs, lib, ... }:

{
  options.custom.shell.enable = lib.mkEnableOption "shell environment";

  config = lib.mkIf config.custom.shell.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      history = {
        size = 100000;
        save = 100000;
        ignoreDups = true;
        ignoreSpace = true;
        share = true;
      };

      shellAliases = {
        ll = "eza -lah --group-directories-first --icons";
        ls = "eza --group-directories-first --icons";
        lt = "eza --tree --level=2 --icons";
        cat = "bat --paging=never";
        grep = "rg";
        find = "fd";
        cd = "z";       # zoxide override

        # Podman quality of life
        docker = "podman";
        dc = "podman-compose";

        # Niri / system
        nrs = "$HOME/nixos-config/rebuild.sh";
        nrt = "sudo nixos-rebuild test --flake .#hobbes";
        nfu = "nix flake update";
      };

      initContent = ''
        # Ctrl-R / Ctrl-T fzf bindings
        [[ -f ${pkgs.fzf}/share/fzf/key-bindings.zsh ]] && source ${pkgs.fzf}/share/fzf/key-bindings.zsh
        [[ -f ${pkgs.fzf}/share/fzf/completion.zsh ]] && source ${pkgs.fzf}/share/fzf/completion.zsh
      '';
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        add_newline = true;
        command_timeout = 1000;
        format = lib.concatStrings [
          "$username$hostname$directory$git_branch$git_status$nix_shell$python$nodejs$rust$golang$cmd_duration$line_break$character"
        ];
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
        directory.truncation_length = 4;
        git_branch.symbol = "⎇ ";
        nix_shell.format = "via [❄ $state]($style) ";
      };
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      defaultOptions = [ "--height=40%" "--layout=reverse" "--border" ];
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    programs.bat.enable = true;
    programs.eza = {
      enable = true;
      enableZshIntegration = false;
    };
  };
}
