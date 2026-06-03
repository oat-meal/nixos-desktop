{
  description = "NixOS Lab - Multi-host infrastructure with Niri desktop, home server, and laptop";

  ################################
  ## FLAKE INPUTS
  ################################
  inputs = {
    # Stable (system base)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Unstable (for Discord, cutting-edge libs, etc.)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Niri compositor (scrollable tiling Wayland)
    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  ################################
  ## FLAKE OUTPUTS
  ################################
  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, niri-flake, zen-browser, ... }:
    let
      system = "x86_64-linux";

      # Shared overlay for unstable packages
      unstableOverlay = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config = prev.config;
        };
      };

      # Builder helper for NixOS hosts
      mkSystem = { hostname, hostPath, extraModules ? [], enableHomeManager ? true, enableDesktop ? true }:
        nixpkgs.lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit system;
            inputs = {
              inherit self nixpkgs nixpkgs-unstable home-manager niri-flake;
            };
          };

          modules = [
            # Host-specific configuration
            hostPath

            # Overlays
            { nixpkgs.overlays = [
              unstableOverlay
              (final: prev: { zen-browser = zen-browser.packages.${system}.default; })
            ]; }
          ]
          ++ (if enableDesktop then [
            # Niri compositor (desktop hosts only)
            niri-flake.nixosModules.niri
            { nixpkgs.overlays = [ niri-flake.overlays.niri ]; }
          ] else [])
          ++ extraModules
          ++ (if enableHomeManager then [
            # Home Manager integration
            home-manager.nixosModules.home-manager
            {
              home-manager.sharedModules = [
                { nixpkgs.overlays = [ unstableOverlay ]; }
              ];
              home-manager.users.oat = import ./home/oat/default.nix;
              home-manager.extraSpecialArgs = {
                inherit system;
                inputs = {
                  inherit self nixpkgs nixpkgs-unstable home-manager niri-flake;
                };
              };
              home-manager.backupFileExtension = "hm_bak";
            }
          ] else []);
        };

    in {
      ############################################################
      ## INSTALLER ISO
      ############################################################

      packages.${system}.installer-iso = (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ./installer/default.nix
          { nixpkgs.overlays = [ unstableOverlay ]; }
          { nixpkgs.config.allowUnfree = true; }
        ];
      }).config.system.build.isoImage;

      ############################################################
      ## HOSTS
      ############################################################

      nixosConfigurations = {
        # Gaming Workstation
        # AMD Ryzen 9950X, Niri compositor, gaming optimizations
        workstation-nixos = mkSystem {
          hostname = "workstation-nixos";
          hostPath = ./hosts/workstation/default.nix;
        };

        # Framework 13 Laptop
        # AMD Ryzen, Niri compositor, power management
        laptop-nixos = mkSystem {
          hostname = "laptop-nixos";
          hostPath = ./hosts/laptop/default.nix;
        };

        # Home Server — Framework Server (headless)
        # AMD Ryzen AI Max+ 395, 128GB RAM, Ollama/Jellyfin/AdGuard
        server-nixos = mkSystem {
          hostname = "server-nixos";
          hostPath = ./hosts/server/default.nix;
          enableDesktop = false;
          enableHomeManager = false;
        };
      };
    };
}
