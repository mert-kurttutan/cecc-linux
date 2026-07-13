{
  description = "Dev shell for Casper WMI kernel driver work";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    host-nixos.url = "path:/etc/nixos";
  };

  outputs = { self, nixpkgs, host-nixos }:
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
          hostConfig = host-nixos.nixosConfigurations.nixos.config;
          kernel = hostConfig.boot.kernelPackages.kernel;
          kdir = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
          guiLibs = with pkgs; [
            fontconfig
            wayland
            wayland-protocols
            libxkbcommon
            vulkan-loader
            mesa
          ];
          runtimeLibs = guiLibs ++ pkgs.lib.optional (hostConfig.hardware.nvidia.package != null) hostConfig.hardware.nvidia.package;
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

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;

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
