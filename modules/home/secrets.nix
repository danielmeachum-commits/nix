{ config, pkgs, lib, inputs, ... }:

{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../secrets/secrets.yaml;

    secrets.LINEAR_API_KEY = { };

    # Decrypted at activation into a runtime-only path (never the nix store),
    # so plain-text env vars never land in the git repo or /nix/store.
    templates."env-secrets.sh".content = ''
      export LINEAR_API_KEY="${config.sops.placeholder.LINEAR_API_KEY}"
    '';
  };
}
