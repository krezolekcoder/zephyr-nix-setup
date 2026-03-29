# Open-source debug/flash tools — alternatives or complements to JLink.

{ pkgs }:

let
  pyocdEnv = pkgs.python3.withPackages (ps: with ps; [
    pyocd
  ]);

in {
  # OpenOCD: supports ST-Link, CMSIS-DAP, FTDI, and many others
  openocd = [
    pkgs.openocd
    pkgs.gdb
  ];

  # pyOCD: Python-based, great for CMSIS-DAP and Arm Cortex-M
  pyocd = [
    pyocdEnv
  ];
}
