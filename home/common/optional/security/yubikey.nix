{ config, pkgs, lib, ... }:

{
  ################################
  ## YubiKey - Home Manager Configuration
  ## GPG agent with smart card support, SSH config
  ################################

  ################################
  ## GPG Agent with YubiKey support
  ################################
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;  # Use GPG keys for SSH authentication
    enableScDaemon = true;    # Smart card daemon for YubiKey

    # PIN entry program (GUI)
    pinentry.package = pkgs.pinentry-gtk2;

    # Cache settings (adjust as needed)
    defaultCacheTtl = 600;        # 10 minutes
    maxCacheTtl = 7200;           # 2 hours
    defaultCacheTtlSsh = 600;
    maxCacheTtlSsh = 7200;

    # Extra config for smart card
    extraConfig = ''
      # Disable on-disk caching of private keys
      no-allow-external-cache
    '';
  };

  ################################
  ## GPG Configuration
  ################################
  programs.gpg = {
    enable = true;

    # Use the agent for all operations
    settings = {
      use-agent = true;

      # Prefer strong algorithms
      personal-cipher-preferences = "AES256 AES192 AES";
      personal-digest-preferences = "SHA512 SHA384 SHA256";
      personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";

      # Key server
      keyserver = "hkps://keys.openpgp.org";

      # Display options
      keyid-format = "0xlong";
      with-fingerprint = true;
    };
  };

  ################################
  ## SSH Client - FIDO2 Key Support
  ################################
  programs.ssh = {
    enable = true;

    # Global SSH options
    extraConfig = ''
      # FIDO2 security key settings
      # Uncomment the line below to require touch for each SSH connection:
      # SecurityKeyProvider internal

      # Forward GPG agent for remote GPG operations (optional)
      # Match host trusted-server
      #   ForwardAgent yes

      # Common server configurations
      Host *
        # Use FIDO2 keys when available
        IdentitiesOnly yes
        AddKeysToAgent yes

        # Prefer modern key exchange
        KexAlgorithms curve25519-sha256@libssh.org,curve25519-sha256
    '';
  };

  ################################
  ## Yubico config directory
  ## Creates ~/.config/Yubico/ for u2f_keys
  ################################
  home.file.".config/Yubico/.keep".text = "";

  ################################
  ## SSH directory setup
  ## Creates ~/.ssh/ with correct permissions
  ################################
  home.file.".ssh/.keep" = {
    text = "";
    onChange = ''
      chmod 700 ~/.ssh
    '';
  };

  ################################
  ## Shell aliases for YubiKey operations
  ################################
  home.shellAliases = {
    # YubiKey info
    yk = "ykman info";
    yk-list = "ykman list";

    # FIDO2 operations
    yk-fido-list = "ykman fido credentials list";
    yk-fido-reset = "ykman fido reset";

    # GPG card status
    gpg-card = "gpg --card-status";
    gpg-card-edit = "gpg --card-edit";

    # Generate FIDO2 SSH key (resident, touch required)
    ssh-keygen-yk = "ssh-keygen -t ed25519-sk -O resident -O verify-required";

    # Register U2F key for PAM
    yk-pam-setup = "mkdir -p ~/.config/Yubico && pamu2fcfg > ~/.config/Yubico/u2f_keys && echo 'Primary key registered. Insert backup key and run: pamu2fcfg -n >> ~/.config/Yubico/u2f_keys'";
  };
}
