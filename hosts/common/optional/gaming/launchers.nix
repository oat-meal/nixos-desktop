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

    # Wine support (WoW64: both 32- and 64-bit — needed for 64-bit Windows games)
    #
    # 26.05 deprecates this in favour of wineWow64Packages. NOT changed here on
    # purpose: that is a different build (upstream's new-WoW64, a 64-bit-only wine
    # that runs 32-bit apps without a 32-bit library stack), not a rename, so it can
    # change behaviour for older 32-bit titles. Deprecated still builds and works.
    # Switch deliberately, with a game to test against — not inside a channel migration.
    wineWowPackages.stable
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
