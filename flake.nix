{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    roc.url = "github:roc-lang/roc";
  };
  outputs = {
    nixpkgs,
    roc,
    ...
  }: let
    systems = nixpkgs.lib.systems.flakeExposed;
  in {
    formatter = nixpkgs.lib.genAttrs systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        pkgs.alejandra
    );
    devShells = nixpkgs.lib.genAttrs systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      rocPkgs = roc.packages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = builtins.attrValues {
          inherit (pkgs) nixd nil alejandra;
          inherit (rocPkgs) full;
        };
      };
    });
  };
}
