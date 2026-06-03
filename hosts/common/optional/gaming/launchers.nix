# Game launchers and gaming tools
# Lutris, Bottles, Heroic, and related utilities

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Game launchers
    bottles
    lutris
    heroic

    # Gaming session tools
    gamescope

    # GPU control
    corectrl

    # Wine support
    wine
    winetricks
    protontricks

    # Performance monitoring
    goverlay
    nvtopPackages.full
    btop

    # Controller support
    linuxConsoleTools
  ];

  # Gaming mode desktop entry
  environment.etc."steam-gaming.desktop" = {
    text = ''
      [Desktop Entry]
      Name=Steam (Gaming Mode)
      Comment=Launch Steam in Big Picture with GameScope and GameMode optimizations
      Exec=gamemoderun gamescope -W 3840 -H 2160 -r 120 --adaptive-sync --expose-wayland -- steam -gamepadui
      Icon=steam
      Terminal=false
      Type=Application
      Categories=Game;Network;
      StartupNotify=true
    '';
  };
}
