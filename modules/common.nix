# Common packages included in every Zephyr devShell.
# These are the baseline tools required to build any Zephyr project.

{ pkgs, zephyrPkgs }:

let
  zephyrPython = pkgs.python3.withPackages (ps: with ps; [
    west
    pyelftools
    pyyaml
    packaging
    colorama
    pillow
    jsonschema
  ]);

in [
  # West (Zephyr meta-tool / workspace manager)
  zephyrPython

  # Build system
  pkgs.cmake
  pkgs.ninja
  pkgs.gnumake

  # Device tree
  pkgs.dtc

  # Required by Zephyr's build system
  pkgs.gperf
  pkgs.bison
  pkgs.flex

  # Host toolchain (for native/unit-test builds)
  pkgs.gcc

  # Utilities
  pkgs.git
  pkgs.wget
  pkgs.file

  # direnv integration — lets .envrc auto-activate this shell on `cd`
  pkgs.direnv
  pkgs.nix-direnv

  # NOTE: zephyrPkgs.hosttools (dfu-util etc.) excluded — fails to build on aarch64-darwin
  # Re-add once zephyr-nix fixes macOS Apple Silicon support
]
