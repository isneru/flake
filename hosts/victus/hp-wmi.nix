{ config, ... }:
let
  kernel = config.boot.kernelPackages.kernel;
  moduleDir = "lib/modules/${kernel.modDirVersion}";
in
{
  boot.extraModulePackages = [
    (kernel.stdenv.mkDerivation {
      pname = "hp-wmi-8a26";
      inherit (kernel) version src;
      nativeBuildInputs = kernel.moduleBuildDependencies;

      postPatch = ''
        substituteInPlace drivers/platform/x86/hp/hp-wmi.c \
          --replace-fail '"8A25"' '"8A25", "8A26"'
        echo 'obj-m += hp-wmi.o' > drivers/platform/x86/hp/Kbuild
      '';

      buildPhase = ''
        make -C ${kernel.dev}/${moduleDir}/build M=$PWD/drivers/platform/x86/hp modules
      '';

      installPhase = ''
        install -Dm444 drivers/platform/x86/hp/hp-wmi.ko $out/${moduleDir}/updates/hp-wmi.ko
        mkdir -p $out/etc/depmod.d
        echo 'override hp_wmi * updates' > $out/etc/depmod.d/hp-wmi.conf
      '';
    })
  ];
}
