{
  self,
  specialArgs,
  config,
  ...
}:

self.lib.factory.deployRsModule {
  inherit config specialArgs;
}
