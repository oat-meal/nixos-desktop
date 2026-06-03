{ config, pkgs, lib, ... }:

{
  ################################
  ## YubiKey - Base Configuration
  ## udev rules, pcscd, management tools
  ################################

  ################################
  ## Smart Card Daemon
  ################################
  services.pcscd.enable = true;

  ################################
  ## udev rules for YubiKey access
  ################################
  services.udev.packages = [ pkgs.yubikey-personalization ];

  ################################
  ## Required packages
  ################################
  environment.systemPackages = with pkgs; [
    # YubiKey management
    yubikey-manager      # ykman CLI
    yubikey-manager-qt   # GUI for YubiKey management
    yubikey-personalization # ykpersonalize for OTP config

    # FIDO2/U2F
    libfido2             # fido2-token CLI

    # PIV/Smart Card
    yubico-piv-tool      # PIV management
    opensc               # Smart card utilities

    # GPG smart card support
    gnupg
    pinentry-gtk2        # PIN entry dialog
  ];

  ################################
  ## GPG smart card daemon socket
  ## Required for GPG operations with YubiKey
  ################################
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = false;
    pinentryPackage = pkgs.pinentry-gtk2;
  };

  ################################
  ## Polkit rule for YubiKey management
  ## Allows users in plugdev group to manage YubiKeys
  ################################
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.debian.pcsc-lite.access_pcsc" &&
          subject.isInGroup("plugdev")) {
        return polkit.Result.YES;
      }
    });
  '';
}
