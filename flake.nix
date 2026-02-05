{
  description = "Mirror messages from a GroupMe to a Discord webhook";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      packages.default = pkgs.writeShellApplication {
        name = "groupme-mirror";
        runtimeInputs = [ pkgs.curl pkgs.jq pkgs.coreutils pkgs.bash ];
        text = builtins.readFile ./mirror.sh;
      };
    }) // {
      nixosModules.default = { config, lib, pkgs, ... }:
      with lib;
      let
        cfg = config.services.groupme-mirror;
      in {
        options.services.groupme-mirror = {
          enable = mkEnableOption "GroupMe to Discord mirror service";
          envFile = mkOption {
            type = types.str;
            default = "/etc/groupme-mirror.env";
            description = "Path to file containing GROUP_ID, GROUPME_ACCESS_TOKEN, and DISCORD_WEBHOOK_URL";
          };
          interval = mkOption {
            type = types.str;
            default = "1m";
            description = "Systemd timer interval (e.g., '1m' or '30s')";
          };
        };

        config = mkIf cfg.enable {
          systemd.services.groupme-mirror = {
            description = "GroupMe to Discord Mirror Service";
            after = [ "network.target" ];
            serviceConfig = {
              ExecStart = "${self.packages.${pkgs.system}.default}/bin/groupme-mirror";
              EnvironmentFile = cfg.envFile;

              DynamicUser = true;
              StateDirectory = "groupme-mirror";
              User = "groupme-mirror";
            };
          };

          systemd.timers.groupme-mirror = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1m";
              OnUnitActiveSec = cfg.interval;
              Unit = "groupme-mirror.service";
            };
          };
        };
      };
    };
}
