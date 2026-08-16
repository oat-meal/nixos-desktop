# INTENTIONALLY NOT IMPORTED BY ANY HOST — this is not dead code.
#
# YubiKey use in this lab is LUKS/FIDO2 unlock only, which needs no PAM or PIV
# integration (that lives in security/luks.nix, via boot.initrd.systemd + fido2).
# This module and pam-u2f.nix stay available but unimported deliberately: adding
# YubiKey to the PAM stack puts a hardware dependency in the sudo/login path, and
# a lost or unplugged key then locks you out of the machine. Import only with a
# tested fallback in place. Same applies to home/common/optional/security/yubikey.nix.
#
# NOTE: server-nixos does not use FIDO2 unlock at all — it is headless, and a touch
# requirement is incompatible with unattended boot. It uses TPM2 (see hosts/server).

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
