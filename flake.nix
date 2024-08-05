{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    roc = {
      url = "github:roc-lang/roc";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
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
        buildInputs = with pkgs; [
          (with rocPkgs; [full])
        ];
      };
    });
  };
}
