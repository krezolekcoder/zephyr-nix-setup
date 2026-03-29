{
  description = "Zephyr development environment scaffold";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zephyr-nix = {
      url = "github:adisbladis/zephyr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zephyr-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zephyrPkgs = zephyr-nix.packages.${system};

        # Import the shell factory, injecting shared dependencies
        mkZephyrShell = import ./lib/mkZephyrShell.nix {
          inherit pkgs zephyrPkgs;
        };
      in
      {
        # Expose mkZephyrShell so project flakes can consume it
        lib = { inherit mkZephyrShell; };

        # Top-level convenience shells — use with: nix develop .#<name>
        devShells = {
          # Minimal shell: just west + common build tools, no SDK
          # Includes `native-sim` helper for running samples via OrbStack
          default = mkZephyrShell {
            withNativeSim = true;
          };

          # ARM shell (nRF52, STM32, etc.) with JLink
          arm = mkZephyrShell {
            targets = [ "arm" ];
            withJlink = true;
          };

          # RISC-V shell with OpenOCD
          riscv = mkZephyrShell {
            targets = [ "riscv" ];
            withOpenocd = true;
          };
        };
      }
    );
}
