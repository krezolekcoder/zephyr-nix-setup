# OrbStack helpers for running Zephyr native_sim on Linux from macOS.
#
# Provides a `native-sim` script that:
#   1. Builds a Zephyr sample inside the OrbStack VM (reusing the macOS workspace)
#   2. Runs the resulting ELF inside the VM and streams output back
#
# Usage (inside nix devShell):
#   native-sim                                   # builds & runs hello_world
#   native-sim zephyr/samples/philosophers       # any sample relative to workspace
#   native-sim zephyr/samples/hello_world -- -DCONFIG_FOO=y   # extra cmake args

{ pkgs
, orbMachine    ? "ubuntu-zephyr-native-sim"
, zephyrWorkspace ? "/Users/kamilkrezolek/zephyr-workspace"
}:

let
  nativeSim = pkgs.writeShellScriptBin "native-sim" ''
    set -euo pipefail

    MACHINE="${orbMachine}"
    WORKSPACE="${zephyrWorkspace}"
    SAMPLE="''${1:-zephyr/samples/hello_world}"
    BUILD_DIR="/tmp/native-sim-build/$(basename "$SAMPLE")"

    # Split args: everything after -- goes to west as extra cmake args
    shift || true
    EXTRA_ARGS="$*"

    echo "==> Building $SAMPLE on $MACHINE..."
    orb run -m "$MACHINE" bash -lc "
      set -euo pipefail
      source \"\$HOME/.venv/zephyr/bin/activate\"
      export ZEPHYR_BASE=$WORKSPACE/zephyr
      export ZEPHYR_TOOLCHAIN_VARIANT=host
      west build -b native_sim/native/64 $WORKSPACE/$SAMPLE \
        --build-dir $BUILD_DIR \
        $EXTRA_ARGS
    "

    echo "==> Running $BUILD_DIR/zephyr/zephyr.exe..."
    orb run -m "$MACHINE" "$BUILD_DIR/zephyr/zephyr.exe"
  '';

in {
  packages = [ nativeSim ];
}
