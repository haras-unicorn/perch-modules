{
  lib,
  perch,
  ...
}:

{
  flake.lib.factory.nixosModuleTestModule =
    {
      flakeModules,
      specialArgs,
      superConfig,
      superOptions,
      nixpkgs,
    }:
    let
      modules =
        builtins.mapAttrs
          (
            module: value:
            perch.lib.module.patch (_: args: builtins.removeAttrs args [ "nixosModule" ]) (
              _: args:
              args
              // (
                if superConfig.flake ? nixosModules && superConfig.flake.nixosModules ? ${module} then
                  {
                    nixosModule = {
                      name = module;
                      value = superConfig.flake.nixosModules.${module};
                    };
                  }
                else
                  {
                    nixosModule = null;
                  }
              )
            ) (_: result: result) value
          )
          (
            lib.filterAttrs (
              module: _: superConfig.flake ? nixosModules && superConfig.flake.nixosModules ? ${module}
            ) flakeModules
          );

      artifacts =
        builtins.mapAttrs
          (
            _:
            lib.mapAttrs' (
              name: value: {
                inherit value;
                name = "${name}-test";
              }
            )
          )
          (
            perch.lib.artifacts.make {
              inherit
                nixpkgs
                ;

              flakeModules = modules;

              config = "nixosModuleTest";
              nixpkgsConfig = "nixosModuleTestNixpkgs";
              defaultConfig = "defaultNixosModuleTest";

              specialArgs = (
                specialArgs
                // {
                  super.config = superConfig;
                  super.options = superOptions;
                }
              );
            }
          );
    in
    {
      config.eval.allowedArgs = [
        "super"
        "pkgs"
        "nixosModule"
      ];

      options.defaultNixosModuleTest = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      options.nixosModuleTest = lib.mkOption {
        type = lib.types.raw;
      };
      options.nixosModuleTestNixpkgs = lib.mkOption {
        type = perch.lib.type.nixpkgs.config;
      };
      config.eval.privateConfig = [
        [ "defaultNixosModuleTest" ]
        [ "nixosModuleTest" ]
        [ "nixosModuleTestNixpkgs" ]
      ];

      config.flake.checks = artifacts;
    };

  flake.lib.factory.deployRsModule =
    {
      specialArgs,
      config,
      ...
    }:
    let
      deploy-rs = if specialArgs ? deploy-rs then specialArgs.deploy-rs else null;

      nixosConfigurationDeployNodes =
        if deploy-rs == null then
          { }
        else if !config.nixosConfigurationsAsDeployNodes then
          { }
        else
          builtins.mapAttrs
            (
              name: value:
              let
                system = builtins.concatStringsSep "-" (lib.takeEnd 2 (lib.splitString "-" name));
                submodule = value.config.deploy.node;
              in
              submodule
              // {
                user = "root";
                profiles.system = {
                  path = deploy-rs.lib.${system}.activate.nixos value;
                };
              }
            )
            (
              lib.filterAttrs (
                _: conf: conf.config ? deploy && conf.config.deploy ? node
              ) config.flake.nixosConfigurations
            );

      deployChecks =
        if deploy-rs == null then
          { }
        else
          builtins.mapAttrs (system: deployLib: deployLib.deployChecks config.flake.deploy) deploy-rs.lib;
    in
    {
      config.nixosModule.options.deploy.node.hostname = lib.mkOption {
        type = lib.types.str;
        description = lib.literalMD ''
          Deployment host name.
        '';
      };

      config.nixosModule.options.deploy.node.sshUser = lib.mkOption {
        type = lib.types.str;
        description = lib.literalMD ''
          Deployment SSH user.
        '';
      };

      options.nixosConfigurationsAsDeployNodes = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = lib.literalMD ''
          Convert all nixos configurations to deploy nodes.
        '';
      };
      config.eval.privateConfig = [
        [ "nixosConfigurationsAsDeployNodes" ]
      ];

      options.flake.deploy.nodes = lib.mkOption {
        type = lib.types.attrsOf lib.types.raw;
        default = { };
        description = lib.literalMD ''
          Propagated `deploy.nodes` flake output.
        '';
      };

      config.eval.publicConfig = [
        [
          "flake"
          "deploy"
          "nodes"
        ]
      ];

      config.flake.deploy.nodes = nixosConfigurationDeployNodes;

      config.flake.checks = deployChecks;
    };
}
