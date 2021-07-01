{
  description = "queued-build-hook - a Nix post-build-hook with some superpowers";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    lib = pkgs.lib;
    queued-build-hook = import ./default.nix { inherit pkgs lib; };
  in
  {
    devShell."${system}" = import ./shell.nix { inherit pkgs; };

    packages."${system}".queued-build-hook = queued-build-hook;

    defaultPackage."${system}" = self.packages."${system}".queued-build-hook;
  };
}
