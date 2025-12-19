{
  inputs = {
    home-manager.url = "github:nix-community/home-manager?rev=fdec8815a86db36f42fc9c8cb2931cd8485f5aed";
    deploy-rs.url = "github:serokell/deploy-rs?rev=d5eff7f948535b9c723d60cd8239f8f11ddc90fa";
  };

  outputs =
    {
      perch,
      perch-modules,
      home-manager,
      deploy-rs,
      ...
    }@inputs:
    perch.lib.flake.make {
      inherit inputs;
      selfModules.fizzbuzz =
        {
          self,
          pkgs,
          lib,
          config,
          specialArgs,
          perch-modules,
          nixosModule,
          ...
        }:
        {
          defaultPackage = true;
          packageNixpkgs.system = [
            "x86_64-linux"
            "x86_64-darwin"
          ];
          package = pkgs.writeShellApplication {
            name = "fizzbuzz";
            text = ''
              for i in {1..100}; do
                if (( i % 15 == 0 )); then
                  echo "FizzBuzz"
                elif (( i % 3 == 0 )); then
                  echo "Fizz"
                elif (( i % 5 == 0 )); then
                  echo "Buzz"
                else
                  echo "$i"
                fi
              done
            '';
          };

          defaultNixosModule = true;
          nixosModule = {
            options.programs.fizzbuzz = {
              enable = lib.mkEnableOption "fizzbuzz";
            };
            config = lib.mkIf config.programs.fizzbuzz.enable {
              environment.systemPackages = [
                self.packages.${pkgs.system}.default
              ];
            };
          };

          nixosModuleTestNixpkgs.system = [ "x86_64-linux" ];
          nixosModuleTest = pkgs.testers.runNixOSTest {
            name = "${nixosModule.name}-${pkgs.system}";
            nodes = {
              ${nixosModule.name} = {
                imports = [
                  nixosModule.value
                ];

                config.programs.fizzbuzz.enable = true;
              };
            };
            testScript = ''
              start_all()
              node = machines[0]
              node.succeed("fizzbuzz")
            '';
          };

          defaultHomeManagerModule = true;
          homeManagerModule = {
            options.programs.fizzbuzz = {
              enable = lib.mkEnableOption "fizzbuzz";
            };
            config = lib.mkIf config.programs.fizzbuzz.enable {
              home.packages = [
                self.packages.${pkgs.system}.default
              ];
            };
          };

          nixosConfigurationNixpkgs.system = "x86_64-linux";
          nixosConfiguration = {
            imports = [
              self.nixosModules.default
              home-manager.nixosModules.default
              perch-modules.nixosModules."flake-deployRs"
            ];
            fileSystems."/" = {
              device = "/dev/disk/by-label/NIXROOT";
              fsType = "ext4";
            };
            deploy.node = {
              hostname = "example.com";
              sshUser = "haras";
            };
            boot.loader.grub.device = "nodev";
            programs.fizzbuzz.enable = true;
            users.users.haras.isNormalUser = true;
            home-manager.extraSpecialArgs = specialArgs;
            home-manager.users.haras = {
              imports = [
                self.homeManagerModules.default
              ];
              programs.fizzbuzz.enable = true;
              home.stateVersion = "25.11";
            };
            system.stateVersion = "25.11";
          };
        };
    };
}
