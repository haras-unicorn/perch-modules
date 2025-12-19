{
  self,
  lib,
  perch,
  nixpkgs,
  home-manager,
  deploy-rs,
  ...
}:

let
  superConfig = { };
  superOptions = { };

  homeManagerModule =
    { specialArgs, flakeModules, ... }:
    if specialArgs ? home-manager then
      perch.lib.factory.submoduleModule {
        inherit
          specialArgs
          flakeModules
          superConfig
          superOptions
          ;
        config = "homeManagerModule";
      }
    else
      { };

  deployRsModule =
    {
      specialArgs,
      config,
      ...
    }:
    if specialArgs ? deploy-rs then
      self.lib.factory.deployRsModule {
        inherit config specialArgs;
      }
    else
      { };

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
        ;
      input = perch.lib.flake.make {
        inputs = {
          inherit
            perch
            nixpkgs
            home-manager
            deploy-rs
            ;
        };
        selfModules = {
          inherit homeManagerModule deployRsModule nixosModuleTestModule;
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
      deployModule =
        { input, ... }:
        {
          defaultNixosConfiguration = true;
          nixosConfigurationNixpkgs.system = [ "x86_64-linux" ];
          nixosConfiguration = {
            imports = [
              input.nixosModules.deployRsModule
            ];
            deploy.node = {
              hostname = "example.com";
              sshUser = "haras";
            };
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
}
