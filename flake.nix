{
  description = "NixOS Lab - Multi-host infrastructure with MangoWM desktop, home server, and laptop";

  ################################
  ## FLAKE INPUTS
  ################################
  inputs = {
    # Stable (system base)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Unstable (for Discord, cutting-edge libs, etc.)
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sops-nix — runtime secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia — native Wayland desktop shell (v5). Evaluating on the workstation;
    # follows nixpkgs (builds from source, no upstream binary cache).
    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MangoWM — dwl-based Wayland compositor. The desktop compositor on all
    # desktop hosts (niri fully removed 2026-07-04).
    #
    # Follows nixpkgs-unstable, NOT nixpkgs: since 2026-07-08 mango requires
    # wlroots_0_20, which 25.11 does not package (it stops at 0_19). Pinning
    # mango back to a wlroots_0_19 rev is not an option — the selmon NULL-deref
    # fix in keypress() landed after that bump, and that crash takes the whole
    # session down on the first keypress after the only monitor sleeps.
    # Revisit if/when 25.11 gains wlroots_0_20.
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  ################################
  ## FLAKE OUTPUTS
  ################################
  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, zen-browser, sops-nix, noctalia, mango, ... }:
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
              inherit self nixpkgs nixpkgs-unstable home-manager noctalia mango;
            };
          };

          modules = [
            # Host-specific configuration
            hostPath

            # Runtime secrets
            sops-nix.nixosModules.sops

            # Overlays
            { nixpkgs.overlays = [
              unstableOverlay
              (final: prev: { zen-browser = zen-browser.packages.${system}.default; })
            ]; }
          ]
          # Desktop compositor (MangoWM) is imported per-host via hosts/*/default.nix
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
                inherit system hostname;
                inputs = {
                  inherit self nixpkgs nixpkgs-unstable home-manager noctalia mango;
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
        # AMD Ryzen 9950X, MangoWM compositor, gaming optimizations
        workstation-nixos = mkSystem {
          hostname = "workstation-nixos";
          hostPath = ./hosts/workstation/default.nix;
        };

        # Framework 13 Laptop
        # AMD Ryzen, MangoWM compositor, power management
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
