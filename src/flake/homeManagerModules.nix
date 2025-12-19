{
  perch,
  flakeModules,
  specialArgs,
  config,
  options,
  ...
}:

perch.lib.factory.submoduleModule {
  inherit flakeModules specialArgs;
  superConfig = config;
  superOptions = options;
  config = "homeManagerModule";
}
