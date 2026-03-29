# zephyr-nix-setup

Nix flake scaffold for reproducible Zephyr RTOS development environments on macOS and Linux.

**What you get:**
- A `nix develop` shell with all Zephyr build tools (west, cmake, ninja, dtc, …)
- Optional toolchain targets (ARM, RISC-V) and debug tools (JLink, OpenOCD, pyOCD)
- A `native-sim` helper script to build and run Zephyr native_sim samples on macOS via OrbStack — no Linux machine required, no re-downloading your existing workspace

---

## Why Nix instead of Docker?

The common alternative for reproducible Zephyr environments is a Docker container (Zephyr provides official images). Nix takes a different approach that works better for day-to-day embedded development.

### The Docker approach and its friction

With Docker you get a Linux container with all tools baked in. This works, but creates a wall between you and your work:

- **Slow iteration** — every build runs inside the container. You need volume mounts, wrapper scripts, or a full IDE integration just to edit files on the host and build inside the container.
- **No native tooling** — debuggers, flash tools, and serial monitors need access to USB devices and the host filesystem. Passing those through Docker requires extra flags and often breaks on macOS.
- **Large images** — the official Zephyr Docker image is several GB and must be re-pulled when the toolchain version changes.
- **macOS pain** — Docker on macOS runs inside a Linux VM (Docker Desktop or Colima). USB passthrough for JLink/ST-Link is unreliable or unsupported. File I/O through the VM is slow.
- **All-or-nothing** — either you are inside the container or you are not. There is no way to selectively add a tool without rebuilding the image.

### What Nix does differently

Nix installs every tool into an isolated path in `/nix/store` and activates them in your current shell via `nix develop`. You stay in your normal terminal, editor, and filesystem — the shell just gains the right tools on `$PATH`.

- **Works on macOS natively** — tools run directly on your Mac. No VM overhead for building, no issues with file I/O performance.
- **Exact reproducibility** — `flake.lock` pins every dependency to a specific hash. The environment is byte-for-byte identical across machines and over time. `nix develop` on a colleague's machine gives exactly the same toolchain versions.
- **Composable** — add or remove tools (JLink, OpenOCD, pyOCD) with a single flag in your `flake.nix`. No Dockerfile to maintain.
- **Per-project isolation** — different projects can use different versions of west, cmake, or the ARM toolchain simultaneously without conflicts.
- **direnv integration** — the shell activates automatically when you `cd` into the project and deactivates when you leave. No manual `docker run` or `source` commands.
- **No daemon, no image pull** — tools are fetched and cached in `/nix/store` on first use. Subsequent `nix develop` calls are instant.

### The one thing Docker has over Nix: native_sim

Zephyr's native simulator compiles Zephyr as a Linux process and runs it directly. This requires Linux — it cannot run on macOS regardless of tooling.

This is where OrbStack comes in. Rather than running your entire workflow inside a container, you keep your editor, west workspace, and Nix shell on macOS, and delegate only the `native_sim` build and run step to a lightweight OrbStack VM. The VM mounts your macOS filesystem automatically, so your existing 16 GB Zephyr workspace is reused — nothing is copied or re-downloaded. The `native-sim` script in this repo handles this transparently with a single command.

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

> **Custom paths:** By default the workspace is assumed to be at `$HOME/zephyr-workspace` and the VM named `ubuntu-zephyr-native-sim`. Override with env vars:
> ```bash
> ZEPHYR_WORKSPACE=~/projects/zephyr ZEPHYR_ORB_MACHINE=my-vm bash scripts/setup-orb-vm.sh
> ```
> To hardcode a different path in the `native-sim` script, pass `zephyrWorkspace` to `mkZephyrShell` via the `orb.nix` module.

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
