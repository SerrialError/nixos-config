{
  description = "NixOS configuration flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plugin-onedark.url = "github:navarasu/onedark.nvim";
    plugin-onedark.flake = false;
    nix-colors.url = "github:misterio77/nix-colors";
    sops-nix = {
      url = "github:Mic92/sops-nix";
    };
    flux.url = "github:IogaMaster/flux";
    flake-utils.url = "github:numtide/flake-utils";
    cargo-v5.url = "github:vexide/cargo-v5";
    rust-overlay.url = "github:oxalica/rust-overlay";
    vex-v5-simulator-src = {
  	url = "path:./pkgs/vex-v5-simulator.nix";
  	flake = false;
    };
    vex-v5-kernel-src = {
      url = "path:./pkgs/vex-v5-kernel.nix";
      flake = false;
    };
  };
    outputs = { self, nixpkgs, home-manager, flake-utils, rust-overlay, cargo-v5, ... } @ inputs:
  let
    system = "x86_64-linux";

    nightlyToolchain = pkgs.rust-bin.nightly."2025-02-18".default;

    rustPlatformNightly = pkgs.makeRustPlatform {
      cargo = nightlyToolchain;
      rustc = nightlyToolchain;
    };

    myOverlay = final: prev: {
      vex-v5-kernel = import inputs.vex-v5-kernel-src {
        inherit (prev) lib fetchFromGitHub;
        rustPlatform = rustPlatformNightly;
      };
      vex-v5-simulator = import inputs.vex-v5-simulator-src {
        inherit (prev) lib fetchFromGitHub qemu webkitgtk_4_1 libsoup_3 pkg-config glib gtk3 vte libvirt libvirt-glib libxml2 gtk-vnc spice-gtk usbredir makeWrapper;
        rustPlatform = rustPlatformNightly;
      };
    };

    overlays = [
      (import rust-overlay)
      myOverlay
    ];

    crossPkgs = import nixpkgs {
      inherit system overlays;
      crossSystem = { config = "armv7a-none-eabi"; };
      config.allowUnfree = true;
    };

    pkgs = import nixpkgs {
      inherit system overlays;
      config.allowUnfree = true;
    };

    cargo-v5-full = cargo-v5.packages.${system}.cargo-v5-full;

  in {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        inputs.home-manager.nixosModules.default
        {
          nixpkgs.pkgs = pkgs;
        }
      ];
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        cargo-v5-full
        pkgs.llvmPackages.bintools
        pkgs.cargo-binutils
        nightlyToolchain.override {
          extensions = [ "rust-analyzer" "rust-src" "clippy" ];
        }
        pkgs.rustPackages.rust-src
      ];
    };

    packages.${system} = {
      vex-v5-simulator = pkgs.vex-v5-simulator;
      vex-v5-kernel = pkgs.vex-v5-kernel;
    };

    overlays.default = myOverlay;
  };
  # Add the features directory to the Nix store
  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
  };
}
