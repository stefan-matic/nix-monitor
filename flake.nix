{
  description = "Nix Monitor - A DankMaterialShell plugin for monitoring Nix store and home-manager generations";

  outputs =
    { self, ... }:
    let
      mkNixMonitorModule =
        {
          isNixOS ? false,
        }:
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
              localRevisionCommand = cfg.localRevisionCommand;
              remoteRevisionCommand = cfg.remoteRevisionCommand;
              nixpkgsChannel = cfg.nixpkgsChannel;
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
                [ "bash" "-c" "sudo nixos-rebuild switch --flake .#hostname 2>&1" ]
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
                [ "bash" "-c" "nix-collect-garbage -d 2>&1" ]
              '';
            };

            updateInterval = mkOption {
              type = types.int;
              default = 300;
              description = "Update interval in seconds for refreshing statistics";
              example = 600;
            };

            localRevisionCommand = mkOption {
              type = types.listOf types.str;
              default = [
                "sh"
                "-c"
                "nixos-version --hash 2>/dev/null | cut -c 1-7 || echo 'N/A'"
              ];
              description = "Command to get local nixpkgs revision";
              example = literalExpression ''
                [ "sh" "-c" "nixos-version --hash | cut -c 1-7" ]
              '';
            };

            remoteRevisionCommand = mkOption {
              type = types.listOf types.str;
              default = [
                "sh"
                "-c"
                "git ls-remote https://github.com/NixOS/nixpkgs.git nixos-unstable 2>/dev/null | cut -c 1-7 || echo 'N/A'"
              ];
              description = "Command to get remote nixpkgs revision";
              example = literalExpression ''
                [ "sh" "-c" "git ls-remote https://github.com/NixOS/nixpkgs.git nixos-24.11 | cut -c 1-7" ]
              '';
            };

            nixpkgsChannel = mkOption {
              type = types.str;
              default = "nixos-unstable";
              description = "NixOS channel to check for updates";
              example = "nixos-24.11";
            };
          };

          config = mkIf cfg.enable (mkMerge [
            {
              assertions = [
                {
                  assertion = cfg.rebuildCommand != null;
                  message = "programs.nix-monitor.rebuildCommand must be set when nix-monitor is enabled";
                }
              ];
            }
            (
              if isNixOS then
                {
                  environment.etc."xdg/quickshell/dms-plugins/NixMonitor" = {
                    source = self;
                  };

                  environment.etc."xdg/quickshell/dms-plugins/NixMonitor/config.json" = {
                    source = configFile;
                  };
                }
              else
                {
                  home.file.".config/DankMaterialShell/plugins/NixMonitor" = {
                    source = self;
                    recursive = true;
                  };

                  home.file.".config/DankMaterialShell/plugins/NixMonitor/config.json" = {
                    source = configFile;
                  };
                }
            )
          ]);
        };
    in
    {
      homeManagerModules.default = mkNixMonitorModule { isNixOS = false; };

      nixosModules.default = mkNixMonitorModule { isNixOS = true; };

      dmsPlugin = self;
    };
}
