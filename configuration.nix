# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Unfree + NVIDIA EULA
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.nvidia.acceptLicense = true;

  # Hostname
  networking.hostName = "homeserver";

  # We will define addresses in systemd-networkd (no global DHCP)
  networking.useDHCP = false;

  # Disable NetworkManager and its dispatcher hacks
  networking.networkmanager.enable = false;

  # Switch to systemd-networkd + resolved
  networking.useNetworkd = true;
  networking.useDHCP = false;

  services.resolved.enable = true;

  # Bond device definition
  networking.bonds.bond0 = {
    interfaces = [ "enp66s0f0" "enp66s0f1" ];
    driverOptions = {
      miimon = 100;
      mode = "active-backup";
    };
  };

  # Configure bond0 with static IPv4 + gateway + DNS
  networking.interfaces.bond0 = {
    useDHCP = false;
    ipv4.addresses = [
      { address = "192.168.1.100"; prefixLength = 24; }
    ];
  };

  # default gateway + DNS
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers   = [ "192.168.1.1" "1.1.1.1" "8.8.8.8" ];


  # Make boot wait for real network readiness
  systemd.network.wait-online.enable = true;
  # (defaults to waiting for at least one configured interface; fine here)

  # Time / locale / console
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # LVM + RAID
  services.lvm.enable = true;
  boot.initrd.services.lvm.enable = true;

  boot.swraid.enable = true;
  boot.swraid.mdadmConf = builtins.concatStringsSep "\n" [
    "ARRAY /dev/md0 metadata=1.2 spares=1 name=homeserver:0 UUID=a13e736d:e8805790:1e2d65a6:c4f6b3d2"
    "PROGRAM /usr/local/bin/mdadm-ntfy"
  ];

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # User
  users = {
    defaultUserShell = pkgs.zsh;
    users.danteb = {
      initialPassword = "changeme123!";
      isNormalUser = true;
      extraGroups = [ "docker" "wheel" ];
      openssh.authorizedKeys.keys = [
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBH5PB799wDZ5lqHUn0HDnEudAaUk9ihMYk2/vE7O8ZZ+ykEEycFa1BFxVP4EnIe9J9jyD9GVYs2vgngMNFEmeAE=" # Dante's iPhone (Termius)
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGSElIxTg8VbjbB3O2WVMvZJYfP4GBzg5uzJSaKKu12f dantevbarbieri@gmail.com" # Dante's MacBook Pro
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPdijU1XLbXrh1yMq7RtrLrIaTtWibnMAFcxTfFm1Y+g dantevbarbieri@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHGJVxpke1XAdXybnz5HUkZBx9sDLqaJSsghrItLoDRj redmond\dbarbieri@DESKTOP-JG75H93" # Dante Work PC
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFYsa3JuUbgxuC6O+rfxSIC4scGcxhlgig+wXVoEMaCe dantevbarbieri@gmail.com" # Dell Latitude E5550
      ];
      packages = with pkgs; [
        fastfetch
        tree
      ];
    };
  };

  programs.git = {
    enable = true;
    config = {
      commit.gpgsign = true;
      gpg.format = "ssh";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      user = {
        email = "dantevbarbieri@gmail.com";
        name  = "dantebarbieri";
        signingkey = "~/.ssh/id_ed25519.pub";
      };
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };
  programs.zsh.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    neovim
    wget
    zoxide
    # Storage tooling
    mdadm lvm2 dosfstools xfsprogs parted
    # Docker
    docker-compose
  ];

  programs.gnupg.agent.enable = true;
  programs.ssh.startAgent = true;

  services.openssh = {
    enable = true;
    ports = [ 28 ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Docker
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      features = { cdi = true; };
      fixed-cidr-v6 = "fd00::/80";
      ipv6 = true;
      live-restore = true;
      userland-proxy = true;
    };
  };

  # NVIDIA
  hardware = {
    graphics.enable = true;
    nvidia = {
      modesetting.enable = true;
      open = true;
      datacenter.enable = true;
      nvidiaSettings.enable = false;
      # package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
    nvidia-container-toolkit.enable = true;
  };

  # doas instead of sudo
  security = {
    doas = {
      enable = true;
      extraRules = [ { groups = [ "wheel" ]; keepEnv = true; } ];
    };
    sudo.enable = false;
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}

