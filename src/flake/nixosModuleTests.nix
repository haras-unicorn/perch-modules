{
  self,
  nixpkgs,
  flakeModules,
  specialArgs,
  config,
  options,
  ...
}:

self.lib.factory.nixosModuleTestModule {
  inherit specialArgs flakeModules nixpkgs;
  superConfig = config;
  superOptions = options;
}
