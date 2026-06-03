# GameMode configuration
# System optimization daemon for gaming sessions
# Override coreCount in host config based on CPU

{ config, lib, pkgs, ... }:

{
  ##############################
  ## GameMode polkit rules    ##
  ##############################
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var dominated = ["cpugovctl", "gpuclockctl", "procsysctl"];
      if (action.id == "org.freedesktop.policykit.exec" && subject.isInGroup("wheel")) {
        var program = action.lookup("program");
        if (program) {
          for (var i = 0; i < dominated.length; i++) {
            if (program.indexOf(dominated[i]) >= 0) {
              return polkit.Result.YES;
            }
          }
        }
      }
    });
  '';

  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      general = {
        renice = 10;
        ioprio = 0;
        inhibit_screensaver = 1;
        softrealtime = "auto";
        reaper_freq = 5;
        desiredgov = "performance";
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = lib.mkDefault 0;
        amd_performance_level = "high";
      };
      cpu = {
        park_cores = "no";
        pin_cores = "yes";
        # Override this per host based on CPU core count
        # Desktop (16 cores): 12, Laptop (8 cores): 6
        core_count = lib.mkDefault 8;
      };
      custom = {
        start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
        end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    gamemode
  ];
}
