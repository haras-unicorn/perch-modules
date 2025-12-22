{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?rev=727668086d6923171b25b6a74064d418ae1edb27";
  };

  outputs =
    {
      self,
      nixpkgs,
      perch,
      deploy-rs,
      home-manager,
      rumor,
      ...
    }:
    {
      test =
        {
          root,
          filter ? "",
        }:
        let
          lib = nixpkgs.lib;

          specialArgs = {
            inherit
              nixpkgs
              lib
              perch
              deploy-rs
              home-manager
              rumor
              ;
            self.lib = flake.lib;
          };

          eval = lib.evalModules {
            specialArgs = specialArgs;
            class = "flake";
            modules = [
              perch.modules."lib-lib"
            ]
            ++ (builtins.attrValues (
              lib.filterAttrs (name: _: lib.hasPrefix "lib" name) (
                perch.lib.import.dirToFlatPathAttrs "-" "${root}/src"
              )
            ));
          };

          flake = eval.config.flake;

          specs = perch.lib.import.dirToFlatValueAttrs "-" "${self}/specs";

          results = lib.flatten (
            builtins.map (
              outer:
              builtins.map
                (inner: {
                  name = "${outer.name}: ${inner.name}";
                  value = if inner.value then "passed" else "failed";
                })
                (
                  builtins.filter (inner: lib.hasPrefix filter outer.name || lib.hasPrefix filter inner.name) (
                    lib.attrsToList (outer.value specialArgs)
                  )
                )
            ) (lib.attrsToList specs)
          );

          ok = builtins.all (result: result.value == "passed") results;

          summary =
            let
              total = builtins.length results;
              failed = builtins.filter (r: r.value == "failed") results;
              passedCount = total - builtins.length failed;

              header = if ok then "✅ All tests passed!" else "❌ Some tests failed.";

              line = result: "- " + result.name + ": " + (if result.value == "passed" then "✅" else "❌");

              details =
                if ok then "" else "\n\nFailed tests:\n" + lib.concatStringsSep "\n" (builtins.map line failed);

              tally = "\n\nSummary: " + toString passedCount + "/" + toString total + " passed";
            in
            header + tally + details;
        in
        {
          inherit ok results summary;
        };
    };
}
