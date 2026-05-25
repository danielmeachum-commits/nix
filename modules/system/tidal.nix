{ config, pkgs, lib, ... }:

{
  options.custom.tidal = {
    enable = lib.mkEnableOption "Tidal download tooling (installs uv so `uv tool install tidal-dl-ng` works)";
  };

  config = lib.mkIf config.custom.tidal.enable {
    # tidal-dl-ng is not packaged in nixpkgs, so we install uv and let the
    # user pull tidal-dl-ng into an isolated venv with `uv tool install`.
    environment.systemPackages = with pkgs; [
      uv
    ];
  };
}
