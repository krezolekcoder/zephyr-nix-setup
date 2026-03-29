# Factory function for Zephyr devShells.
#
# Usage:
#   mkZephyrShell {
#     targets    = [ "arm" ];        # Zephyr SDK toolchain targets to include
#     withJlink  = true;             # Include JLink tools
#     withOpenocd = false;           # Include OpenOCD
#     withNativeSim = true;          # Include `native-sim` OrbStack helper script
#     extraPackages = [ pkgs.foo ];  # Any extra packages
#     extraEnv   = { FOO = "bar"; }; # Extra shell env vars
#     shellHook  = ''echo "ready"''; # Extra shellHook commands
#   }
#
# All arguments are optional. The defaults produce a minimal shell with
# just west, cmake, ninja, and the common Zephyr Python environment.

{ pkgs, zephyrPkgs }:

{
  # Zephyr SDK toolchain targets to activate.
  # Valid values: "arm" "riscv" "x86" "xtensa" "arc" "mips" "nios2" "sparc"
  # See: https://github.com/adisbladis/zephyr-nix
  targets ? [ ],

  # Debug / flash tool toggles
  withJlink      ? false,
  withOpenocd    ? false,
  withPyocd      ? false,

  # OrbStack native_sim helper — adds `native-sim` script to PATH
  withNativeSim  ? false,

  # Escape hatch: bolt on arbitrary packages
  extraPackages ? [ ],

  # Extra environment variables merged into the shell
  extraEnv ? { },

  # Extra commands appended to shellHook
  shellHook ? "",
}:

let
  commonPkgs  = import ../modules/common.nix  { inherit pkgs zephyrPkgs; };
  jlinkPkgs   = import ../modules/jlink.nix   { inherit pkgs; };
  debugPkgs   = import ../modules/debug.nix   { inherit pkgs; };
  orbPkgs     = import ../modules/orb.nix     { inherit pkgs; };

  # Pick the right SDK based on requested targets.
  # zephyr-nix exposes:
  #   zephyrPkgs.sdk              — full SDK (all toolchains, ~2 GB)
  #   zephyrPkgs.sdkAarch         — per-arch SDKs (arm, riscv, …)
  # We build a minimal SDK containing only the requested targets.
  sdk =
    if targets == [ ]
    then [ ]  # No SDK — useful for host-only / west init workflows
    else map (t: zephyrPkgs.hosttools) targets  # placeholder; see note below
    # NOTE: zephyr-nix currently exposes `zephyrPkgs.sdk` (full) and
    # `zephyrPkgs.hosttools`. Per-target SDKs are not yet stable upstream.
    # Replace the above with:
    #   [ (zephyrPkgs.sdk.override { targets = targets; }) ]
    # once https://github.com/adisbladis/zephyr-nix supports target filtering.
  ;

  conditionalPkgs =
    (if withJlink      then jlinkPkgs.packages else []) ++
    (if withOpenocd    then debugPkgs.openocd  else []) ++
    (if withPyocd      then debugPkgs.pyocd    else []) ++
    (if withNativeSim  then orbPkgs.packages   else []);

  allPackages = commonPkgs ++ sdk ++ conditionalPkgs ++ extraPackages;

  # Merge extra env vars into the shell environment
  envAttrs = {
    ZEPHYR_TOOLCHAIN_VARIANT = if withJlink then "gnuarmemb" else "zephyr";
  } // extraEnv;

in
pkgs.mkShell (envAttrs // {
  packages = allPackages;

  shellHook = ''
    # Re-expose system paths hidden by nix develop (OrbStack, Homebrew, etc.)
    export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

    echo "Zephyr dev shell ready"
    echo "  targets:  ${if targets == [] then "(none)" else builtins.concatStringsSep ", " targets}"
    echo "  jlink:    ${if withJlink then "yes" else "no"}"
    echo "  openocd:  ${if withOpenocd then "yes" else "no"}"
    ${shellHook}
  '';
})
