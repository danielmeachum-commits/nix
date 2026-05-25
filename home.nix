{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./modules/home/shell.nix
    ./modules/home/git.nix
    ./modules/home/terminal.nix
    ./modules/home/editors.nix
    ./modules/home/dev.nix
    ./modules/home/gnome.nix
    ./modules/home/firefox.nix
  ];

  home.username = "hobbes";
  home.homeDirectory = "/home/hobbes";

  # Picked up by `uv tool install`, `pipx install`, `cargo install`, etc.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Pin home-manager to a release. Don't change this after first activation.
  home.stateVersion = "26.05";

  # Let HM manage itself.
  programs.home-manager.enable = true;

  # XDG user dirs — make `cd ~/dev` etc. predictable.
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    extraConfig = {
      XDG_DEV_DIR = "$HOME/dev";
    };
  };

  custom.shell.enable = true;
  custom.git.enable = true;
  custom.terminal.enable = true;
  custom.editors.enable = true;
  custom.dev.enable = true;
  custom.gnome.enable = true;
}
