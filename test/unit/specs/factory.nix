{
  self,
  lib,
  perch,
  nixpkgs,
  home-manager,
  deploy-rs,
  rumor,
  ...
}:

let
  superConfig = { };
  superOptions = { };

  homeManagerModule =
    { specialArgs, flakeModules, ... }:
    perch.lib.factory.submoduleModule {
      inherit
        specialArgs
        flakeModules
        superConfig
        superOptions
        ;
      config = "homeManagerModule";
    };

  deployRsModule =
    {
      specialArgs,
      config,
      ...
    }:
    self.lib.factory.deployRsModule {
      inherit config specialArgs;
    };

  rumorModule =
    {
      specialArgs,
      config,
      ...
    }:
    self.lib.factory.rumorModule {
      inherit config specialArgs;
    };

  nixosModuleTestModule =
    {
      specialArgs,
      flakeModules,
      config,
      options,
      nixpkgs,
      ...
    }:
    self.lib.factory.nixosModuleTestModule {
      inherit specialArgs flakeModules nixpkgs;
      superConfig = config;
      superOptions = options;
    };

  flakeResult = perch.lib.flake.make {
    inputs = {
      inherit
        perch
        nixpkgs
        home-manager
        deploy-rs
        rumor
        ;
      input = perch.lib.flake.make {
        inputs = {
          inherit
            perch
            nixpkgs
            home-manager
            deploy-rs
            rumor
            ;
        };
        selfModules = {
          inherit
            homeManagerModule
            deployRsModule
            rumorModule
            nixosModuleTestModule
            ;
        };
      };
    };
    selfModules = {
      someHomeManagerModule = {
        homeManagerModule = {
          value = "some hello :)";
        };
        defaultHomeManagerModule = true;
      };
      otherHomeManagerModule = {
        homeManagerModule = {
          value = "other hello :)";
        };
      };
      none = { };
      nixosModule =
        { pkgs, nixosModule, ... }:
        {
          nixosModule = {
            environment.systemPackages = [ pkgs.hello ];
          };

          nixosModuleTestNixpkgs.system = [ "x86_64-linux" ];
          nixosModuleTest = pkgs.testers.runNixOSTest {
            name = "${nixosModule.name}-${pkgs.system}";
            nodes = {
              ${nixosModule.name} = nixosModule.value;
            };
            testScript = ''
              start_all()
              node = machines[0]
              node.succeed("hello")
            '';
          };
        };
      configurationModule =
        { input, ... }:
        {
          defaultNixosConfiguration = true;
          nixosConfigurationNixpkgs.system = [ "x86_64-linux" ];
          nixosConfiguration = {
            imports = [
              input.nixosModules.deployRsModule
              input.nixosModules.rumorModule
            ];
            deploy.node = {
              hostname = "example.com";
              sshUser = "haras";
            };
            rumor.sops.keys = [ "secret" ];
            rumor.sops.path = "../sops.yaml";
            rumor.specification.generations = [
              {
                generator = "text";
                arguments = {
                  name = "secret";
                  text = "hello :)";
                };
              }
            ];
            fileSystems."/" = {
              device = "/dev/disk/by-label/nix-root";
              fsType = "ext4";
            };
            boot.loader.grub.device = "nodev";
            system.stateVersion = "25.11";
          };
        };
    };
  };
in
{
  factory_home_manager_correct =
    flakeResult.homeManagerModules == {
      default = {
        value = "some hello :)";
      };
      otherHomeManagerModule = {
        value = "other hello :)";
      };
      someHomeManagerModule = {
        value = "some hello :)";
      };
    };

  factory_deploy_correct = builtins.all (
    { name, value }: value.hostname == "example.com" && value.sshUser == "haras"
  ) (lib.attrsToList flakeResult.deploy.nodes);

  factory_nixos_module_tests_correct =
    flakeResult.checks.x86_64-linux.nixosModule-test.type == "derivation";

  factory_rumor_correct =
    (builtins.head flakeResult.rumor.configurationModule-x86_64-linux.generations).arguments.text
    == "hello :)";

  factory_rumor_sops_correct =
    (builtins.elemAt flakeResult.rumor.configurationModule-x86_64-linux.generations 1).generator
    == "age-key"
    &&
      (builtins.elemAt flakeResult.rumor.configurationModule-x86_64-linux.generations 2).generator
      == "sops"
    &&
      (builtins.elemAt flakeResult.rumor.configurationModule-x86_64-linux.generations 2).arguments.secrets
      == {
        secret = "secret";
      };
}
