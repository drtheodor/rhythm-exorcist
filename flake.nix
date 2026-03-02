{
  description = "Empty Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};

        nativeBuildInputs = with pkgs; [
          git
        ];

        buildInputs = with pkgs; [
          wayland
          godot

          # zlibext
          pkg-config
          scons
          mold
          zlib
        ];
      in {
        devShells.default = pkgs.mkShell {
          inherit nativeBuildInputs buildInputs;
        };

        devShells.android = pkgs.mkShell {
          inherit nativeBuildInputs;

          buildInputs = with pkgs; [
            sdkmanager
          ] ++ buildInputs;
        };
      }
    );
}
