{ pkgs, ... }:

{
  devShell = pkgs.mkShell {
    packages = with pkgs; [
      # version control
      git

      # scripts
      just
      nushell

      # nix
      nixfmt-rfc-style
      nixVersions.stable

      # markdown
      markdownlint-cli
      nodePackages.markdown-link-check

      # spelling
      nodePackages.cspell

      # misc
      nodePackages.prettier

      # tools
      fd
      coreutils
    ];
  };
}
