# Modules

Here is a fizzbuzz flake from Perch modules end-to-end tests:

<!-- markdownlint-disable MD013 -->

```nix
{{ #include ../test/e2e/fizzbuzz/flake.nix }}
```

<!-- markdownlint-enable MD013 -->

In the example we see a call to `perch.lib.flake.make` with one `fizzbuzz`
module. The module defines:

- a default and named package called `fizzbuzz` by the name of the module for
  the abovementioned systems like so:

  ```nix
  {
    packages = {
      "systems..." = {
        default = "<<derivation>>";
        fizzbuzz = "<<derivation>>";
      };
    };
  }
  ```

- a default and named NixOS module using the beforementioned package called
  `fizzbuzz` by the name of the module like so:

  ```nix
  {
    nixosModules = {
      default = "<<module>>";
      fizzbuzz = "<<module>>";
    };
  }
  ```

- a named NixOS module test inside `checks` using the beforementioned NixOS
  module like so:

  ```nix
  {
    checks = {
      ${system} = {
        fizzbuzz-test = "<<derivation>>";
      };
    };
  }
  ```

- a default and named Home manager module using the beforementioned package
  called `fizzbuzz` by the name of the module like so:

  ```nix
  {
    homeManagerModule = {
      default = "<<module>>";
      fizzbuzz = "<<module>>";
    };
  }
  ```

- a NixOS configuration using the beforementioned NixOS module named
  `fizzbuzz-${system}` where the system is the abovementioned system

  ```nix
  {
    nixosConfigurations = {
      "fizzbuzz-${system}" = "<<nixos configuration>>";
    };
  }
  ```

- a `deploy.nodes` `flake` output to be used with `deploy-rs` along with checks
  for the `deploy.nodes` flake output schema

  ```nix
  {
    deploy.nodes = {
      "fizzbuzz-${system}" = {
        hostname = "example.com";
        sshUser = "haras";
        user = "root";
        profiles.system = "<<derivation>>";
      };
    };
    checks = {
      ${system} = {
        deploy-activate = "<<derivation>>";
        deploy-schema = "<<derivation>>";
      };
    };
  }
  ```

- a `rumor` `flake` output to be used with `rumor` along with checks for the
  `rumor` flake output schema

  ```nix
  {
    rumor = {
      "fizzbuzz-${system}" = {
        generations = [{
          generator = "text";
          arguments = {
            name = "secret";
            text = "hello :)";
          };
        }];
      };
    };
    checks = {
      ${system} = {
        rumor-fizzbuzz-${system}-schema = "<<derivation>>";
      };
    };
  }
  ```

## Special arguments

- `nixosModule` - in the NixOS module test evaluation context, it will be set to
  the NixOS module that is defined in the same flake module if the flake module
  defines one.

## Options

### Home manager modules

- `defaultHomeManagerModule`: `bool` = `false` - whether this module defines the
  default Home manager module
- `homeManagerModule`: `raw` - the Home manager module for this module

### Deploy-rs

- `nixosConfigurationsAsDeployNodes`: `bool` = `true` - converts all NixOS
  configurations with `deploy.node` configuration into deploy nodes

  `perch-modules` provides a NixOS module
  `perch-modules.nixosModules."flake-deployRs"` which you can use to define a
  `deploy.node` in your NixOS configuration

### NixOS module tests

- `nixosModuleTest`: `raw` - the NixOS module test for this module
- `nixosModuleTestNixpkgs`: `nixpkgs config` - the `nixpkgs` configuration for
  this NixOS module test `pkgs`

### Rumor

- `rumor.sopsDir`: `nullOr str` = `null` - where to copy the resulting sops file
  to be used with `sops-nix`
- `nixosConfigurationsAsRumor`: `bool` = `true` - converts all NixOS
  configurations with `rumor` configuration into `rumor` specifications

  `perch-modules` provides a NixOS module
  `perch-modules.nixosModules."flake-rumor"` which you can use to define a
  `rumor` specification in your NixOS configuration
