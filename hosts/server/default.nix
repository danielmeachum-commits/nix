{
  custom.vmdev.enable = true;
  custom.navidrome.enable = true;

  # Lidarr's plugins UI isn't in mainline nixpkgs yet, so we run hotio's
  # `pr-plugins` container instead. Web UI on :8686.
  custom.lidarr.enable = true;

  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;
}
