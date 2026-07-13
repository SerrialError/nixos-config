# Shared baseline for all hosts (desktop + server). Everything here was
# extracted from the original configuration.nix; host-specific config lives
# under hosts/<name>/.
{
  config,
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.agenix.nixosModules.default
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Weekly automatic maintenance so the store doesn't balloon:
  #  - gc removes generations older than 30 days (keeps recent ones for rollback)
  #  - optimise hard-links identical store paths to reclaim space
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  nixpkgs.config.allowUnfree = true;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # SSH authorized keys for every host come from this agenix secret. Reading
  # it via authorizedKeys.keyFiles happens at eval time, which is why rebuilds
  # need --impure and root. Host configs may override owner/mode (the desktop
  # shares it with the git-shell user).
  age.secrets.ssh-auth-keys.file = ../secrets/ssh-auth-keys.age;

  users.users.connor = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keyFiles = [
      config.age.secrets.ssh-auth-keys.path
    ];
  };
  # connor's login shell; per-user zsh config comes from home-manager where enabled
  programs.zsh.enable = true;

  services.openssh = {
    enable = true;
    # Key-based auth only; authorized keys are deployed via agenix.
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    curlFull
    rsync
    tmux
    killall
    ncdu
    unzip
    fastfetch
    ripgrep
    fd
    jq
  ];
}
