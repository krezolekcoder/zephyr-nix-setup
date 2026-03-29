# zephyr-nix-setup

Nix flake scaffold for reproducible Zephyr RTOS development environments on macOS and Linux.

**What you get:**
- A `nix develop` shell with all Zephyr build tools (west, cmake, ninja, dtc, …)
- Optional toolchain targets (ARM, RISC-V) and debug tools (JLink, OpenOCD, pyOCD)
- A `native-sim` helper script to build and run Zephyr native_sim samples on macOS via OrbStack — no Linux machine required, no re-downloading your existing workspace

---

## Prerequisites

- [Nix](https://nixos.org/download) with flakes enabled
- [OrbStack](https://orbstack.dev) (macOS only, for native_sim)

**Enable flakes** if you haven't already — add to `~/.config/nix/nix.conf`:
```
experimental-features = nix-flakes nix-command
```

---

## Quick start

```bash
git clone https://github.com/yourname/zephyr-nix-setup
cd zephyr-nix-setup
nix develop          # minimal shell: west + build tools
nix develop .#arm    # ARM shell with JLink
nix develop .#riscv  # RISC-V shell with OpenOCD
```

---

## Adding to your Zephyr project

Add a `flake.nix` to the root of your project repo:

```nix
{
  description = "My Zephyr project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zephyr-nix = {
      url = "github:adisbladis/zephyr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zephyr-nix-setup = {
      url = "github:yourname/zephyr-nix-setup";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zephyr-nix.follows = "zephyr-nix";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zephyr-nix-setup, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        mkZephyrShell = zephyr-nix-setup.lib.${system}.mkZephyrShell;
      in
      {
        devShells.default = mkZephyrShell {
          targets   = [ "arm" ];
          withJlink = true;

          extraEnv = {
            BOARD = "nrf52840dk_nrf52840";
          };
        };
      }
    );
}
```

Then:
```bash
nix develop   # enters the Zephyr shell for your project
```

Optionally add `.envrc` for automatic activation on `cd`:
```bash
echo "use flake" > .envrc
direnv allow
```

---

## Running native_sim on macOS

Zephyr's native simulator requires Linux. On macOS, OrbStack provides a lightweight Linux VM that mounts your macOS filesystem automatically — so your existing Zephyr workspace is reused directly, no re-downloading needed.

### One-time VM setup

Create an Ubuntu VM in OrbStack, then run the bootstrap script:

```bash
# Create the VM (in OrbStack UI or CLI)
orb create ubuntu ubuntu-zephyr-native-sim

# Bootstrap it
bash scripts/setup-orb-vm.sh
```

The script installs the minimal Linux toolchain inside the VM (~few hundred MB). Your Zephyr workspace on macOS is accessed via OrbStack's automatic filesystem mount at the same path.

### Usage

Enable the `native-sim` script in your `flake.nix`:

```nix
devShells.default = mkZephyrShell {
  withNativeSim = true;
  # ...
};
```

Then from inside `nix develop`:

```bash
# Build and run hello_world (default)
native-sim

# Any sample, relative to your workspace root
native-sim zephyr/samples/philosophers

# Pass extra CMake args
native-sim zephyr/samples/hello_world -- -DCONFIG_BOOT_BANNER=n
```

Build artifacts are stored inside the VM at `/tmp/native-sim-build/` and persist until the VM reboots. The macOS workspace source is never modified.

> **Note:** `setup-orb-vm.sh` hardcodes `/Users/kamilkrezolek/zephyr-workspace` as the workspace path. Update the `ZEPHYR_WORKSPACE` variable at the top of the script and the `zephyrWorkspace` argument in `modules/orb.nix` to match your setup.

---

## mkZephyrShell reference

| Argument | Type | Default | Description |
|---|---|---|---|
| `targets` | `[ string ]` | `[]` | Zephyr SDK toolchain targets: `"arm"` `"riscv"` `"x86"` `"xtensa"` … |
| `withJlink` | bool | `false` | Include JLink tools (Linux only via Nix; macOS: install manually) |
| `withOpenocd` | bool | `false` | Include OpenOCD + GDB |
| `withPyocd` | bool | `false` | Include pyOCD |
| `withNativeSim` | bool | `false` | Include `native-sim` OrbStack helper script |
| `extraPackages` | `[ pkg ]` | `[]` | Any additional Nix packages |
| `extraEnv` | attrset | `{}` | Extra environment variables (e.g. `BOARD`) |
| `shellHook` | string | `""` | Extra commands appended to the shell's `shellHook` |

---

## Repository layout

```
flake.nix               # Root flake — exposes devShells and lib.mkZephyrShell
lib/
  mkZephyrShell.nix     # Shell factory function
modules/
  common.nix            # Baseline packages (west, cmake, ninja, …)
  jlink.nix             # JLink tooling
  debug.nix             # OpenOCD / pyOCD
  orb.nix               # OrbStack native-sim helper
scripts/
  setup-orb-vm.sh       # One-time OrbStack VM bootstrap
projects/               # Example project flakes (for reference only)
  example-nrf52/
  example-stm32/
```
