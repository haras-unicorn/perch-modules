# Perch modules

An assortment of modules to use with [perch].

## Get started

Add the following to `flake.nix`:

```nix
{
  inputs = {
    perch.url = "github:haras-unicorn/perch/refs/tags/<perch-version>";

    perch-modules.url = "github:haras-unicorn/perch/refs/tags/<perch-version>";
    perch-modules.inputs.perch.follows = "perch";
  };

  outputs = { perch, ... } @inputs:
    perch.lib.flake.make {
      inherit inputs;
      root = ./.;
      prefix = "flake";
    };
}
```

## Documentation

Documentation can be found on [GitHub Pages].

## Contributing

Please review [CONTRIBUTING.md](./CONTRIBUTING.md)

## License

This project is licensed under the [MIT License](./LICENSE.md).

[GitHub Pages]: https://haras-unicorn.github.io/perch-modules/
[perch]: https://haras-unicorn.github.io/perch/
