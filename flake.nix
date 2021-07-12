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

    nixosModule = { config, pkgs, lib, modulesPath, ... }: {
      # TODO: allow only root user write to socket
      # TODO: ensure only service can read from socket
      # TODO: enable service confinment
      # TODO: add configurable options
      #       - service user should set hook
      #       - service user should be able to pass secrets (signing key)?
      # options = {};
      config.systemd = {
        sockets.queued-build-hook = {
            description = "socket for root to enqueue built hooks that called asyncly by service";
            wantedBy = [ "sockets.target" ];
            before = [ "multi-user.target" ];
            socketConfig.ListenStream = "/run/queued-build-hook.sock";
            #TODO: socketConfig.socketMode = "0600";
        };

        services.queued-build-hook = {
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            DynamicUser = true;
            Type = "simple";
            ExecStart = "${queued-build-hook}/bin/queued-build-hook daemon --hook ${./dummy-hook.sh}";
          };

   #       confinement.enable = true;
        };
      };
    };

    checks."${system}" = {
      integration-tests = import ./vm-test.nix {
        makeTest = import (nixpkgs + "/nixos/tests/make-test-python.nix");
        inherit pkgs;
        queued-build-hook-module = self.nixosModule;
        queued-build-hook-binary-path = "${self.packages."${system}".queued-build-hook}/bin/queued-build-hook";
      };
    };
    defaultPackage."${system}" = self.packages."${system}".queued-build-hook;
  };
}
