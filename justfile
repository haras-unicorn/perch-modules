set windows-shell := ["nu.exe", "-c"]
set shell := ["nu", "-c"]

root := absolute_path('')
perch := shell('"github:haras-unicorn/perch?rev=" + (open flake.lock | from json | get nodes.perch.locked.rev)')
perch-modules := root
nixpkgs := shell('"github:nixos/nixpkgs?rev=" + (open flake.lock | from json | get nodes.nixpkgs.locked.rev)')
home-manager := "github:nix-community/home-manager?rev=fdec8815a86db36f42fc9c8cb2931cd8485f5aed"
deploy-rs := "github:serokell/deploy-rs?rev=d5eff7f948535b9c723d60cd8239f8f11ddc90fa"

default:
    @just --choose

format:
    cd '{{ root }}'; just --unstable --fmt
    prettier --write '{{ root }}'
    nixfmt ...(fd '.*.nix$' '{{ root }}' | lines)

lint:
    cd '{{ root }}'; just --unstable --fmt --check
    prettier --check '{{ root }}'
    nixfmt --check ...(fd '.*.nix$' '{{ root }}' | lines)
    cspell lint '{{ root }}' --no-progress
    markdownlint '{{ root }}'
    markdown-link-check \
      --config .markdown-link-check.json \
      --quiet \
      ...(fd '.*.md' | lines)
    nix flake check --all-systems

test-e2e-all *args:
    #!/usr/bin/env nu
    ls "{{ root }}/test/e2e" | get name | each {
      (nix flake check
        --override-flake perch-modules '{{ perch-modules }}'
        --override-flake perch "{{ perch }}"
        --override-flake nixpkgs "{{ nixpkgs }}"
        --all-systems
        --no-write-lock-file
        {{ args }}
        $"path:(realpath $in)")
    }

test-e2e test *args:
    nix flake check \
      --override-flake perch-modules '{{ perch-modules }}' \
      --override-flake perch "{{ perch }}" \
      --override-flake nixpkgs "{{ nixpkgs }}" \
      --all-systems \
      --no-write-lock-file \
      {{ args }} \
      $"path:("{{ root }}/test/e2e/{{ test }}")"

test-unit filter="":
    #!/usr/bin/env nu
    let result = (nix eval
      --json
      --impure
      --override-flake perch-modules '{{ perch-modules }}'
      --override-flake perch "{{ perch }}"
      --override-flake nixpkgs "{{ nixpkgs }}"
      --override-flake home-manager "{{ home-manager }}"
      --override-flake deploy-rs "{{ deploy-rs }}"
      --expr
      '(builtins.getFlake "{{ root }}/test/unit").test {
        root = "{{ root }}";
        filter = "{{ filter }}";
      }') | complete
    if $result.exit_code != 0 {
      print -e $result.stderr
      exit 1
    }

    let json = $result.stdout | from json
    print $json.summary
    if not $json.ok {
      print -e $result.stderr
      exit 1
    }

repl test *args:
    cd '{{ root }}/test/e2e/{{ test }}'; \
      nix repl \
        {{ args }} \
        --override-flake perch-modules '{{ root }}' \
        --override-flake perch '{{ perch }}' \
        --expr 'rec { \
          perchModules = "{{ root }}"; \
          perchModulesFlake = builtins.getFlake perchModules; \
          test = "{{ root }}/test/e2e/{{ test }}"; \
          testFlake = builtins.getFlake test; \
        }'

dev-docs:
    mdbook serve '{{ root }}/docs'

docs:
    rm -rf '{{ root }}/artifacts'
    cd '{{ root }}/docs'; mdbook build
    mv '{{ root }}/docs/book' '{{ root }}/artifacts'
