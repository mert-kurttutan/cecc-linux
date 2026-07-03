{
  description = "Dev shell for Casper WMI kernel driver work";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          kernelPackages = pkgs.linuxPackages;
          kernel = kernelPackages.kernel;
          kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
          guiLibs = with pkgs; [
            fontconfig
            wayland
            wayland-protocols
            libxkbcommon
            vulkan-loader
            mesa
          ];
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nushell
              gnumake
              gcc
              binutils
              elfutils
              kmod
              pkg-config
            ] ++ guiLibs
              ++ kernel.moduleBuildDependencies ++ [
                kernel.dev
              ];

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath guiLibs;

            shellHook = ''
              export DRIVER_DIR="$PWD/casper-wmi"
              export KDIR="${kdir}"
              export MODULE_NAME="casper_wmi"

              echo "driver dir: $DRIVER_DIR"
              echo "kernel build dir: $KDIR"
              echo "reload loop: nu ./scripts/reload.nu"
            '';
          };
        });
    };
}
