# native_sim helper module.
#
# Provides a `native-sim` script that builds and runs Zephyr native_sim samples:
#   - macOS: delegates to an OrbStack Linux VM (Linux required for native_sim)
#   - Linux: builds and runs directly in the current shell
#
# Also provides an `orb` stub on Linux that exits with a helpful error,
# rather than a confusing "command not found".
#
# Usage (inside nix devShell):
#   native-sim                                   # builds & runs hello_world
#   native-sim zephyr/samples/philosophers       # any sample relative to workspace
#   native-sim zephyr/samples/hello_world -- -DCONFIG_FOO=y   # extra cmake args

{ pkgs
, orbMachine      ? "ubuntu-zephyr-native-sim"  # macOS only
, zephyrWorkspace ? ""   # defaults to $HOME/zephyr-workspace at runtime
}:

let
  nativeSim = pkgs.writeShellScriptBin "native-sim" (
    if pkgs.stdenv.isDarwin then ''
      set -euo pipefail

      MACHINE="${orbMachine}"
      WORKSPACE="${zephyrWorkspace}"
      WORKSPACE="''${WORKSPACE:-$HOME/zephyr-workspace}"
      SAMPLE="''${1:-zephyr/samples/hello_world}"
      BUILD_DIR="/tmp/native-sim-build/$(basename "$SAMPLE")"

      shift || true
      EXTRA_ARGS="$*"

      echo "==> Building $SAMPLE on $MACHINE (OrbStack)..."
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

    '' else ''
      set -euo pipefail

      WORKSPACE="${zephyrWorkspace}"
      WORKSPACE="''${WORKSPACE:-$HOME/zephyr-workspace}"
      SAMPLE="''${1:-zephyr/samples/hello_world}"
      BUILD_DIR="/tmp/native-sim-build/$(basename "$SAMPLE")"

      shift || true
      EXTRA_ARGS="$*"

      export ZEPHYR_BASE="$WORKSPACE/zephyr"
      export ZEPHYR_TOOLCHAIN_VARIANT=host

      echo "==> Building $SAMPLE..."
      west build -b native_sim/native/64 "$WORKSPACE/$SAMPLE" \
        --build-dir "$BUILD_DIR" \
        $EXTRA_ARGS

      echo "==> Running $BUILD_DIR/zephyr/zephyr.exe..."
      "$BUILD_DIR/zephyr/zephyr.exe"
    '')
  );

  # On Linux: provide a stub that explains orb is macOS-only
  orbStub = pkgs.writeShellScriptBin "orb" ''
    echo "error: OrbStack (orb) is macOS-only." >&2
    echo "On Linux, native_sim runs directly — use 'native-sim' instead." >&2
    exit 1
  '';

in {
  packages = [ nativeSim ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ orbStub ];
}
