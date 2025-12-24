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

  flake.lib.factory.rumorModule =
    {
      config,
      specialArgs,
    }:

    let
      rumor = if specialArgs ? rumor then specialArgs.rumor else null;

      importsOption = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        description = lib.literalMD ''
          Rumor `imports` specification value.
        '';
      };

      generationsOption = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        description = lib.literalMD ''
          Rumor `generations` specification value.
        '';
      };

      exportsOption = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
        description = lib.literalMD ''
          Rumor `exports` specification value.
        '';
      };

      sopsKeysOption = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = lib.literalMD ''
          Which files to include in the sops file.
        '';
      };

      sopsPathOption = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = lib.literalMD ''
          Where to put the sops file.
        '';
      };

      specificationSubmodule.options = {
        imports = importsOption;
        generations = generationsOption;
        exports = exportsOption;
      };

      rumorSubmodule.options = {
        specification = {
          imports = importsOption;
          generations = generationsOption;
          exports = exportsOption;
        };
        sops = {
          keys = sopsKeysOption;
          path = sopsPathOption;
        };
      };

      nixosConfigurationsAsRumor =
        if rumor == null then
          { }
        else if !config.nixosConfigurationsAsRumor then
          { }
        else
          builtins.mapAttrs
            (name: conf: {
              imports = conf.config.rumor.specification.imports;
              generations =
                conf.config.rumor.specification.generations
                ++ (lib.optionals ((builtins.length conf.config.rumor.sops.keys) != 0) [
                  {
                    generator = "age";
                    arguments = {
                      private = "age-private";
                      public = "age-public";
                    };
                  }
                  {
                    generator = "sops";
                    arguments = {
                      renew = true;
                      age = "age-public";
                      private = "sops-private";
                      public = "sops-public";
                      secrets = builtins.listToAttrs (
                        builtins.map (file: {
                          name = file;
                          value = file;
                        }) conf.config.rumor.sops.keys
                      );
                    };
                  }
                ]);
              exports =
                conf.config.rumor.specification.exports
                ++ (lib.optionals
                  ((builtins.length conf.config.rumor.sops.keys) != 0 && conf.config.rumor.sops.path != null)
                  [
                    {
                      exporter = "copy";
                      arguments = {
                        from = "sops-public";
                        to = conf.config.rumor.sops.path;
                      };
                    }
                  ]
                );
            })
            (
              lib.filterAttrs (
                _: conf: conf.config ? rumor && conf.config.rumor != null
              ) config.flake.nixosConfigurations
            );

      # TODO: pkgs.runCommand with rumor validate
      rumorChecks =
        if rumor == null then
          { }
        else
          builtins.listToAttrs (
            builtins.map (system: {
              name = system;
              value = { };
            }) perch.lib.defaults.systems
          );
    in
    {
      config.nixosModule = {
        options.rumor = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule rumorSubmodule);
          default = null;
        };
      };

      options.rumor.sopsDir = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = lib.literalMD ''
          Where to put the sops file.
        '';
      };
      options.nixosConfigurationsAsRumor = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = lib.literalMD ''
          Convert all nixos configurations to rumor.
        '';
      };
      config.eval.privateConfig = [
        [ "nixosConfigurationsAsRumor" ]
      ];

      options.flake.rumor = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule specificationSubmodule);
        default = { };
        description = lib.literalMD ''
          Rumor specifications.
        '';
      };
      config.eval.publicConfig = [
        [
          "flake"
          "rumor"
        ]
      ];

      config.flake.rumor = nixosConfigurationsAsRumor;

      config.flake.checks = rumorChecks;
    };
}
