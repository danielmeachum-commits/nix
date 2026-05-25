{ config, pkgs, lib, ... }:

{
  options.custom.terminal.enable = lib.mkEnableOption "terminal emulator config";

  config = lib.mkIf config.custom.terminal.enable {
    programs.kitty = {
      enable = true;
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 12;
      };
      settings = {
        shell = "${pkgs.zsh}/bin/zsh";
        cursor_shape = "beam";
        enable_audio_bell = false;
        window_padding_width = 8;
        hide_window_decorations = "yes";
        confirm_os_window_close = 0;
        copy_on_select = "yes";
        scrollback_lines = 100000;
        tab_bar_edge = "top";
        tab_bar_style = "powerline";
        background_opacity = "0.95";
        enabled_layouts = "splits,stack";
      };
      keybindings = {
        "ctrl+shift+enter" = "launch --cwd=current --location=split";
        "ctrl+shift+t"     = "new_tab_with_cwd";
        "ctrl+shift+c"     = "no_op";
        "ctrl+shift+v"     = "no_op";
        "ctrl+c"           = "copy_or_interrupt";
        "ctrl+v"           = "paste_from_clipboard";
      };
      themeFile = "Catppuccin-Mocha";
    };

    programs.tmux = {
      enable = true;
      keyMode = "vi";
      mouse = true;
      baseIndex = 1;
      escapeTime = 10;
      historyLimit = 100000;
      terminal = "tmux-256color";
      extraConfig = ''
        set -ga terminal-overrides ",*256col*:Tc"
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"
      '';
      plugins = with pkgs.tmuxPlugins; [
        sensible
        yank
        resurrect
        continuum
      ];
    };
  };
}
