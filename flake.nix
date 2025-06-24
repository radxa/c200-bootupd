{
  # Enter with `nix develop`
  description = "Support `make dtbs` for NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    devShell.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
      pkgs.mkShell {
        packages = [ pkgs.linux.dev ];

        shellHook = ''
          export KERNEL_HEADERS=${pkgs.linux.dev}/lib/modules/*/source
          export KERNEL_OUTPUT=${pkgs.linux.dev}/lib/modules/*/build
        '';
      };

  };
}
