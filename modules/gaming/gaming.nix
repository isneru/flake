{ ... }:
{
  flake.modules.nixos.gaming =
    { config, pkgs, ... }:
    {
      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia = {
        package = config.boot.kernelPackages.nvidiaPackages.stable;
        open = true;
        modesetting.enable = true;
        powerManagement.enable = true;
        powerManagement.finegrained = true;
        dynamicBoost.enable = true;

        prime = {
          offload.enable = true;
          offload.enableOffloadCmd = true;
        };
      };

      hardware.graphics.enable32Bit = true;

      programs.steam = {
        enable = true;
        gamescopeSession.enable = true;
        remotePlay.openFirewall = true;
        extraCompatPackages = [ pkgs.proton-ge-bin ];
        extraPackages = [ pkgs.libGLU ];
      };

      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };

      programs.gamemode = {
        enable = true;
        settings.custom = {
          start = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
          end = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced";
        };
      };

      services.ananicy = {
        enable = true;
        package = pkgs.ananicy-cpp;
        rulesProvider = pkgs.ananicy-rules-cachyos;
      };

      boot.kernelParams = [ "split_lock_detect=off" ];
    };

  flake.modules.homeManager.gaming =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "gamerun";
          runtimeInputs = with pkgs; [ gamemode ];
          text = builtins.readFile ./gamerun.sh;
        })
      ]
      ++ (with pkgs; [
        # keep-sorted start
        heroic
        mangohud
        mesa-demos
        prismlauncher
        protonplus
        protontricks
        vulkan-tools
        # keep-sorted end
      ]);
    };
}
