{
  description = "Hobbes' NixOS + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { self, nixpkgs, home-manager, nur, sops-nix, ... }@inputs:
    let
      system = "x86_64-linux";

      mkHost = { hostname, hardwarePath, extraHomeModules ? [], extraSystemModules ? [] }: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          { networking.hostName = hostname; }
          hardwarePath
          ./configuration.nix
          { nixpkgs.overlays = [ nur.overlays.default ]; }

          home-manager.nixosModules.home-manager
          ({ pkgs, ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.hobbes = { imports = [ ./home.nix ] ++ extraHomeModules; };

            # GNOME/Plasma rewrite some home-manager-managed files at runtime
            # (mimeapps.list, fontconfig's 10-hm-fonts.conf, ...), so each
            # activation wants to back the live file up again — and hard-fails
            # if a .hm-backup with that name is left over from last time. The
            # backups never hold anything but those desktop rewrites of
            # declared files, so sweep leftovers before every activation.
            systemd.services.home-manager-hobbes.preStart = ''
              ${pkgs.findutils}/bin/find /home/hobbes -maxdepth 1 -name '*.hm-backup' -type f -print -delete || true
              ${pkgs.findutils}/bin/find /home/hobbes/.config /home/hobbes/.local -name '*.hm-backup' -type f -print -delete || true
            '';
          })
        ] ++ extraSystemModules;
      };
    in {
      nixosConfigurations = {
        hobbes-svr = mkHost {
          hostname = "hobbes-svr";
          hardwarePath = ./hosts/server/hardware-configuration.nix;
          extraHomeModules = [ { custom.vmdev.enable = true; } ];
          extraSystemModules = [ ./hosts/server/default.nix ];
        };

        hobbes-lap = mkHost {
          hostname = "hobbes-lap";
          hardwarePath = ./hosts/laptop/hardware-configuration.nix;
          extraHomeModules = [ { custom.vmdev.enable = true; } ];
          extraSystemModules = [ ./hosts/laptop/default.nix ];
        };
      };

      homeConfigurations.hobbes = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${system};
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./home.nix ];
      };

      apps.${system}.vm = {
        type = "app";
        program = "${self.nixosConfigurations.hobbes-svr.config.system.build.vm}/bin/run-hobbes-svr-vm";
      };
    };
}
