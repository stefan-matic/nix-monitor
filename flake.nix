{
  description = "Nix Monitor - A DankMaterialShell plugin for monitoring Nix store and home-manager generations";

  outputs =
    { self, ... }:
    {
      homeManagerModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        with lib;
        let
          cfg = config.programs.nix-monitor;

          configFile = pkgs.writeText "nix-monitor-config.json" (
            builtins.toJSON {
              generationsCommand = cfg.generationsCommand;
              storeSizeCommand = cfg.storeSizeCommand;
              rebuildCommand = cfg.rebuildCommand;
              gcCommand = cfg.gcCommand;
              updateInterval = cfg.updateInterval;
            }
          );
        in
        {
          options.programs.nix-monitor = {
            enable = mkEnableOption "Nix Monitor plugin for DankMaterialShell";

            generationsCommand = mkOption {
              type = types.listOf types.str;
              default = [
                "sh"
                "-c"
                "nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | wc -l"
              ];
              description = "Command to count Nix system generations";
              example = literalExpression ''
                [ "sh" "-c" "nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l" ]
              '';
            };

            storeSizeCommand = mkOption {
              type = types.listOf types.str;
              default = [
                "sh"
                "-c"
                "du -sh /nix/store 2>/dev/null | cut -f1"
              ];
              description = "Command to get Nix store size";
              example = literalExpression ''
                [ "sh" "-c" "du -sh /nix/store 2>/dev/null | cut -f1" ]
              '';
            };

            rebuildCommand = mkOption {
              type = types.listOf types.str;
              description = "Command to run for system rebuild (required)";
              example = literalExpression ''
                [ "bash" "-c" "cd ~/.config/home-manager && home-manager switch --flake .#home 2>&1" ]
              '';
            };

            gcCommand = mkOption {
              type = types.listOf types.str;
              default = [
                "sh"
                "-c"
                "nix-collect-garbage -d 2>&1"
              ];
              description = "Command to run for garbage collection";
              example = literalExpression ''
                [ "/usr/bin/bash" "-l" "-c" "nix-collect-garbage -d" ]
              '';
            };

            updateInterval = mkOption {
              type = types.int;
              default = 300;
              description = "Update interval in seconds for refreshing statistics";
              example = 600;
            };
          };

          config = mkIf cfg.enable {
            assertions = [
              {
                assertion = cfg.rebuildCommand != null;
                message = "programs.nix-monitor.rebuildCommand must be set when nix-monitor is enabled";
              }
            ];

            home.file.".config/DankMaterialShell/plugins/NixMonitor" = {
              source = self;
              recursive = true;
            };

            home.file.".config/DankMaterialShell/plugins/NixMonitor/config.json" = {
              source = configFile;
            };
          };
        };

      dmsPlugin = self;
    };
}
