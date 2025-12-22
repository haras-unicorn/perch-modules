{
  self,
  specialArgs,
  config,
  ...
}:

self.lib.factory.rumorModule {
  inherit config specialArgs;
}
