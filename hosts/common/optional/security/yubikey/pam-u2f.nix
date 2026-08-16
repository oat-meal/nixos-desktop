# INTENTIONALLY NOT IMPORTED BY ANY HOST — see yubikey/default.nix for why.
# Putting a hardware key in the sudo/login path risks lockout; LUKS/FIDO2 unlock
# (security/luks.nix) is the only YubiKey integration actually in use.

{ config, pkgs, lib, ... }:

{
  ################################
  ## YubiKey PAM U2F - sudo/login integration
  ## Requires: ~/.config/Yubico/u2f_keys (per-user)
  ##
  ## Setup steps:
  ## 1. pamu2fcfg > ~/.config/Yubico/u2f_keys
  ## 2. For backup key: pamu2fcfg -n >> ~/.config/Yubico/u2f_keys
  ################################

  ################################
  ## Required packages
  ################################
  environment.systemPackages = with pkgs; [
    pam_u2f               # PAM module
    yubico-pam            # Alternative PAM module
  ];

  ################################
  ## PAM Configuration
  ## "sufficient" = YubiKey OR password works
  ## Change to "required" for YubiKey AND password
  ################################
  security.pam.services = {
    # sudo with U2F
    sudo.u2fAuth = true;

    # su with U2F
    su.u2fAuth = true;

    # Login manager (greetd/tuigreet)
    greetd.u2fAuth = true;

    # Screen lock (swaylock)
    swaylock.u2fAuth = true;

    # polkit (GUI privilege escalation)
    polkit-1.u2fAuth = true;
  };

  ################################
  ## U2F PAM settings
  ################################
  security.pam.u2f = {
    enable = true;
    settings = {
      cue = true;           # Print "Please touch the device" prompt
      # authfile = "/etc/u2f_keys";  # System-wide keys (optional)
      # origin = "pam://hostname";   # Custom origin (optional)
    };
  };
}
