# JLink tooling module.
#
# JLink is proprietary (SEGGER license). On macOS, nixpkgs does not package it
# as a derivation you can install silently — you must accept the EULA.
#
# Two strategies, pick one:
#
#   A) Install JLink system-wide via nix-darwin (recommended for macOS):
#        environment.systemPackages = [ pkgs.segger-jlink ];
#      Then set `withJlink = false` here and rely on the system install.
#
#   B) Use the pkgs.segger-jlink derivation below. nixpkgs will prompt you
#      to set `allowUnfree = true` and accept the SEGGER EULA.
#      Add to your nixpkgs config:
#        nixpkgs.config.allowUnfreePredicate = pkg:
#          builtins.elem (lib.getName pkg) [ "segger-jlink" ];

{ pkgs }:

let
  # segger-jlink is Linux-only in nixpkgs as of 2025.
  # On macOS, fall back to a stub that tells the user to install manually.
  jlinkPackage =
    if pkgs.stdenv.isLinux
    then pkgs.segger-jlink
    else
      pkgs.writeShellScriptBin "JLinkExe" ''
        echo "JLink not available via Nix on macOS."
        echo "Install manually from https://www.segger.com/downloads/jlink/"
        echo "or via: brew install --cask segger-jlink"
        exit 1
      '';

in {
  packages = [
    jlinkPackage

    # ARM GDB for use with JLink GDB server
    pkgs.gdb

    # Optional: Ozone (SEGGER graphical debugger) — also Linux-only in nixpkgs
    # pkgs.ozone
  ];
}
